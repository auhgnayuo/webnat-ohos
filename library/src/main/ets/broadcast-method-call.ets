/**
 * BroadcastMethodCall - 广播式方法调用的竞赛协调器
 *
 * 当 `Webnat.method` 未指定 `connection` 时，会把同一次方法调用**广播**给当前所有连接
 * （主框架 + 所有 iframe），并在这些子调用之间做「谁先返回用谁的」的竞赛裁决。
 *
 * 典型使用场景是**透传 iframe**：正常情况下同一个方法只会有一个 frame 注册处理器，
 * 其余 frame 会立即回 `unimplemented`。协调器据此挑出真正实现该方法的 frame 作为结果来源。
 *
 * ## 竞赛规则
 *
 * 每个连接各自发起一次独立的单连接 RPC（各有独立的调用 ID，互不干扰），协调器据其响应裁决：
 *
 * - **胜者锁定**：第一个发来「有意义信号」的连接成为胜者，随后立即 `abort` 其余连接，
 *   之后只透传胜者的 notify 与最终结果。
 *   「有意义信号」= `notify`、成功 `reply`、或**真实业务错误**（错误码不是 `unimplemented`/`closed`）。
 * - **淘汰而非获胜**：`unimplemented(-1010)` 与 `closed(-1004)` 都不会「抢跑」成为胜者，
 *   只是把该连接移出候选池；当所有连接都被淘汰且从未出现胜者时才最终失败：
 *   若淘汰过程中出现过 `closed` 则返回 `closed`，否则返回 `unimplemented`。
 * - **已锁定的胜者中途失败**（如其连接关闭）：直接把该错误返回给调用方。
 * - **超时 / 取消**：作用于整组——`abort` 全部子调用，返回 `timeout` / `cancelled`。
 *   子调用本身不设超时，超时统一由协调器组级管理。
 */

import { WebnatError, WebnatErrorCode } from './error';
import { Connection } from './connection';
import { AbortController, AbortSignal } from './abortController';
import { MethodFunc, MethodOptions, MethodWebnat } from './method-webnat';

export class BroadcastMethodCall {
  /** 是否已终结（终态到达后所有信号都被忽略） */
  private settled: boolean = false;
  /** 胜者连接 ID；undefined 表示尚未锁定胜者 */
  private winnerId: string | undefined = undefined;
  /** 已被淘汰（回了 unimplemented/closed）的连接 ID 集合 */
  private eliminated: Set<string> = new Set();
  /** 淘汰过程中是否出现过 closed（决定候选池耗尽时返回哪种错误码） */
  private sawClosed: boolean = false;
  /** 参与竞赛的连接总数（快照自发起时） */
  private total: number = 0;
  /** 各子调用的取消控制器，key 为连接 ID；完成或被取消后从表中移除 */
  private controllers: Map<string, AbortController> = new Map();
  /** 组级超时定时器 */
  private timer: number | undefined = undefined;
  /** 方法名（仅用于构造最终的 unimplemented 错误信息） */
  private methodName: string = '';
  /** 透传给调用方的通知回调（只透传胜者的 notify） */
  private userNotification: ((param: ESObject) => void) | undefined = undefined;
  /** Promise 的 resolve / reject */
  private resolveFn: ((value: ESObject) => void) | undefined = undefined;
  private rejectFn: ((error: ESObject) => void) | undefined = undefined;
  /** 外部取消信号及其监听器（用于结束时解绑） */
  private outerSignal: AbortSignal | undefined = undefined;
  private outerSignalAbort: (() => void) | undefined = undefined;
  /** 结束收尾钩子（只触发一次） */
  private onFinished: () => void;

  constructor(onFinished: () => void) {
    this.onFinished = onFinished;
  }

  /**
   * 启动广播调用
   *
   * @param connections 参与竞赛的连接快照（发起时的所有连接）
   * @param methodWebnat 复用其单连接 RPC 能力
   * @param func 方法描述（方法名 + 参数）
   * @param options 调用选项（timeout / onNotification / signal）
   * @returns Promise，resolve 时返回胜者结果，reject 时返回最终错误
   */
  start(connections: Connection[], methodWebnat: MethodWebnat, func: MethodFunc, options?: MethodOptions): Promise<ESObject> {
    this.methodName = func.method;
    this.userNotification = options?.onNotification;
    this.total = connections.length;

    return new Promise<ESObject>((resolve: (value: ESObject) => void, reject: (error: ESObject) => void): void => {
      this.resolveFn = resolve;
      this.rejectFn = reject;

      // 没有任何连接：与旧的单连接行为一致，立即返回 closed
      if (connections.length === 0) {
        this.finish(undefined, WebnatError.closed());
        return;
      }

      // 外部取消信号：已取消则立即结束，否则挂监听
      const outer = options?.signal;
      if (outer) {
        if (outer.aborted) {
          this.finish(undefined, WebnatError.cancelled());
          return;
        }
        const onAbort = (): void => {
          this.finish(undefined, WebnatError.cancelled());
        };
        this.outerSignal = outer;
        this.outerSignalAbort = onAbort;
        outer.addEventListener('abort', onAbort);
      }

      // 组级超时（子调用不再各自设置超时）
      const timeout = options?.timeout;
      if (timeout !== undefined && timeout > 0) {
        this.timer = setTimeout((): void => {
          this.finish(undefined, WebnatError.timeout());
        }, timeout);
      }

      // 对每个连接发起独立的单连接子调用
      for (let i = 0; i < connections.length; i++) {
        if (this.settled) {
          break;
        }
        const connection = connections[i];
        const connId = connection.id;
        const controller = new AbortController();
        this.controllers.set(connId, controller);
        const perNotify = (p: ESObject): void => {
          this.handleNotify(connId, p);
        };
        // 子调用不设超时：超时统一由协调器组级管理
        const subOptions: MethodOptions = {
          onNotification: perNotify,
          signal: controller.signal,
        };
        methodWebnat.method(func, subOptions, connection)
          .then((result: ESObject): void => {
            this.handleComplete(connId, result, null);
          })
          .catch((err: ESObject): void => {
            const w = WebnatError.from(err) ?? new WebnatError(WebnatErrorCode.UNKNOWN, 'Unknown Error');
            this.handleComplete(connId, undefined, w);
          });
      }
    });
  }

  /** 处理某连接的途中通知 */
  private handleNotify(connId: string, param: ESObject): void {
    if (this.settled) {
      return;
    }
    if (this.winnerId !== undefined) {
      // 已有胜者：只透传胜者的通知，落败者一律忽略
      if (this.winnerId === connId && this.userNotification) {
        this.userNotification(param);
      }
      return;
    }
    // 尚无胜者：该连接凭「首个有意义信号」锁定为胜者
    this.winnerId = connId;
    this.cancelLosers(connId);
    if (this.userNotification) {
      this.userNotification(param);
    }
  }

  /** 处理某连接的最终完成（成功或错误） */
  private handleComplete(connId: string, result: ESObject, error: WebnatError | null): void {
    if (this.settled) {
      return;
    }
    // 该子调用已完成，从控制器表中移除
    this.controllers.delete(connId);

    if (this.winnerId !== undefined) {
      // 已锁定的胜者产出终态：直接作为最终结果；落败者迟到消息忽略
      if (this.winnerId === connId) {
        this.finish(result, error);
      }
      return;
    }

    // 尚无胜者
    if (error && this.isEliminating(error)) {
      this.eliminated.add(connId);
      if (error.code === WebnatErrorCode.CLOSED) {
        this.sawClosed = true;
      }
      // 全部连接都被淘汰且从未出现胜者：兜底失败
      if (this.eliminated.size >= this.total) {
        this.finish(undefined, this.sawClosed ? WebnatError.closed() : WebnatError.unimplemented(this.methodName));
      }
      return;
    }

    // 成功或真实业务错误：该连接抢跑获胜并直接终结
    this.winnerId = connId;
    this.cancelLosers(connId);
    this.finish(result, error);
  }

  /** 判断错误是否属于「淘汰类」（不抢跑、不获胜，只移出候选池） */
  private isEliminating(error: WebnatError): boolean {
    return error.code === WebnatErrorCode.UNIMPLEMENTED || error.code === WebnatErrorCode.CLOSED;
  }

  /** 取消除 except 外的所有子调用（给落败 frame 发 abort） */
  private cancelLosers(except: string): void {
    const losers: AbortController[] = [];
    const keys: string[] = [];
    this.controllers.forEach((controller: AbortController, id: string): void => {
      if (id !== except) {
        losers.push(controller);
        keys.push(id);
      }
    });
    // 先从表中移除再逐个取消：取消会同步触发子调用 reject，避免重入时重复处理
    keys.forEach((id: string): void => {
      this.controllers.delete(id);
    });
    losers.forEach((c: AbortController): void => {
      c.abort();
    });
  }

  /** 终结整组调用：幂等，仅 resolve/reject 一次并触发收尾钩子 */
  private finish(result: ESObject, error: WebnatError | null): void {
    if (this.settled) {
      return;
    }
    this.settled = true;
    if (this.timer !== undefined) {
      clearTimeout(this.timer);
      this.timer = undefined;
    }
    if (this.outerSignal && this.outerSignalAbort) {
      this.outerSignal.removeEventListener('abort', this.outerSignalAbort);
    }
    // abort 所有剩余子调用（胜者的已完成，abort 为 no-op；落败者收到 abort）
    const remaining: AbortController[] = [];
    this.controllers.forEach((c: AbortController): void => {
      remaining.push(c);
    });
    this.controllers.clear();
    remaining.forEach((c: AbortController): void => {
      c.abort();
    });

    if (error) {
      this.rejectFn?.(error);
    } else {
      this.resolveFn?.(result ?? null);
    }
    this.onFinished();
  }
}

/**
 * MethodWebnat - 方法调用消息传递器
 *
 * 实现请求-响应模式的远程方法调用（RPC）机制。
 *
 * 适用场景：
 * - 需要获取返回值的方法调用
 * - 异步操作（如文件读取、网络请求等）
 * - 需要超时控制的场景
 * - 需要主动取消的长时间操作
 *
 * 特点：
 * - 支持双向方法调用（Native 调用 Web 和 Web 调用 Native）
 * - 基于 Promise 的异步调用
 * - 支持超时控制
 * - 支持主动取消正在执行的方法
 * - 自动错误传递
 * - 每个调用有唯一 ID，支持并发多个调用
 *
 * 消息格式：使用 Message 协议，包含 invoke、reply、notify、abort 字段
 * - 调用请求：`{ from: string, to: string, invoke: { id: string, method: string, param?: ESObject } }`
 * - 调用结果：`{ from: string, to: string, reply: { id: string, result?: ESObject, error?: ESObject } }`
 * - 调用通知：`{ from: string, to: string, notify: { id: string, param?: ESObject } }`
 * - 取消请求：`{ from: string, to: string, abort: { id: string } }`
 */

import { util } from '@kit.ArkTS';
import { WebnatError, WebnatErrorCode } from './error';
import { Message } from './message';
import { Connection, ConnectionImpl } from './connection';
import { AbortController, AbortSignal } from './abortController';

export interface MethodFunc {
  method: string;
  param?: ESObject;
}

export interface MethodOptions {
  timeout?: number;
  onNotification?: (param: ESObject) => void;
  signal?: AbortSignal;
}

export class MethodWebnat {
  /**
   * 方法处理函数映射表
   *
   * key: 方法名称
   * value: 方法处理函数
   *
   * 用于处理来自对端的方法调用请求
   *
   * 注意：每个方法名称只能注册一个处理函数
   */
  private listeners: Map<string, (param: ESObject, signal: AbortSignal, notify: (param: ESObject) => void,
    connection: Connection) => Promise<ESObject>> = new Map();
  /**
   * 调用通知回调函数映射表
   *
   * key: 调用 ID
   * value: 通知回调函数
   *
   * 用于在方法调用过程中发送通知
   */
  private onNotifications: Map<string, (param: ESObject) => void> = new Map();
  /**
   * 调用完成回调函数映射表
   *
   * key: 调用 ID
   * value: 完成回调函数（接收 result 或 error）
   *
   * 用于在收到方法调用结果时 resolve 或 reject 对应的 Promise
   */
  private onCompletes: Map<string, (result?: ESObject, error?: WebnatError | null) => void> = new Map();
  /**
   * 连接关闭时的清理回调映射表
   *
   * key: 连接 ID
   * value: 该连接上所有待完成调用的清理回调，嵌套 Map key 为调用 ID，value 为清理回调函数
   */
  private onCloses: Map<string, Map<string, () => void>> = new Map();
  /**
   * 调用取消函数映射表
   *
   * key: 调用 ID
   * value: 取消函数
   *
   * 用于主动取消正在执行的方法调用
   */
  private aborts: Map<string, () => void> = new Map();

  // ==================== 公共 API ====================

  /**
   * 注册方法处理器
   *
   * 注册方法监听器以响应来自 Web 端的方法调用请求。
   *
   * **重要**：每个方法名称只能有一个处理器，重复注册会覆盖之前的处理器。
   *
   * @param method 方法名称，用于标识要处理的方法
   * @param listener 方法处理器，当收到对应方法的调用请求时会被调用
   * @param listener.param Web 端调用时传递的参数
   * @param listener.signal AbortSignal，当调用被取消时会触发 abort 事件
   * @param listener.notify 通知函数，用于在执行过程中主动向调用方发送通知
   * @param listener.connection 调用来源连接
   * @returns Promise，resolve 时返回方法执行结果
   */
  on(method: string, listener: (param: ESObject, signal: AbortSignal, notify: (param: ESObject) => void,
    connection: Connection) => Promise<ESObject>) {
    this.listeners.set(method, listener);
  }

  /**
   * 移除方法处理器
   *
   * 从监听器映射表中移除指定名称和处理器的组合。
   *
   * @param method 方法名称
   * @param listener 要移除的方法处理器（必须与注册时的函数引用完全相同）
   */
  off(method: string, listener: (param: ESObject, signal: AbortSignal, notify: (param: ESObject) => void,
    connection: Connection) => Promise<ESObject>) {
    if (listener === this.listeners.get(method)) {
      this.listeners.delete(method);
    }
  }

  /**
   * 调用 Web 端方法
   *
   * 发起远程方法调用，支持超时和取消。这是一个异步操作，结果通过 Promise 返回。
   *
   * **调用流程**：
   * 1. 生成唯一调用 ID
   * 2. 设置超时定时器（如有传入）
   * 3. 注册完成回调和通知回调
   * 4. 发送调用请求消息
   * 5. 等待结果、超时或被取消
   * 6. 清理回调和定时任务
   *
   * @param func 方法描述对象
   * @param func.method 要调用的方法名称
   * @param func.param 方法参数，可以是任意可序列化的对象，可选
   * @param options 调用选项，可选
   * @param options.timeout 超时时间（毫秒），超时后会自动取消调用并抛出超时错误
   * @param options.onNotification 接收到途中的通知时回调，用于接收方法执行过程中的进度或状态更新
   * @param options.signal 可选，AbortSignal，用于主动取消操作；若传入时已处于 aborted 状态，立即抛出取消错误（与 Web 端语义一致）
   * @param connection 目标连接，如果为 undefined 则报错
   * @returns Promise<ESObject>，resolve 时返回方法执行结果，reject 时返回错误
   * @throws {WebnatError} 方法执行错误，包括：
   *   - 超时错误（WebnatErrorCode.TIMEOUT）
   *   - 取消错误（WebnatErrorCode.CANCELLED）
   *   - 连接关闭错误（WebnatErrorCode.CLOSED）
   *   - 其他执行错误
   */
  async method(func: MethodFunc, options?: MethodOptions, connection?: Connection,): Promise<ESObject> {
    if (!connection) {
      throw WebnatError.closed();
    }
    if (options?.signal?.aborted) {
      throw WebnatError.cancelled();
    }
    const id = util.generateRandomUUID();
    const conn = connection as ConnectionImpl;

    let cancelAbort: () => void = () => {
    };
    let cancelTimeout: () => void = () => {
    };
    let cancelOnNotification: () => void = () => {
    };
    let cancelOnClose: () => void = () => {
    };

    try {
      return await new Promise<ESObject>((resolve, reject) => {
        this.onCompletes.set(id, (result?: ESObject, error?: WebnatError | null) => {
          if (error) {
            reject(error);
          } else {
            resolve(result ?? null);
          }
        });

        const signal = options?.signal;
        if (signal) {
          const abort = (): void => {
            const onComplete = this.onCompletes.get(id);
            if (!onComplete) {
              return;
            }
            onComplete(undefined, WebnatError.cancelled());
            void conn.trySend(Message.abort(connection.id, id));
          };
          signal.addListener(abort);
          cancelAbort = (): void => {
            signal.removeListener(abort);
          };
        }

        const timeout = options?.timeout;
        if (timeout !== undefined && timeout > 0) {
          const timer = setTimeout((): void => {
            const onComplete = this.onCompletes.get(id);
            if (!onComplete) {
              return;
            }
            onComplete(undefined, WebnatError.timeout());
            void conn.trySend(Message.abort(connection.id, id));
          }, timeout);
          cancelTimeout = (): void => {
            clearTimeout(timer);
          };
        }

        const onNotification = options?.onNotification;
        if (onNotification) {
          this.onNotifications.set(id, onNotification);
          cancelOnNotification = (): void => {
            this.onNotifications.delete(id);
          };
        }

        let onClosesMap = this.onCloses.get(connection.id);
        if (!onClosesMap) {
          onClosesMap = new Map();
          this.onCloses.set(connection.id, onClosesMap);
        }
        onClosesMap.set(id, (): void => {
          const onComplete = this.onCompletes.get(id);
          if (!onComplete) {
            return;
          }
          onComplete(undefined, WebnatError.closed());
        });
        cancelOnClose = (): void => {
          const m = this.onCloses.get(connection.id);
          if (m) {
            m.delete(id);
            if (m.size === 0) {
              this.onCloses.delete(connection.id);
            }
          }
        };

        const invokeMessage = Message.invoke(connection.id, id, func.method, func.param);
        void conn.send(invokeMessage).catch((err: ESObject): void => {
          const onComplete = this.onCompletes.get(id);
          if (!onComplete) {
            return;
          }
          const w = WebnatError.from(err);
          onComplete(undefined, w ?? new WebnatError(WebnatErrorCode.UNKNOWN, 'Send failed'));
        });
      });
    } finally {
      this.onCompletes.delete(id);
      cancelOnNotification();
      cancelAbort();
      cancelTimeout();
      cancelOnClose();
    }
  }

  // ==================== 消息接收 ====================

  /**
   * 接收到消息时的回调
   *
   * 处理四种类型的方法消息：
   * 1. `reply`: 方法调用结果（收到我们发起的调用响应）
   * 2. `invoke`: 方法调用请求（Web 端请求 Native 方法）
   * 3. `abort`: 取消方法调用
   * 4. `notify`: 方法途中的通知（如进度/信息）
   *
   * @param message 接收到的消息（已解析的 `Message` 对象）
   * @param connection 消息来源连接
   */
  receive = async (message: Message, connection: Connection): Promise<void> => {
    if (message.reply) {
      const reply = message.reply;
      const id = reply.id;
      const result: ESObject = reply.result;
      const errorField: ESObject = reply.error;
      const onComplete = this.onCompletes.get(id);
      if (onComplete) {
        if (errorField !== undefined && errorField !== null) {
          const w = WebnatError.from(errorField);
          onComplete(result, w ?? new WebnatError(WebnatErrorCode.UNKNOWN, 'Unknown Error'));
        } else {
          onComplete(result, null);
        }
      }
      return;
    }
    if (message.abort) {
      const abort = message.abort;
      const id = abort.id;
      this.aborts.get(id)?.();
      return;
    }
    if (message.notify) {
      const notify = message.notify;
      const id = notify.id;
      const param: ESObject = notify.param;
      const onNotification = this.onNotifications.get(id);
      if (onNotification) {
        onNotification(param);
      }
      return;
    }
    if (message.invoke) {
      const invoke = message.invoke;
      const id = invoke.id;
      const method = invoke.method;
      const param: ESObject = invoke.param;
      if (!id || typeof id !== 'string') {
        return;
      }
      const listener = this.listeners.get(method);
      if (!listener) { // 方法未实现，返回错误
        const error = WebnatError.unimplemented(method);
        const replyMessage = Message.reply(connection.id, id, undefined, error);
        (connection as ConnectionImpl).trySend(replyMessage);
        return;
      }
      const abortController = new AbortController();
      let settled = false;

      const clean = (): void => {
        this.aborts.delete(id);
        const onClosesForConn = this.onCloses.get(connection.id);
        if (onClosesForConn) {
          onClosesForConn.delete(id);
          if (onClosesForConn.size === 0) {
            this.onCloses.delete(connection.id);
          }
        }
      };

      const complete = (result: ESObject | undefined, error: WebnatError | null): void => {
        if (settled) {
          return;
        }
        settled = true;
        clean();
        if (error) {
          const replyMessage = Message.reply(connection.id, id, undefined, error);
          (connection as ConnectionImpl).trySend(replyMessage);
        } else {
          const replyMessage = Message.reply(connection.id, id, result, undefined);
          (connection as ConnectionImpl).trySend(replyMessage);
        }
      };

      this.aborts.set(id, (): void => {
        if (settled) {
          return;
        }
        settled = true;
        clean();
        abortController.abort();
      });

      let onClosesMap = this.onCloses.get(connection.id);
      if (!onClosesMap) {
        onClosesMap = new Map();
        this.onCloses.set(connection.id, onClosesMap);
      }
      onClosesMap.set(id, (): void => {
        if (settled) {
          return;
        }
        settled = true;
        clean();
        abortController.abort();
      });

      const notify = (nParam: ESObject): void => {
        if (settled) {
          return;
        }
        const notifyMessage = Message.notify(connection.id, id, nParam);
        (connection as ConnectionImpl).trySend(notifyMessage);
      };

      const listenerPromise: Promise<ESObject> = listener(param, abortController.signal, notify, connection);
      await listenerPromise.then((result: ESObject): void => {
        complete(result, null);
      }).catch((err: ESObject): void => {
        const w = WebnatError.from(err);
        complete(undefined, w ?? new WebnatError(WebnatErrorCode.UNKNOWN, 'Unknown Error'));
      });
      return;
    }
  }
  // ==================== 生命周期方法 ====================

  /**
   * 连接打开时的回调
   *
   * 将新连接添加到连接列表中，后续可向其发送方法调用请求。
   *
   * @param _connection 新打开的连接对象（Connection 实例）
   */
  onConnectionOpen = (_connection: Connection): void => {
    // MethodWebnat 不需要维护连接列表
  }
  
  /**
   * 连接关闭时的回调
   *
   * 触发该连接上所有待完成调用的清理回调（返回连接关闭错误），并从连接列表中移除。
   *
   * @param connection 已关闭的连接对象（Connection 实例）
   */
  onConnectionClose = (connection: Connection): void => {
    // 获取该连接的所有清理回调
    const onCloses = this.onCloses.get(connection.id);
    if (onCloses) {
      // 执行所有该连接上的清理回调
      // 这包括：
      // 1. 取消该连接上所有正在执行的方法调用（作为被调用方）
      // 2. 通知该连接上所有等待结果的调用：连接已关闭（作为调用方）
      const callbacks = Array.from(onCloses.values());
      callbacks.forEach(callback => {
        callback();
      });
      // 清理该连接相关的资源
      this.onCloses.delete(connection.id);
    }
  };
}


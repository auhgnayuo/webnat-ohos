/**
 * AbortController - 取消控制器
 *
 * 提供取消异步操作的能力，API 与 Node.js / Web 标准的 AbortController 保持一致。
 *
 * 适用场景：
 * - 需要取消正在执行的方法调用
 * - 超时控制
 * - 用户主动取消操作
 *
 * 使用方式：
 * ```typescript
 * const controller = new AbortController()
 * const signal = controller.signal
 *
 * // 在异步操作中监听取消信号
 * signal.addEventListener('abort', (event: AbortEvent): void => {
 *   // 执行清理逻辑
 * })
 *
 * // 取消操作，可选传入原因（缺省为 name 为 AbortError 的 Error）
 * controller.abort()
 * ```
 */
export class AbortController {
  /** 取消信号，用于监听取消事件 */
  readonly signal: AbortSignal = new AbortSignalImpl();

  /**
   * 取消操作
   *
   * 将信号置为已取消并触发 abort 事件。多次调用只有第一次生效。
   *
   * @param reason 取消原因，缺省为 name 为 AbortError 的 Error
   */
  abort(reason?: ESObject): void {
    (this.signal as AbortSignalImpl).abort(reason);
  }
}

/** abort 事件对象，作为事件监听器的参数传入 */
export class AbortEvent {
  /** 事件类型，固定为 'abort' */
  readonly type: string = 'abort';
  /** 触发该事件的信号 */
  readonly target: AbortSignal;

  constructor(target: AbortSignal) {
    this.target = target;
  }
}

/** addEventListener 的选项 */
export interface AddEventListenerOptions {
  /** 仅为与 Web 签名兼容：abort 事件只会触发一次，该选项不改变行为 */
  once?: boolean;
}

/**
 * AbortSignal - 取消信号接口
 *
 * 表示一个可取消的信号，用于监听取消事件。API 与 Node.js / Web 标准的 AbortSignal 保持一致。
 * 与标准一致：对已处于取消状态的信号注册监听器不会触发回调，请先判断 aborted。
 */
export interface AbortSignal {
  /** 是否已取消，只读属性 */
  readonly aborted: boolean;

  /** 取消原因，未取消时为 undefined，只读属性 */
  readonly reason: ESObject;

  /** 取消时的事件处理函数，与通过 addEventListener 注册的监听器按首次设置的先后顺序调用 */
  onabort: ((event: AbortEvent) => void) | null;

  /**
   * 注册取消监听器
   *
   * 重复注册同一个监听器只会生效一次；type 仅支持 'abort'，其他类型会被忽略。
   *
   * @param type 事件类型，固定为 'abort'
   * @param listener 取消时的监听器
   * @param options 监听选项
   */
  addEventListener(type: string, listener: (event: AbortEvent) => void, options?: AddEventListenerOptions): void;

  /**
   * 移除取消监听器
   *
   * @param type 事件类型，固定为 'abort'
   * @param listener 要移除的监听器（必须与注册时的引用完全相同）
   */
  removeEventListener(type: string, listener: (event: AbortEvent) => void): void;

  /**
   * 若信号已取消，则抛出 reason
   */
  throwIfAborted(): void;

  /**
   * 注册取消监听器
   *
   * 与 addEventListener 不同：如果信号已经处于取消状态，监听器会立即被调用。
   *
   * @deprecated 请使用 addEventListener('abort', listener)
   * @param listener 取消时的监听器
   */
  addListener(listener: () => void): void;

  /**
   * 移除取消监听器
   *
   * @deprecated 请使用 removeEventListener('abort', listener)
   * @param listener 要移除的监听器（必须与注册时的引用完全相同）
   */
  removeListener(listener: () => void): void;
}

function createAbortError(): Error {
  const error = new Error('This operation was aborted');
  error.name = 'AbortError';
  return error;
}

/**
 * AbortSignalImpl - 取消信号实现类
 *
 * 实现 AbortSignal 接口，提供取消信号的具体功能。
 */
class AbortSignalImpl implements AbortSignal {
  aborted: boolean = false;
  reason: ESObject = undefined;
  /** 有序的监听器集合，onabort 与 addListener 的适配函数也在其中 */
  private listeners: Set<(event: AbortEvent) => void> = new Set();
  /** addListener 注册的原始监听器 -> 适配函数，供 removeListener 查找 */
  private legacyListeners: Map<() => void, (event: AbortEvent) => void> = new Map();
  private handler: ((event: AbortEvent) => void) | null = null;
  private handlerAttached: boolean = false;

  get onabort(): ((event: AbortEvent) => void) | null {
    return this.handler;
  }

  set onabort(value: ((event: AbortEvent) => void) | null) {
    this.handler = value;
    // 首次设置时占位，之后重新赋值不改变它在监听器中的顺序
    if (value !== null && !this.handlerAttached && !this.aborted) {
      this.handlerAttached = true;
      this.listeners.add((event: AbortEvent): void => {
        const current = this.handler;
        if (current !== null) {
          current(event);
        }
      });
    }
  }

  addEventListener(type: string, listener: (event: AbortEvent) => void): void {
    // 已取消的信号不会再触发事件，无需保留监听器
    if (type !== 'abort' || this.aborted) {
      return;
    }
    this.listeners.add(listener);
  }

  removeEventListener(type: string, listener: (event: AbortEvent) => void): void {
    if (type === 'abort') {
      this.listeners.delete(listener);
    }
  }

  throwIfAborted(): void {
    if (this.aborted) {
      throw this.reason as Error;
    }
  }

  addListener(listener: () => void): void {
    if (this.aborted) {
      listener();
      return;
    }
    if (this.legacyListeners.has(listener)) {
      return;
    }
    const adapter: (event: AbortEvent) => void = (): void => {
      listener();
    };
    this.legacyListeners.set(listener, adapter);
    this.listeners.add(adapter);
  }

  removeListener(listener: () => void): void {
    const adapter = this.legacyListeners.get(listener);
    if (adapter !== undefined) {
      this.legacyListeners.delete(listener);
      this.listeners.delete(adapter);
    }
  }

  abort(reason?: ESObject): void {
    if (this.aborted) {
      return;
    }
    this.aborted = true;
    this.reason = reason !== undefined ? reason : createAbortError();
    const event = new AbortEvent(this);
    const snapshot: Array<(event: AbortEvent) => void> = [];
    this.listeners.forEach((listener: (event: AbortEvent) => void): void => {
      snapshot.push(listener);
    });
    for (const listener of snapshot) {
      // 被前面的监听器移除的不再调用
      if (!this.listeners.has(listener)) {
        continue;
      }
      try {
        listener(event);
      } catch {
        // 忽略监听器错误，确保所有监听器都能被调用
      }
    }
    this.listeners.clear();
    this.legacyListeners.clear();
  }
}

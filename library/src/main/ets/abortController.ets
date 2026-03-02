/**
 * AbortController - 取消控制器
 *
 * 提供取消异步操作的能力，类似于 Web 标准的 AbortController。
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
 * signal.addListener(() => {
 *   // 执行清理逻辑
 * })
 * 
 * // 取消操作
 * controller.abort()
 * ```
 */
export class AbortController {
  /** 取消信号，用于监听取消事件 */
  readonly signal: AbortSignal = new AbortSignalImpl();

  /**
   * 取消操作
   *
   * 触发取消信号，通知所有监听器操作已被取消。
   * 多次调用此方法不会产生副作用。
   */
  abort(): void {
    (this.signal as AbortSignalImpl).abort();
  }
}

/**
 * AbortSignal - 取消信号接口
 *
 * 表示一个可取消的信号，用于监听取消事件。
 *
 * 特点：
 * - 只读的 aborted 属性，表示是否已取消
 * - addListener 方法用于注册取消监听器
 * - addListener 返回一个取消函数，用于移除监听器
 */
export interface AbortSignal {
  /**
   * 注册取消监听器
   *
   * 注册一个监听器，当操作被取消时会调用该监听器。
   * 如果信号已经处于取消状态，监听器会立即被调用。
   *
   * @param listener 取消时的监听器
   * @returns 返回一个函数，调用该函数可以移除监听器
   */
  addListener(listener: () => void): void;

  /**
   * 移除取消监听器
   *
   * 从监听器集合中移除指定的监听器
   *
   * @param listener 要移除的监听器（必须与注册时的引用完全相同）
   */
  removeListener(listener: () => void): void;

  /** 是否已取消，只读属性 */
  readonly aborted: boolean;
}

/**
 * AbortSignalImpl - 取消信号实现类
 *
 * 实现 AbortSignal 接口，提供取消信号的具体功能。
 */
class AbortSignalImpl implements AbortSignal {
  /** 监听器集合，存储所有注册的取消监听器 */
  private listeners: Set<() => void> = new Set();
  /** 是否已取消 */
  aborted: boolean = false;

  /**
   * 注册取消监听器
   *
   * 如果信号已经处于取消状态，监听器会立即被调用。
   * 否则，监听器会被注册到监听器集合中。
   *
   * @param listener 取消时的监听器
   */
  addListener(listener: () => void): void {
    if (this.aborted) {
      // 如果已经取消，立即调用监听器
      listener();
      // 返回一个空函数，因为监听器已经被调用，不需要移除
      return;
    }
    // 注册监听器到集合
    this.listeners.add(listener);
  }

  /**
   * 移除取消监听器
   *
   * 从监听器集合中移除指定的监听器
   *
   * @param listener 要移除的监听器（必须与注册时的引用完全相同）
   */
  removeListener(listener: () => void): void {
    this.listeners.delete(listener);
  }

  /**
   * 取消操作
   *
   * 标记信号为已取消状态，并通知所有注册的监听器。
   * 多次调用此方法不会产生副作用。
   */
  abort(): void {
    if (this.aborted) {
      // 已经取消，直接返回
      return;
    }
    // 标记为已取消
    this.aborted = true;
    // 获取所有监听器的副本（避免在遍历时修改集合）
    const fns = this.listeners;
    // 通知所有监听器
    for (const fn of fns) {
      try {
        fn();
      } catch {
        // 忽略监听器错误，确保所有监听器都能被调用
      }
    }
    // 清空监听器集合
    this.listeners.clear();
  }
}
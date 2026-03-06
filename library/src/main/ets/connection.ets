import { WebnatError } from './error';
import { Message } from './message';

/**
 * Connection 接口
 *
 * 表示 Native 端与 Web 端之间的单个连接。
 *
 * 核心职责：
 * 1. 管理连接的生命周期状态
 * 2. 提供消息发送能力
 * 3. 携带连接的元数据（attributes）
 *
 * 连接类型：
 * - 主框架连接：对应 Web 端页面的主框架
 * - iframe 连接：对应 Web 端页面中的 iframe
 *
 * 每个 WebView 可以有多个连接（主框架 + 多个 iframe）
 */
export interface Connection {
  /** 连接的唯一标识符，由 Web 端生成 */
  readonly id: string;

  /** 连接的元数据，在连接建立时由 Web 端传递，包含连接的附加信息 */
  readonly attributes?: Record<string, ESObject>;

  /** 当前连接的界面 URL，在连接建立时当前页面的地址 */
  readonly url?: string;

  /** 连接是否已关闭 */
  readonly closed: boolean;
}

/**
 * ConnectionImpl - 连接实现类
 *
 * 实现 Connection 接口，提供连接的具体功能。
 */
export class ConnectionImpl implements Connection {
  /** 连接的唯一标识符 */
  id: string;
  /** 连接的元数据 */
  attributes?: Record<string, ESObject>;
  /** 当前连接的界面 URL，在连接建立时当前页面的地址 */
  url?: string;
  /** 连接是否已关闭 */
  closed: boolean = false;
  /** 消息发送函数，由创建 Connection 时注入，封装了实际的消息发送逻辑 */
  private sendMessage: (message: Message) => Promise<void>;

  /**
   * 构造函数
   *
   * @param id 连接 ID
   * @param attributes 连接元数据
   * @param url 当前连接的界面 URL，可选
   * @param sendMessage 消息发送函数，用于向 Web 端发送消息
   */
  constructor(id: string, attributes: Record<string, ESObject>, url: string | undefined, sendMessage: (message: Message) => Promise<void>) {
    this.id = id;
    this.attributes = attributes;
    this.url = url;
    this.sendMessage = sendMessage;
  }

  /**
   * 发送消息到 Web 端
   *
   * 如果连接已关闭，会立即抛出 WebnatError 错误，不会实际发送消息。
   * 此方法是异步的，发送结果通过 Promise 返回。
   *
   * @param message 要发送的消息
   * @throws {WebnatError} 如果连接已关闭，抛出 WebnatErrorCode.CLOSED 错误
   *
   * @example
   * ```typescript
   * try {
   *   const message = Message.raw(Message.NATIVE_UUID, { data: 'test' })
   *   await connection.send(message)
   *   console.log('Message sent successfully')
   * } catch (error) {
   *   if (error.code === WebnatErrorCode.CLOSED) {
   *     console.error('Connection is closed')
   *   }
   * }
   * ```
   */
  async send(message: Message): Promise<void> {
    if (this.closed) {
      throw WebnatError.closed();
    }
    await this.sendMessage(message);
  }

  /**
   * 尝试发送消息到 Web 端
   *
   * 与 send 方法不同，此方法不会抛出异常，而是静默失败。
   * 适用于在连接可能已关闭的情况下发送消息，如清理资源时。
   *
   * @param message 要发送的消息
   *
   * @example
   * ```typescript
   * // 在清理资源时使用，不关心是否成功
   * const message = Message.close(connection.id, { reason: 'cleanup' })
   * await connection.trySend(message)
   * ```
   */
  async trySend(message: Message): Promise<void> {
    try {
      await this.send(message);
    } catch (_) {
      // 静默忽略错误
    }
  }

  /**
   * 释放连接资源
   *
   * 标记连接为已关闭状态，之后调用 send 方法会抛出错误。
   * 通常在连接关闭时调用，用于清理资源。
   *
   * **注意**：此方法只修改本地状态，不会向 Web 端发送关闭消息。
   */
  dispose(): void {
    this.closed = true;
  }
}

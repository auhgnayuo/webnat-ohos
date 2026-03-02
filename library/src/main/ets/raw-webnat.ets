/**
 * RawWebnat - 原始消息传递器
 *
 * 提供最基础的消息发送和接收功能，不做任何额外处理。
 *
 * 适用场景：
 * - 简单的数据传输
 * - 不需要消息分类的场景
 * - 自定义消息格式的场景
 *
 * 消息格式：使用 Message 协议，包含 raw 字段
 * - 原始消息：`{ from: string, to: string, raw: { param?: ESObject } }`
 */

import { Message } from './message';
import { Connection, ConnectionImpl } from './connection';

export class RawWebnat {

  /** 原始消息接收回调函数列表 */
  private listeners: ((param: ESObject, connection: Connection) => void)[] = [];

  // ==================== 公共 API ====================

  /**
   * 注册原始消息监听器
   *
   * 可以注册多个监听器，所有监听器都会收到相同的消息。
   * 如果同一个监听器引用已存在，则先移除旧的再添加新的。
   *
   * @param listener 消息监听回调
   * @param listener.param 接收到的消息内容，可以是任意可序列化的对象
   * @param listener.connection 消息来源的连接对象
   */
  on = (listener: (param: ESObject, connection: Connection) => void) => {
    // 如果已存在，先移除再添加（防止重复注册）
    const index = this.listeners.indexOf(listener);
    if (index !== -1) {
      this.listeners.splice(index, 1);
    }
    this.listeners.push(listener);
  };

  /**
   * 移除原始消息监听器
   *
   * 使用引用相等性来匹配监听器，只有完全相同的引用才会被移除。
   *
   * @param listener 要移除的监听器（必须与注册时的函数引用完全相同）
   */
  off = (listener: (param: ESObject, connection: Connection) => void) => {
    this.listeners = this.listeners.filter(item => item !== listener);
  };

  /**
   * 发送原始消息到指定连接
   *
   * 将消息包装为 Message 格式后发送到 Web 端。
   *
   * @param param 消息体，可以是任意可序列化的对象（String、Number、Object、Array 等）
   * @param connection 目标连接，如果连接已关闭则不会发送
   */
  raw = (param: ESObject, connection: Connection): void => {
    const message = Message.raw(connection.id, param);
    (connection as ConnectionImpl).trySend(message);
  }

  // ==================== 消息接收 ====================

  /**
   * 接收消息
   *
   * 从 Message 对象中提取原始消息并分发给所有回调函数。
   *
   * @param message Message 对象，必须包含 raw 字段
   * @param connection 消息来源连接
   */
  receive = (message: Message, connection: Connection): void => {
    if (!message.raw) {
      return;
    }
    const param: ESObject = message.raw.param;
    // 创建快照，避免回调函数中修改列表导致的问题
    const snapshot = this.listeners.slice();
    snapshot.forEach(listener => {
      try {
        listener(param, connection);
      } catch (error) {
        // 忽略回调错误
      }
    });
  };

  // ==================== 生命周期方法 ====================

  /**
   * 连接打开时的回调
   *
   * @param connection 新打开的连接
   */
  onConnectionOpen = (_connection: Connection): void => {
  }

  /**
   * 连接关闭时的回调
   *
   * @param connection 已关闭的连接
   */
  onConnectionClose = (_connection: Connection): void => {
  }
}


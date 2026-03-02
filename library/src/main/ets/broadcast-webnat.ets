/**
 * BroadcastWebnat - 广播消息传递器
 *
 * 实现发布-订阅模式的消息传递机制。
 *
 * 适用场景：
 * - 事件通知（如数据更新、状态变更）
 * - 一对多的消息分发
 * - 不需要返回值的通知场景
 *
 * 特点：
 * - 支持多个订阅者
 * - 按事件名称分类
 * - 不需要响应
 *
 * 消息格式：使用 Message 协议，包含 broadcast 字段
 * - 广播消息：`{ from: string, to: string, broadcast: { name: string, param?: ESObject } }`
 */

import { Message } from './message';
import { Connection, ConnectionImpl } from './connection';
import { WebnatError } from './error';

export class BroadcastWebnat {

  /**
   * 广播事件回调函数映射表
   *
   * key: 广播事件名称
   * value: 该事件的回调函数数组
   */
  private listeners: Map<string, ((param: ESObject, connection: Connection) => void)[]> = new Map();

  // ==================== 公共 API ====================

  /**
   * 订阅广播消息
   *
   * 注册指定事件名称的监听器，当收到对应事件的广播时触发回调。
   * 可以注册多个监听器监听同一事件，所有监听器都会收到通知。
   *
   * @param name 广播事件名称，用于标识不同的事件类型
   * @param listener 接收到广播时的回调函数
   * @param listener.param 广播携带的参数，可以是任意可序列化的对象
   * @param listener.connection 消息来源的连接对象
   */
  on = (name: string, listener: (param: ESObject, connection: Connection) => void) => {
    const listeners = this.listeners.get(name);
    if (!listeners) {
      // 首次订阅该事件，创建新的回调函数数组
      this.listeners.set(name, [listener]);
    } else {
      // 如果已存在，先移除再添加（防止重复注册）
      const index = listeners.indexOf(listener);
      if (index !== -1) {
        listeners.splice(index, 1);
      }
      listeners.push(listener);
    }
  };

  /**
   * 取消订阅广播消息
   *
   * 移除指定事件名称下的特定监听器，使用引用相等性进行匹配。
   *
   * @param name 广播事件名称
   * @param listener 要移除的监听器（必须与注册时的函数引用完全相同）
   */
  off = (name: string, listener: (param: ESObject, connection: Connection) => void) => {
    const listeners = this.listeners.get(name);
    if (listeners) {
      const filteredListeners = listeners.filter(item => item !== listener);
      if (filteredListeners.length === 0) {
        // 没有订阅者了，删除该事件的映射
        this.listeners.delete(name);
      } else {
        // 还有其他订阅者，更新回调函数数组
        this.listeners.set(name, filteredListeners);
      }
    }
  };

  /**
   * 广播消息
   *
   * 向指定连接或所有连接发送广播消息。如果 `connection` 为 `undefined`，则向所有当前活跃的连接广播。
   *
   * @param name 广播事件名称，用于标识事件类型
   * @param params 广播参数，可以是任意可序列化的对象，可选
   * @param connection 目标连接，如果为 `undefined` 则广播到所有连接
   */
  broadcast = (name: string, params?: ESObject, connection?: Connection): void => {
    if (connection) {
      const message = Message.broadcast(connection.id, name, params);
      (connection as ConnectionImpl).trySend(message);
    }
  }

  // ==================== 消息接收 ====================

  /**
   * 接收消息
   *
   * 从 Message 对象中提取广播消息，并根据事件名称分发给对应的订阅者。
   *
   * @param message Message 对象，必须包含 broadcast 字段
   * @param connection 消息来源连接
   */
  receive = (message: Message, connection: Connection): void => {
    if (!message.broadcast) {
      return;
    }
    const name = message.broadcast.name;
    const params: ESObject = message.broadcast.param;
    if (!name || typeof name !== 'string') {
      throw WebnatError.deserializationFailed(message.broadcast);
    }
    // 触发该事件名称的所有回调函数
    const listeners = this.listeners.get(name);
    if (listeners) {
      // 创建快照，避免回调函数中修改列表导致的问题
      const snapshot = listeners.slice();
      snapshot.forEach(listener => {
        try {
          listener(params, connection);
        } catch (error) {
          // 忽略回调错误
        }
      });
    }
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


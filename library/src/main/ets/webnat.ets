/**
 * Webnat - Native 与 Web 之间的双向通信框架
 *
 * 提供三种通信模式：
 * 1. **Raw（原始消息）**：最基础的消息传递，不做任何额外处理
 * 2. **Broadcast（广播）**：发布-订阅模式，支持事件通知
 * 3. **Method（方法调用）**：RPC 模式，支持远程方法调用和返回值
 *
 * ## 使用示例
 *
 * ```typescript
 * // 1. 获取 Webnat 实例
 * const webnat = Webnat.of(webviewController)
 *
 * // 2. 注册方法处理器
 * webnat.onMethod('getUserInfo', async (param, signal, notify, connection) => {
 *   return { name: 'John', age: 30 }
 * })
 *
 * // 3. 调用 Web 端方法
 * const result = await webnat.method({ method: 'showAlert', param: { message: 'Hello' } })
 * ```
 */
import { AbortSignal } from './abortController'
import { BroadcastWebnat } from './broadcast-webnat'
import { Connection, ConnectionImpl } from './connection'
import { JavaScriptAliveKeeper } from './javaScriptAliveKeeper'
import { Message } from './message'
import { MethodFunc, MethodOptions, MethodWebnat } from './method-webnat'
import { RawWebnat } from './raw-webnat'
import { WebnatVersion } from './version'
import { webview } from '@kit.ArkWeb'

/**
 * Webnat 类
 *
 * 实现统一消息传递功能，整合所有消息传递能力的门面类。
 */
export class Webnat {

  /**
   * 创建或获取 Webnat 实例
   *
   * 工厂方法，为指定的 WebView Controller 创建或返回已存在的 Webnat 实例。
   * 使用单例模式，确保每个 WebView Controller 只有一个 Webnat 实例。
   *
   * 工作流程：
   * 1. 检查 Controller 是否已有 Webnat 实例（通过 __native_webnat__ 属性）
   * 2. 如果存在，直接返回
   * 3. 如果不存在，创建新实例并注册 JavaScript 代理
   * 4. 将实例保存到 Controller 的 __native_webnat__ 属性中
   *
   * JavaScript 代理：
   * - 注册 __native_webnat__.postMessage 方法到 WebView
   * - Web 端可以通过此方法向 Native 端发送消息
   *
   * @param controller WebView Controller 实例
   * @returns Webnat 实例
   */
  static of(controller: webview.WebviewController): Webnat {
    const ctrl: ESObject = controller;
    let webnat: Webnat = ctrl.__native_webnat__;
    if (webnat) {
      return webnat;
    }
    webnat = new Webnat(controller);
    ctrl.__native_webnat__ = webnat;
    
    const prefix = "Webnat";
    const webnatUA = `${prefix}/${WebnatVersion}`;
    try {
      const existingUA = controller.getCustomUserAgent();
      const components = existingUA.split(" ")
        .filter((c: string) => c.length > 0 && !c.startsWith(prefix));
      controller.setCustomUserAgent([...components, webnatUA].join(" "));
    } catch (_) {
    }
    
    // 注册 JavaScript 代理
    try {
      controller.registerJavaScriptProxy({
        postMessage: (param: string): void => {
          webnat.postMessage(param);
        }
      }, '__native_webnat__', ['postMessage'])
    } catch (error) {
        throw error as Error;
    }
    
    return webnat;
  }

  /**
   * 构造函数
   *
   * 初始化 Webnat 并注册三个消息传递器为连接事件的观察者。
   * 使用 WeakRef 避免与 controller.__native_webnat__ 的循环引用。webnat意外没有释放的话，也不会干扰webview.Controller
   *
   * @param controller WebView Controller 实例
   */
  private constructor(controller: webview.WebviewController) {
    this.webControllerRef = new WeakRef(controller);
    
    // 初始化消息传递器
    this.rawWebnat = new RawWebnat();
    this.broadcastWebnat = new BroadcastWebnat();
    this.methodWebnat = new MethodWebnat();
    // 初始化 JavaScript 保活管理器
    this.javaScriptAliveKeeper = new JavaScriptAliveKeeper(200, () => {
      // 心跳回调：向第一个可用连接发送空消息以保持 JS 活跃
      const connections = Array.from(this.connections.values());
      if (connections.length == 0) {
        return;
      }
      const connection = connections[0];
      this.rawWebnat.raw(null, connection);
    });
  }

  /**
   * 获取所有连接
   *
   * @returns 连接字典，key 为连接 ID，value 为 Connection 实例
   */
  getConnections(): Map<string, Connection> {
    return this.connections;
  }

  // MARK: - 原始消息 API

  /**
   * 注册原始消息监听器
   *
   * 可以注册多个监听器，所有监听器都会收到相同的消息。
   * 如果同一个监听器引用已存在，则先移除旧的再添加新的。
   *
   * @param listener 消息监听器回调
   * @param listener.raw 接收到的消息内容，可以是任意可序列化的对象
   * @param listener.connection 消息来源的连接对象
   *
   * @example
   * ```typescript
   * webnat.onRaw((raw, connection) => {
   *   console.log('Received raw message:', raw)
   *   console.log('From connection:', connection.id)
   * })
   * ```
   */
  onRaw(listener: (raw: ESObject, connection: Connection) => void): void {
    this.rawWebnat.on(listener);
  }

  /**
   * 移除原始消息监听器
   *
   * 使用引用相等性来匹配监听器，只有完全相同的引用才会被移除。
   *
   * @param listener 要移除的监听器（必须与注册时的函数引用完全相同）
   *
   * @example
   * ```typescript
   * const listener = (raw: ESObject, connection: Connection) => {
   *   console.log('Message:', raw)
   * }
   * webnat.onRaw(listener)
   * // ... 使用后移除
   * webnat.offRaw(listener)
   * ```
   */
  offRaw(listener: (raw: ESObject, connection: Connection) => void): void {
    this.rawWebnat.off(listener);
  }

  /**
   * 发送原始消息到指定连接
   *
   * 将消息包装为 Message 格式后发送到 Web 端。
   *
   * @param raw 消息体，可以是任意可序列化的对象（String、Number、Object、Array 等）
   * @param connection 目标连接，如果连接已关闭则不会发送
   *
   * @example
   * ```typescript
   * const connections = Array.from(webnat.getConnections().values())
   * if (connections.length > 0) {
   *   webnat.raw({ key: 'value', timestamp: Date.now() }, connections[0])
   * }
   * ```
   */
  raw(raw: ESObject, connection: Connection): void {
    this.rawWebnat.raw(raw, connection);
  }

  // MARK: - 广播消息 API

  /**
   * 订阅广播消息
   *
   * 注册指定事件名称的监听器，当收到对应事件的广播时触发回调。
   * 可以注册多个监听器监听同一事件，所有监听器都会收到通知。
   *
   * @param name 广播事件名称，用于标识不同的事件类型
   * @param listener 接收到广播时的回调函数
   * @param listener.params 广播携带的参数，可以是任意可序列化的对象
   * @param listener.connection 消息来源的连接对象
   *
   * @example
   * ```typescript
   * webnat.onBroadcast('userLogin', (params, connection) => {
   *   console.log('User logged in:', params)
   *   console.log('User ID:', params.userId)
   *   console.log('Connection:', connection.id)
   * })
   * ```
   */
  onBroadcast(name: string, listener: (params: ESObject, connection: Connection) => void): void {
    this.broadcastWebnat.on(name, listener);
  }

  /**
   * 取消订阅广播消息
   *
   * 移除指定事件名称下的特定监听器，使用引用相等性进行匹配。
   *
   * @param name 广播事件名称
   * @param listener 要移除的监听器（必须与注册时的函数引用完全相同）
   *
   * @example
   * ```typescript
   * const listener = (params: ESObject, connection: Connection) => {
   *   console.log('Event:', params)
   * }
   * webnat.onBroadcast('dataUpdate', listener)
   * // ... 使用后移除
   * webnat.offBroadcast('dataUpdate', listener)
   * ```
   */
  offBroadcast(name: string, listener: (params: ESObject, connection: Connection) => void): void {
    this.broadcastWebnat.off(name, listener);
  }

  /**
   * 广播消息
   *
   * 向指定连接或所有连接发送广播消息。如果 `connection` 为 `undefined`，则向所有当前活跃的连接广播。
   *
   * @param name 广播事件名称，用于标识事件类型
   * @param params 广播参数，可以是任意可序列化的对象，可选
   * @param connection 目标连接，如果为 `undefined` 则广播到所有连接
   *
   * @example
   * ```typescript
   * // 广播到所有连接
   * webnat.broadcast('dataUpdated', { timestamp: Date.now(), data: {...} })
   *
   * // 广播到指定连接
   * const connections = Array.from(webnat.getConnections().values())
   * if (connections.length > 0) {
   *   webnat.broadcast('notification', { message: 'Hello' }, connections[0])
   * }
   * ```
   */
  broadcast(name: string, params?: ESObject, connection?: Connection): void {
    const c = connection ?? (() => {
      const connections = Array.from(this.connections.values());
      return connections.length > 0 ? connections[0] : undefined;
    })();
    this.broadcastWebnat.broadcast(name, params ?? null, c);
  }

  // MARK: - 方法调用 API

  /**
   * 注册方法处理器
   *
   * 注册方法监听器以响应来自 Web 端的方法调用请求。
   *
   * **重要**：每个方法名称只能有一个处理器，重复注册会覆盖之前的处理器。
   *
   * @param name 方法名称，用于标识要处理的方法
   * @param listener 方法处理器回调（异步函数）
   * @param listener.params 方法调用时传入的参数，可以是任意可序列化的对象
   * @param listener.signal AbortSignal，当调用被取消时会触发 abort 事件
   * @param listener.notify 通知回调，用于在方法执行过程中发送进度或状态更新
   * @param listener.connection 调用来源的连接对象
   * @returns Promise，resolve 时返回方法执行结果
   *
   * @example
   * ```typescript
   * webnat.onMethod('getUserInfo', async (params, signal, notify, connection) => {
   *   // 发送进度通知
   *   notify({ progress: 50 })
   *
   *   // 监听取消事件
   *   signal.addListener(() => {
   *     console.log('Method call cancelled')
   *   })
   *
   *   // 执行异步操作
   *   const user = await fetchUserData(params.userId)
   *
   *   // 返回结果
   *   return { name: user.name, age: user.age }
   * })
   * ```
   */
  onMethod(name: string, listener: (
    params: ESObject,
    signal: AbortSignal,
    notify: (notification: ESObject) => void,
    connection: Connection,
  ) => Promise<ESObject>): void {
    this.methodWebnat.on(name, listener);
  }

  /**
   * 移除方法处理器
   *
   * 移除指定方法名称的处理器。使用引用相等性进行匹配。
   *
   * @param name 方法名称
   * @param listener 要移除的方法处理器（必须与注册时的函数引用完全相同）
   *
   * @example
   * ```typescript
   * const handler = async (params: ESObject, signal: AbortSignal, 
   *                        notify: (n: ESObject) => void, connection: Connection) => {
   *   return { result: 'success' }
   * }
   * webnat.onMethod('myMethod', handler)
   * // ... 使用后移除
   * webnat.offMethod('myMethod', handler)
   * ```
   */
  offMethod(name: string, listener: (
    params: ESObject,
    signal: AbortSignal,
    notify: (notification: ESObject) => void,
    connection: Connection,
  ) => Promise<ESObject>): void {
    this.methodWebnat.off(name, listener);
  }

  /**
   * 调用 Web 端方法
   *
   * 执行远程方法调用，支持超时和取消。这是一个异步操作，结果通过 Promise 返回。
   *
   * **执行流程**：
   * 1. 生成唯一调用 ID
   * 2. 设置超时定时器（如果指定）
   * 3. 注册完成回调和通知回调
   * 4. 发送调用请求到 Web 端
   * 5. 等待结果、超时或被取消
   * 6. 清理资源并返回结果或抛出错误
   *
   * @param func 方法调用描述对象
   * @param func.method 要调用的方法名称
   * @param func.param 方法参数，可以是任意可序列化的对象，可选
   * @param options 方法调用选项，可选
   * @param options.timeout 超时时间（毫秒），超时后会自动取消调用并抛出超时错误
   * @param options.onNotification 收到通知时的回调函数，用于接收方法执行过程中的进度或状态更新
   * @param options.signal AbortSignal，用于主动取消调用
   * @param connection 目标连接，如果为 undefined 则选择第一个可用连接
   * @returns Promise，resolve 时返回方法执行结果，reject 时返回错误
   * @throws {WebnatError} 方法执行错误，包括：
   *   - 超时错误（WebnatErrorCode.TIMEOUT）
   *   - 取消错误（WebnatErrorCode.CANCELLED）
   *   - 连接关闭错误（WebnatErrorCode.CLOSED）
   *   - 其他执行错误
   *
   * @example
   * ```typescript
   * // 基本调用
   * try {
   *   const result = await webnat.method({ 
   *     method: 'calculate', 
   *     param: { x: 10, y: 20 } 
   *   })
   *   console.log('Result:', result)
   * } catch (error) {
   *   console.error('Error:', error)
   * }
   *
   * // 带超时和通知的调用
   * const result = await webnat.method(
   *   { method: 'processData', param: { data: [...] } },
   *   { 
   *     timeout: 5000,
   *     onNotification: (progress) => {
   *       console.log('Progress:', progress)
   *     }
   *   }
   * )
   *
   * // 支持取消的调用
   * const abortController = new AbortController()
   * setTimeout(() => abortController.abort(), 3000) // 3秒后取消
   * try {
   *   const result = await webnat.method(
   *     { method: 'longOperation' },
   *     { signal: abortController.signal }
   *   )
   * } catch (error) {
   *   if (error.code === WebnatErrorCode.CANCELLED) {
   *     console.log('Operation cancelled')
   *   }
   * }
   * ```
   */
  async method(func: MethodFunc, options?: MethodOptions, connection?: Connection): Promise<ESObject> {
    const c = connection ?? (() => {
      const connections = Array.from(this.connections.values());
      return connections.length > 0 ? connections[0] : undefined;
    })();
    // 在方法调用期间增加引用，确保 JS 保持活跃
    this.javaScriptAliveKeeper.increaseReference();
    try {
      const result: ESObject = await this.methodWebnat.method(func, options, c);
      return result;
    } finally {
      // 方法调用完成后减少引用
      this.javaScriptAliveKeeper.decreaseReference();
    }
  }

  /**
   * WebView Controller 的弱引用
   *
   * 使用 WeakRef 避免与 controller.__native_webnat__ 的循环引用。
   * 当 WebView Controller 被释放时，此引用会自动变为 undefined。
   */
  private webControllerRef: WeakRef<webview.WebviewController>

  /**
   * 获取 WebView Controller
   *
   * 如果 controller 已被回收，返回 undefined
   *
   * @returns WebView Controller，如果已被回收则返回 undefined
   */
  private getWebController(): webview.WebviewController | undefined {
    return this.webControllerRef.deref();
  }

  /**
   * 连接字典
   *
   * key: 连接 ID（由 Web 端生成）
   * value: Connection 实例
   */
  private connections: Map<string, Connection> = new Map();
  /** 原始消息传递器 */
  private rawWebnat: RawWebnat;
  /** 广播消息传递器 */
  private broadcastWebnat: BroadcastWebnat;
  /** 方法调用消息传递器 */
  private methodWebnat: MethodWebnat;
  /** JavaScript 保活管理器 */
  private javaScriptAliveKeeper: JavaScriptAliveKeeper;

  /**
   * 连接打开时的回调
   *
   * 当连接建立时，通知所有注册的消息传递器
   *
   * @param connection 新打开的连接
   */
  private onConnectionOpen(connection: Connection): void {
    this.connections.set(connection.id, connection);
    this.rawWebnat.onConnectionOpen(connection);
    this.broadcastWebnat.onConnectionOpen(connection);
    this.methodWebnat.onConnectionOpen(connection);
  }

  /**
   * 连接关闭时的回调
   *
   * 当连接关闭时，通知所有注册的消息传递器清理该连接相关的资源
   *
   * @param connection 已关闭的连接
   */
  private onConnectionClose(connection: Connection): void {
    this.connections.delete(connection.id);
    this.rawWebnat.onConnectionClose(connection);
    this.broadcastWebnat.onConnectionClose(connection);
    this.methodWebnat.onConnectionClose(connection);
  }

  /**
   * 接收消息时的回调
   *
   * 当从 Web 端接收消息时，分发消息到所有注册的消息传递器。
   *
   * @param connection 消息来源连接
   * @param message 接收的消息
   */
  private onConnectionReceive(connection: Connection, message: Message): void {
    this.rawWebnat.receive(message, connection);
    this.broadcastWebnat.receive(message, connection);
    this.methodWebnat.receive(message, connection);
  }

  /**
   * 接收来自 Web 端的消息
   *
   * 此方法由 Web 端通过 JavaScript 代理调用（通过 __native_webnat__.postMessage），
   * 处理来自 Web 端的消息。
   *
   * 消息格式：JSON 字符串，解析后应为 Message 对象
   *
   * 消息类型：
   * - open: 连接打开消息，建立新连接
   * - close: 连接关闭消息，关闭连接
   * - 其他: 普通消息，转发给各个消息传递器
   *
   * @param messageText JSON 格式的消息字符串
   */
  private postMessage(messageText: string): void {
    // 推迟下次心跳时间
    this.javaScriptAliveKeeper.delay();
    try {
      // 解析 JSON 字符串
      const data: Record<string, ESObject> = JSON.parse(messageText);
      
      // 验证消息魔数
      const magic = data['magic'] as string;
      if (!magic || magic !== Message.MAGIC) {
        return;
      }
      
      // 从字典创建 Message 对象
      const message = Message.from(data);
      if (!message) {
        return;
      }
      const from = message.from;
      // 处理连接打开消息
      if (message.open) {
        // 检查是否已存在相同 ID 的连接
        if (this.connections.has(from)) {
          return;
        }
        // 提取连接元数据
        const attributes: Record<string, ESObject> = message.open.param;
        // 当前连接的界面 URL（连接建立时页面地址）
        const url = this.getWebController()?.getUrl();
        // 创建新的 Connection 实例
        const connection = new ConnectionImpl(from, attributes, url, async (messageToSend: Message): Promise<void> => {
          const controller = this.getWebController();
          if (!controller) {
            // Controller 已被回收，无法发送消息
            return;
          }
          try {
            const string = JSON.stringify([messageToSend]);
            // 转义特殊字符，确保可以安全地嵌入到 JavaScript 单引号字符串中
            // const escapedString = string.replace(/\\/g, '\\\\')
            //   .replace(/'/g, "\\'")
            //   .replace(/\n/g, '\\n')
            //   .replace(/\r/g, '\\r')
            //   .replace(/\u2028/g, '\\u2028')
            //   .replace(/\u2029/g, '\\u2029');
            //
            // 重置保活
            this.javaScriptAliveKeeper.delay();
            // 构造 JavaScript 代码调用 Web 端的 receive 方法
            const js = `window.__web_webnat__.receive(...${string})`;
            await controller.runJavaScript(js);
          } catch (error) {
            // 忽略发送错误
          }
        });
        // 保存连接并通知所有代理
        this.onConnectionOpen(connection);
        return;
      }
      if (message.close) {
        // 处理连接关闭消息
        const connection = this.connections.get(from);
        if (!connection) {
          return;
        }
        // 标记连接为已关闭并通知所有代理
        (connection as ConnectionImpl).dispose();
        this.onConnectionClose(connection);
        return;
      }
      // 处理其他消息类型（raw, broadcast, invoke, reply, notify, abort）
      const targetConnection = this.connections.get(from);
      if (!targetConnection) {
        return;
      }
      this.onConnectionReceive(targetConnection, message);
    } catch (error) {
      // 解析失败，忽略消息
    }
  }
}


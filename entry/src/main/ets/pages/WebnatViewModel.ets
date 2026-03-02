import { Webnat } from 'webnat';
import type { Connection } from 'webnat';
import { AbortSignal } from 'webnat';
import { webview } from '@kit.ArkWeb';
import { LogEntry, LogType, LogCategory } from './LogEntry';

/**
 * WebnatViewModel - 视图模型
 * 
 * 管理 Webnat 的初始化和消息处理逻辑
 */
@ObservedV2
export class WebnatViewModel {
  @Trace logs: LogEntry[] = [];
  @Trace connectionCount: number = 0;
  
  private webController?: webview.WebviewController;
  private webnat?: Webnat;
  private connectionCountTimer?: number;

  // UTF-8 边界字符测试数据
  private utf8BoundaryChars: Record<string, ESObject> = {
    "ascii": "Hello World! 123",
    "latin1": "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ",
    "cjk": "你好世界！中文测试",
    "emoji": "😀😁😂🤣😃😄😅",
    "mixed": "Hello 你好 😀 世界 World! 测试 Test 123",
    "boundaries": "\u0000\u007F\u0080\u07FF\u0800\uFFFF",
    "special": "\n\r\t\\/\"'`{}[]()<>",
    "empty": "",
    "long": "A".repeat(1000) + "你".repeat(100) + "😀".repeat(50),
    "array": ["Hello World! 123", "你好世界！中文测试", "😀😁😂🤣😃😄😅"],
    "nested": {
      "level1": {
        "level2": {
          "level3": "Hello 你好 😀 世界 World! 测试 Test 123"
        }  as Record<string, ESObject>
      }  as Record<string, ESObject>
    } as Record<string, ESObject>
  };

  /**
   * 设置 WebView Controller 并初始化 Webnat
   */
  setup(controller: webview.WebviewController): void {
    this.webController = controller;
    this.webnat = Webnat.of(controller);

    // 注册消息监听器
    this.registerListeners();
    
    // 注册方法处理函数
    this.registerMethodHandlers();
    
    // 定期检查连接数
    this.startConnectionCountTimer();
  }

  /**
   * 启动连接数定时器
   */
  private startConnectionCountTimer(): void {
    if (this.connectionCountTimer) {
      clearInterval(this.connectionCountTimer);
    }
    
    this.connectionCountTimer = setInterval(() => {
      this.updateConnectionCount();
    }, 500);
  }

  /**
   * 更新连接数
   */
  private updateConnectionCount(): void {
    if (this.webnat) {
      // 使用 @Trace 装饰器后，直接赋值即可触发 UI 更新
      this.connectionCount = this.webnat.getConnections().size;
    }
  }

  /**
   * 注册消息监听器
   */
  private registerListeners(): void {
    if (!this.webnat) {
      return;
    }

    // 注册 raw 消息监听
    this.webnat.onRaw((raw: ESObject, connection: Connection) => {
      const message = this.formatMessage(raw);
      this.addLog(LogType.RECEIVED, LogCategory.RAW, `收到 Raw 消息: ${message}`);
    });

    // 注册 broadcast 消息监听
    this.webnat.onBroadcast("test-broadcast", (param: ESObject, connection: Connection) => {
      const message = this.formatMessage(param);
      this.addLog(LogType.RECEIVED, LogCategory.BROADCAST, `收到 Broadcast 消息: ${message}`);
    });
  }

  /**
   * 注册方法处理函数
   */
  private registerMethodHandlers(): void {
    if (!this.webnat) {
      return;
    }

    // 注册 test-method 方法处理函数
    this.webnat.onMethod("test-method", async (param: ESObject, signal: AbortSignal, notify: (notification: ESObject) => void, connection: Connection): Promise<ESObject> => {
      const message = this.formatMessage(param);
      this.addLog(LogType.RECEIVED, LogCategory.METHOD, `收到 Method 调用: ${message}`);

      // 发送通知
      notify({ "progress": 50, "message": "处理中..." });

      // 模拟异步处理
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve();
        }, 3000);
      });

      const result: Record<string, ESObject> = {
        "success": true,
        "result": "Method 调用成功",
        "receivedParam": param ?? null
      };
      
      return result;
    });
  }

  /**
   * 格式化消息为字符串
   */
  private formatMessage(message: ESObject | null | undefined): string {
    if (message === null || message === undefined) {
      return "null";
    }

    try {
      return JSON.stringify(message, null, 2);
    } catch (error) {
      return String(message);
    }
  }

  /**
   * 添加日志
   */
  addLog(type: LogType, category: LogCategory, message: string): void {
    const entry = LogEntry.create(type, category, message);
    // 使用 @Trace 装饰器后，直接 push 即可触发 UI 更新
    this.logs.push(entry);

    // 限制日志数量，避免内存问题
    if (this.logs.length > 1000) {
      this.logs.splice(0, 100);
    }
  }

  /**
   * 发送 Raw 消息
   */
  sendRaw(): void {
    if (!this.webnat) {
      this.addLog(LogType.ERROR, LogCategory.RAW, "Webnat 未初始化");
      return;
    }

    const connections = Array.from(this.webnat.getConnections().values());
    if (connections.length === 0) {
      this.addLog(LogType.ERROR, LogCategory.RAW, "没有可用的连接");
      return;
    }

    const param: ESObject = this.utf8BoundaryChars;
    const message = this.formatMessage(param);
    this.addLog(LogType.SENT, LogCategory.RAW, `发送 Raw 消息: ${message}`);

    this.webnat.raw(param, connections[0]);
  }

  /**
   * 发送 Broadcast 消息
   */
  sendBroadcast(): void {
    if (!this.webnat) {
      this.addLog(LogType.ERROR, LogCategory.BROADCAST, "Webnat 未初始化");
      return;
    }

    const connections = Array.from(this.webnat.getConnections().values());
    if (connections.length === 0) {
      this.addLog(LogType.ERROR, LogCategory.BROADCAST, "没有可用的连接");
      return;
    }

    const param: ESObject = this.utf8BoundaryChars;
    const message = this.formatMessage(param);
    this.addLog(LogType.SENT, LogCategory.BROADCAST, `发送 Broadcast 消息: ${message}`);

    this.webnat.broadcast("test-broadcast", param, connections[0]);
  }

  /**
   * 发送 Method 调用
   */
  async sendMethod(): Promise<void> {
    if (!this.webnat) {
      this.addLog(LogType.ERROR, LogCategory.METHOD, "Webnat 未初始化");
      return;
    }

    const connections = Array.from(this.webnat.getConnections().values());
    if (connections.length === 0) {
      this.addLog(LogType.ERROR, LogCategory.METHOD, "没有可用的连接");
      return;
    }

    const param: ESObject = this.utf8BoundaryChars;
    const message = this.formatMessage(param);
    this.addLog(LogType.SENT, LogCategory.METHOD, `发送 Method 调用: ${message}`);

    try {
      const result: ESObject = await this.webnat.method(
        { method: "test-method", param: param },
        {
          timeout: 5000,
          onNotification: (notification: ESObject) => {
            const notifyMessage = this.formatMessage(notification);
            this.addLog(LogType.RECEIVED, LogCategory.METHOD, `收到 Method 通知: ${notifyMessage}`);
          }
        },
        connections[0]
      );
      const resultMessage = this.formatMessage(result);
      this.addLog(LogType.RECEIVED, LogCategory.METHOD, `Method 调用成功: ${resultMessage}`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      this.addLog(LogType.ERROR, LogCategory.METHOD, `Method 调用失败: ${errorMessage}`);
    }
  }

  /**
   * 清空日志
   */
  clearLogs(): void {
    // 使用 @Trace 装饰器后，直接赋值即可触发 UI 更新
    this.logs = [];
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    if (this.connectionCountTimer) {
      clearInterval(this.connectionCountTimer);
      this.connectionCountTimer = undefined;
    }
  }
}


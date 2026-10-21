/**
 * Webnat 错误码定义
 * 
 * 定义 Webnat 内置错误码。
 * 负数表示系统级、通用错误码，保证与业务自定义 code 不冲突。
 */
export const enum WebnatErrorCode {
  /** 未知错误
   * 
   * 无法识别或分类的错误
   */
  UNKNOWN = -1,
  
  /** 请求已取消
   * 
   * 当用户主动取消某个操作（如 RPC 方法调用）时触发
   */
  CANCELLED = -999,
  
  /** 请求超时
   * 
   * 当操作或调用超时（如 RPC 方法调用超过指定超时时间）时触发
   */
  TIMEOUT = -1001,
  
  /** 连接已关闭
   * 
   * 当尝试向已关闭的连接发送消息时触发
   */
  CLOSED = -1004,
  
  /** 方法未实现
   * 
   * 当调用的方法在对端（Web/Native）未注册处理器时触发
   */
  UNIMPLEMENTED = -1010,
  
  /** 消息反序列化失败
   * 
   * 当接收到的消息无法解析为可用对象时触发
   */
  DESERIALIZATION_FAILED = -1011,
  
  /** 消息序列化失败
   * 
   * 当消息对象无法转换为 JSON 格式时触发
   */
  SERIALIZATION_FAILED = -1012,
}

/**
 * Webnat 标准错误类
 * 
 * 表示 Webnat 协议内的标准错误对象，包含错误码和错误消息。
 * 继承自 Error 类，以便可以在 throw 语句中使用。
 *
 * @example
 * ```typescript
 * try {
 *   // 某些操作
 *   throw new WebnatError(WebnatErrorCode.TIMEOUT, 'Operation timeout')
 * } catch (error) {
 *   if (error instanceof WebnatError) {
 *     console.error(`Error ${error.code}: ${error.message}`)
 *   }
 * }
 * ```
 */
export class WebnatError extends Error {
  /** 错误代码 */
  public readonly code: number;

  /**
   * 构造函数
   *
   * 使用统一的错误码和消息创建错误对象
   *
   * @param code 错误代码
   * @param message 错误消息
   */
  constructor(code: number, message: string) {
    super(message);
    this.code = code;
    this.name = 'WebnatError';
  }

  /**
   * 从任意对象反序列化为 WebnatError
   *
   * 此方法用于将从 JavaScript 端接收到的错误对象转换为 WebnatError
   *
   * 支持的输入格式：
   * 1. 对象格式：{ "code": number, "message": string } 或其它系统常见字段命名（区分大小写，不同风格均支持）
   * 2. 其他类型：将对象描述作为错误消息
   * 
   * @param error 任意异常对象
   * @returns WebnatError 实例，如果 error 为 null 或 undefined 则返回 null
   */
  static from(error: ESObject): WebnatError | null {
    if (error === null || error === undefined) return null;
    if (error instanceof WebnatError) return error;
    if (typeof error === 'object' && !Array.isArray(error)) {
      const first = (keys: string[]): ESObject => {
        for (const key of keys) if (Object.keys(error).indexOf(key) !== -1 || (key === 'message' && error instanceof Error)) return error[key];
        return undefined;
      };
      const rawCode: ESObject = first(['code', 'errcode', 'errCode', 'errorcode', 'errorCode']);
      let code: number = WebnatErrorCode.UNKNOWN;
      const number: number = typeof rawCode === 'number' ? rawCode as number :
        typeof rawCode === 'string' && (rawCode as string).trim() === rawCode && /^[+-]?[0-9]+$/.test(rawCode as string) ? Number(rawCode) : NaN;
      if (Number.isInteger(number) && number >= -2147483648 && number <= 2147483647) code = number;
      const rawMessage: ESObject = first(['message', 'msg', 'errmsg', 'errMsg', 'errormsg', 'errorMsg', 'errormessage', 'errorMessage']);
      const message: string = typeof rawMessage === 'string' ? rawMessage as string :
        typeof rawMessage === 'boolean' || (typeof rawMessage === 'number' && Number.isFinite(rawMessage as number))
          ? String(rawMessage) : 'Unknown Error';
      return new WebnatError(code, message);
    }
    return new WebnatError(WebnatErrorCode.UNKNOWN, String(error));
  }

  /**
   * 构造超时错误
   * 
   * @returns WebnatError 实例
   */
  static timeout(): WebnatError {
    return new WebnatError(WebnatErrorCode.TIMEOUT, 'Operation Timeout');
  }

  /**
   * 构造操作取消错误
   * 
   * @returns WebnatError 实例
   */
  static cancelled(): WebnatError {
    return new WebnatError(WebnatErrorCode.CANCELLED, 'Operation Cancelled');
  }

  /**
   * 构造连接关闭错误
   * 
   * @returns WebnatError 实例
   */
  static closed(): WebnatError {
    return new WebnatError(WebnatErrorCode.CLOSED, 'Connection Closed');
  }

  /**
   * 构造未实现错误
   * 
   * @param obj 可选，未实现的方法描述
   * @returns WebnatError 实例
   */
  static unimplemented(obj?: ESObject): WebnatError {
    const message = obj ? `Unimplemented Method: ${obj}` : 'Unimplemented Method';
    return new WebnatError(WebnatErrorCode.UNIMPLEMENTED, message);
  }

  /**
   * 构造反序列化失败错误
   * 
   * @param obj 可选，额外描述
   * @returns WebnatError 实例
   */
  static deserializationFailed(obj?: ESObject): WebnatError {
    const message = obj ? `Message Deserialization Failed: ${obj}` : 'Message Deserialization Failed';
    return new WebnatError(WebnatErrorCode.DESERIALIZATION_FAILED, message);
  }

  /**
   * 构造序列化失败错误
   * 
   * @param obj 可选，额外描述
   * @returns WebnatError 实例
   */
  static serializationFailed(obj?: ESObject): WebnatError {
    const message = obj ? `Message Serialization Failed: ${obj}` : 'Message Serialization Failed';
    return new WebnatError(WebnatErrorCode.SERIALIZATION_FAILED, message);
  }

  /**
   * 转为 JSON 格式（便于返回 JS 或日志）
   *
   * 将 WebnatError 转换为对象格式，包含 `code` 和 `message` 字段。
   *
   * @returns 包含错误码和错误消息的对象
   *
   * @example
   * ```typescript
   * const error = WebnatError.timeout()
   * const json = error.toJson()
   * // { code: -1001, message: 'Operation Timeout' }
   * ```
   */
  toJson(): Record<string, ESObject> {
    return {
      "code": this.code,
      "message": this.message,
    };
  }
}

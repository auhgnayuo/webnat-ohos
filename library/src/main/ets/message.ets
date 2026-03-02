/**
 * 连接打开消息类
 * 
 * 用于建立连接时的初始化消息，可以携带初始化参数。
 */
export class Open {
  /** 可选的初始化参数，可以是任意可序列化的对象 */
  public readonly param?: ESObject

  /**
   * 构造函数
   * 
   * @param param 可选的初始化参数
   */
  constructor(param?: ESObject) {
    this.param = param;
  }
}

/**
 * 连接关闭消息类
 * 
 * 用于关闭连接时的消息，可以携带关闭原因等参数。
 */
export class Close {
  /** 可选的关闭参数（如关闭原因等），可以是任意可序列化的对象 */
  public readonly param?: ESObject

  /**
   * 构造函数
   * 
   * @param param 可选的关闭参数（如关闭原因等）
   */
  constructor(param?: ESObject) {
    this.param = param;
  }
}

/**
 * 原始消息类
 * 
 * 用于发送任意原始数据，不经过任何特殊处理。
 */
export class Raw {
  /** 原始消息的参数数据，可以是任意可序列化的对象 */
  public readonly param?: ESObject

  /**
   * 构造函数
   * 
   * @param param 原始消息的参数数据
   */
  constructor(param?: ESObject) {
    this.param = param;
  }
}

/**
 * 广播消息类
 * 
 * 用于向所有订阅者发送事件通知，支持事件名称和参数。
 */
export class Broadcast {
  /** 广播事件名称，用于标识不同的事件类型 */
  public readonly name: string
  /** 广播事件的参数数据，可以是任意可序列化的对象，可选 */
  public readonly param?: ESObject

  /**
   * 构造函数
   * 
   * @param name 广播事件名称
   * @param param 广播事件的参数数据
   */
  constructor(name: string, param?: ESObject) {
    this.name = name;
    this.param = param;
  }
}

/**
 * 方法调用消息类
 * 
 * 用于远程方法调用（RPC），包含调用 ID、方法名和参数。
 */
export class Invoke {
  /** 调用 ID，用于匹配请求和响应，唯一标识一次方法调用 */
  public readonly id: string
  /** 要调用的方法名称 */
  public readonly method: string
  /** 方法调用的参数，可以是任意可序列化的对象，可选 */
  public readonly param?: ESObject

  /**
   * 构造函数
   * 
   * @param id 调用 ID，用于匹配请求和响应
   * @param method 要调用的方法名称
   * @param param 方法调用的参数
   */
  constructor(id: string, method: string, param?: ESObject) {
    this.id = id;
    this.method = method;
    this.param = param;
  }
}

/**
 * 方法调用响应消息类
 * 
 * 用于返回方法调用的结果或错误，包含调用 ID、结果或错误信息。
 */
export class Reply {
  /** 调用 ID，用于匹配对应的请求 */
  public readonly id: string
  /** 方法调用的成功结果，可以是任意可序列化的对象（与 `error` 互斥） */
  public readonly result?: ESObject
  /** 方法调用的错误信息，可以是任意可序列化的对象（与 `result` 互斥） */
  public readonly error?: ESObject

  /**
   * 构造函数
   * 
   * @param id 调用 ID，用于匹配对应的请求
   * @param result 方法调用的成功结果（与 error 互斥）
   * @param error 方法调用的错误信息（与 result 互斥）
   */
  constructor(id: string, result?: ESObject, error?: ESObject) {
    this.id = id;
    this.result = result;
    this.error = error;
  }
}

/**
 * 通知消息类
 * 
 * 用于在方法调用执行过程中向调用方发送进度通知或中间结果。
 */
export class Notify {
  /** 调用 ID，用于匹配对应的请求 */
  public readonly id: string
  /** 通知的参数数据，可以是任意可序列化的对象（如进度信息、中间结果等），可选 */
  public readonly param?: ESObject

  /**
   * 构造函数
   * 
   * @param id 调用 ID，用于匹配对应的请求
   * @param param 通知的参数数据
   */
  constructor(id: string, param?: ESObject) {
    this.id = id;
    this.param = param;
  }
}

/**
 * 中止消息类
 * 
 * 用于取消正在执行的方法调用。
 */
export class Abort {
  /** 调用 ID，用于匹配要取消的请求 */
  public readonly id: string

  /**
   * 构造函数
   * 
   * @param id 调用 ID，用于匹配要取消的请求
   */
  constructor(id: string) {
    this.id = id;
  }
}

/**
 * 消息类
 * 
 * 所有消息的统一格式，包含发送方、接收方和具体的消息类型。
 * 消息类型是互斥的，一条消息只能包含一种类型的消息体。
 *
 * 支持的消息类型：
 * - `open`: 连接打开消息
 * - `close`: 连接关闭消息
 * - `raw`: 原始消息
 * - `broadcast`: 广播消息
 * - `invoke`: 方法调用消息
 * - `reply`: 方法调用响应消息
 * - `notify`: 通知消息
 * - `abort`: 中止消息
 */
export class Message {
  /**
   * Native 端的 UUID 标识符常量
   *
   * 用于标识消息来自 Native 端，值为 `"00000000-0000-0000-0000-000000000000"`。
   */
  static readonly NATIVE_UUID = '00000000-0000-0000-0000-000000000000'
  
  /**
   * 消息魔数常量
   *
   * 用于验证消息格式，值为 `"WEBNAT"`。
   */
  static readonly MAGIC = 'WEBNAT'
  
  /** 消息魔数，用于验证消息格式 */
  public readonly magic: string = Message.MAGIC
  
  /** 消息发送方的标识（连接 ID 或 `NATIVE_UUID`） */
  public readonly from: string
  
  /** 消息接收方的标识（连接 ID 或 `NATIVE_UUID`） */
  public readonly to: string
  
  /** 连接打开消息（与其他消息类型互斥） */
  public readonly open?: Open
  
  /** 连接关闭消息（与其他消息类型互斥） */
  public readonly close?: Close
  
  /** 原始消息（与其他消息类型互斥） */
  public readonly raw?: Raw
  
  /** 广播消息（与其他消息类型互斥） */
  public readonly broadcast?: Broadcast
  
  /** 方法调用消息（与其他消息类型互斥） */
  public readonly invoke?: Invoke
  
  /** 方法调用响应消息（与其他消息类型互斥） */
  public readonly reply?: Reply
  
  /** 通知消息（与其他消息类型互斥） */
  public readonly notify?: Notify
  
  /** 中止消息（与其他消息类型互斥） */
  public readonly abort?: Abort
  
  /**
   * 初始化消息
   * 
   * @param from 消息发送方的标识
   * @param to 消息接收方的标识
   * @param open 连接打开消息（与其他消息类型互斥）
   * @param close 连接关闭消息（与其他消息类型互斥）
   * @param raw 原始消息（与其他消息类型互斥）
   * @param broadcast 广播消息（与其他消息类型互斥）
   * @param invoke 方法调用消息（与其他消息类型互斥）
   * @param reply 方法调用响应消息（与其他消息类型互斥）
   * @param notify 通知消息（与其他消息类型互斥）
   * @param abort 中止消息（与其他消息类型互斥）
   */
  constructor(
    from: string,
    to: string,
    open?: Open,
    close?: Close,
    raw?: Raw,
    broadcast?: Broadcast,
    invoke?: Invoke,
    reply?: Reply,
    notify?: Notify,
    abort?: Abort
  ) {
    this.from = from;
    this.to = to;
    this.open = open;
    this.close = close;
    this.raw = raw;
    this.broadcast = broadcast;
    this.invoke = invoke;
    this.reply = reply;
    this.notify = notify;
    this.abort = abort;
    // magic 字段在类属性中已初始化为 Message.MAGIC
  }

  // ==================== 连接管理 ====================

  /**
   * 创建连接打开消息
   * 
   * @param from 发送方标识
   * @param param 可选的初始化参数
   * @returns Message 实例
   */
  static open(from: string, param?: ESObject): Message {
    return new Message(from, Message.NATIVE_UUID, new Open(param));
  }

  /**
   * 创建连接关闭消息
   * 
   * @param from 发送方标识
   * @param param 可选的关闭参数
   * @returns Message 实例
   */
  static close(from: string, param?: ESObject): Message {
    return new Message(from, Message.NATIVE_UUID, undefined, new Close(param));
  }

  /**
   * 创建 Native 发送的原始消息
   * 
   * @param to 接收方标识（连接 ID）
   * @param param 原始消息的参数数据
   * @returns Message 实例
   */
  static raw(to: string, param?: ESObject): Message {
    return new Message(Message.NATIVE_UUID, to, undefined, undefined, new Raw(param));
  }

  /**
   * 创建 Native 发送的广播消息
   * 
   * @param to 接收方标识（连接 ID）
   * @param name 广播事件名称
   * @param param 广播事件的参数数据
   * @returns Message 实例
   */
  static broadcast(to: string, name: string, param?: ESObject): Message {
    return new Message(Message.NATIVE_UUID, to, undefined, undefined, undefined, new Broadcast(name, param));
  }

  /**
   * 创建 Native 发送的方法调用消息
   * 
   * @param to 接收方标识（连接 ID）
   * @param id 调用 ID
   * @param method 方法名称
   * @param param 方法参数
   * @returns Message 实例
   */
  static invoke(to: string, id: string, method: string, param?: ESObject): Message {
    return new Message(Message.NATIVE_UUID, to, undefined, undefined, undefined, undefined, new Invoke(id, method, param));
  }

  /**
   * 创建 Native 发送的方法调用响应消息
   * 
   * @param to 接收方标识（连接 ID）
   * @param id 调用 ID
   * @param result 成功结果（与 error 互斥）
   * @param error 错误信息（与 result 互斥）
   * @returns Message 实例
   */
  static reply(to: string, id: string, result?: ESObject, error?: ESObject): Message {
    return new Message(Message.NATIVE_UUID, to, undefined, undefined, undefined, undefined, undefined, new Reply(id, result, error));
  }

  /**
   * 创建 Native 发送的通知消息
   * 
   * @param to 接收方标识（连接 ID）
   * @param id 调用 ID
   * @param param 通知的参数数据
   * @returns Message 实例
   */
  static notify(to: string, id: string, param?: ESObject): Message {
    return new Message(Message.NATIVE_UUID, to, undefined, undefined, undefined, undefined, undefined, undefined, new Notify(id, param));
  }

  /**
   * 创建 Native 发送的中止消息
   * 
   * @param to 接收方标识（连接 ID）
   * @param id 调用 ID
   * @returns Message 实例
   */
  static abort(to: string, id: string): Message {
    return new Message(Message.NATIVE_UUID, to, undefined, undefined, undefined, undefined, undefined, undefined, undefined, new Abort(id));
  }

  // ==================== 序列化 ====================

  /**
   * 将消息转换为字典格式（用于发送）
   *
   * 将 `Message` 对象转换为字典格式，便于序列化为 JSON 并发送到 Web 端。
   *
   * @returns 字典格式的消息，可以直接用于 JSON 序列化
   */
  toDictionary(): Record<string, ESObject> {
    const dict: Record<string, ESObject> = {
      "magic": this.magic,
      "from": this.from,
      "to": this.to
    };
    
    if (this.open) {
      const openDict: Record<string, ESObject> = {};
      if (this.open.param !== undefined) {
        openDict["param"] = this.open.param as ESObject;
      }
      dict["open"] = openDict;
    }
    
    if (this.close) {
      const closeDict: Record<string, ESObject> = {};
      if (this.close.param !== undefined) {
        closeDict["param"] = this.close.param as ESObject;
      }
      dict["close"] = closeDict;
    }
    
    if (this.raw) {
      const rawDict: Record<string, ESObject> = {};
      if (this.raw.param !== undefined) {
        rawDict["param"] = this.raw.param as ESObject;
      }
      dict["raw"] = rawDict;
    }
    
    if (this.broadcast) {
      const broadcastDict: Record<string, ESObject> = {
        "name": this.broadcast.name
      };
      if (this.broadcast.param !== undefined) {
        broadcastDict["param"] = this.broadcast.param as ESObject;
      }
      dict["broadcast"] = broadcastDict;
    }
    
    if (this.invoke) {
      const invokeDict: Record<string, ESObject> = {
        "id": this.invoke.id,
        "method": this.invoke.method
      };
      if (this.invoke.param !== undefined) {
        invokeDict["param"] = this.invoke.param as ESObject;
      }
      dict["invoke"] = invokeDict;
    }
    
    if (this.reply) {
      const replyDict: Record<string, ESObject> = {
        "id": this.reply.id
      };
      if (this.reply.result !== undefined) {
        replyDict["result"] = this.reply.result as ESObject;
      }
      if (this.reply.error !== undefined) {
        replyDict["error"] = this.reply.error as ESObject;
      }
      dict["reply"] = replyDict;
    }
    
    if (this.notify) {
      const notifyDict: Record<string, ESObject> = {
        "id": this.notify.id
      };
      if (this.notify.param !== undefined) {
        notifyDict["param"] = this.notify.param as ESObject;
      }
      dict["notify"] = notifyDict;
    }
    
    if (this.abort) {
      dict["abort"] = {
        "id": this.abort.id
      };
    }
    
    return dict;
  }
  
  /**
   * 从字典创建消息实例
   *
   * 从字典格式（通常来自 JSON 反序列化）创建 `Message` 对象。
   * 如果字典格式无效（缺少必需字段、魔数不匹配等），则返回 `undefined`。
   *
   * @param dict 字典格式的消息，通常来自 JSON 反序列化
   * @returns `Message` 实例，如果字典格式无效则返回 `undefined`
   */
  static from(dict: Record<string, ESObject>): Message | undefined {
    const magic = dict["magic"] as string;
    if (!magic || magic !== Message.MAGIC) {
      return undefined;
    }
    
    const from = dict["from"] as string;
    const to = dict["to"] as string;
    if (!from || !to) {
      return undefined;
    }
    
    let open: Open | undefined;
    if (dict["open"]) {
      const openDict = dict["open"] as Record<string, ESObject>;
      open = new Open(openDict["param"] as ESObject);
    }
    
    let close: Close | undefined;
    if (dict["close"]) {
      const closeDict = dict["close"] as Record<string, ESObject>;
      close = new Close(closeDict["param"] as ESObject);
    }
    
    let raw: Raw | undefined;
    if (dict["raw"]) {
      const rawDict = dict["raw"] as Record<string, ESObject>;
      raw = new Raw(rawDict["param"] as ESObject);
    }
    
    let broadcast: Broadcast | undefined;
    if (dict["broadcast"]) {
      const broadcastDict = dict["broadcast"] as Record<string, ESObject>;
      const name = broadcastDict["name"] as string;
      if (name) {
        broadcast = new Broadcast(name, broadcastDict["param"] as ESObject);
      }
    }
    
    let invoke: Invoke | undefined;
    if (dict["invoke"]) {
      const invokeDict = dict["invoke"] as Record<string, ESObject>;
      const id = invokeDict["id"] as string;
      const method = invokeDict["method"] as string;
      if (id && method) {
        invoke = new Invoke(id, method, invokeDict["param"] as ESObject);
      }
    }
    
    let reply: Reply | undefined;
    if (dict["reply"]) {
      const replyDict = dict["reply"] as Record<string, ESObject>;
      const id = replyDict["id"] as string;
      if (id) {
        reply = new Reply(id, replyDict["result"] as ESObject, replyDict["error"] as ESObject);
      }
    }
    
    let notify: Notify | undefined;
    if (dict["notify"]) {
      const notifyDict = dict["notify"] as Record<string, ESObject>;
      const id = notifyDict["id"] as string;
      if (id) {
        notify = new Notify(id, notifyDict["param"] as ESObject);
      }
    }
    
    let abort: Abort | undefined;
    if (dict["abort"]) {
      const abortDict = dict["abort"] as Record<string, ESObject>;
      const id = abortDict["id"] as string;
      if (id) {
        abort = new Abort(id);
      }
    }
    
    return new Message(
      from,
      to,
      open,
      close,
      raw,
      broadcast,
      invoke,
      reply,
      notify,
      abort
    );
  }
}


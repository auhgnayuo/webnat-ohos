/**
 * LogEntry - 日志条目数据结构
 * 
 * 用于记录 Webnat 通信过程中的消息日志
 */
export class LogEntry {
  id: string;
  time: string;
  type: LogType;
  category: LogCategory;
  message: string;

  constructor(id: string, time: string, type: LogType, category: LogCategory, message: string) {
    this.id = id;
    this.time = time;
    this.type = type;
    this.category = category;
    this.message = message;
  }

  static create(type: LogType, category: LogCategory, message: string): LogEntry {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    const milliseconds = String(now.getMilliseconds()).padStart(3, '0');
    const time = `${hours}:${minutes}:${seconds}.${milliseconds}`;
    
    const id = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    return new LogEntry(id, time, type, category, message);
  }
}

export enum LogType {
  SENT = '发送',
  RECEIVED = '接收',
  ERROR = '错误'
}

export enum LogCategory {
  RAW = 'Raw',
  BROADCAST = 'Broadcast',
  METHOD = 'Method',
  SYSTEM = '系统'
}


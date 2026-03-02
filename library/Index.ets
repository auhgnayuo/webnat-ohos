/**
 * Webnat 模块入口
 *
 * 统一导出 Webnat 实例和类型定义
 *
 * 导出内容：
 * - Webnat: Webnat 主类
 * - Connection: 连接接口
 * - WebnatError: 错误类
 * - WebnatErrorCode: 错误码枚举
 * - AbortController, AbortSignal: 取消控制器相关
 * - Message, Param: 消息相关类型
 */
export { Webnat } from './src/main/ets/webnat'
export { WebnatVersion } from './src/main/ets/version'
export type { Connection } from './src/main/ets/connection'
export { WebnatError, WebnatErrorCode } from './src/main/ets/error'
export { AbortController, AbortSignal } from './src/main/ets/abortController'
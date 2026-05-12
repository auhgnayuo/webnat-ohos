# Changelog

All notable changes to this project will be documented in this file.

## [1.0.5] (2026-05-12)

### Fixed

- Native→Web 注入：`runJavaScript` 侧改为 `JSON.stringify([message.toDictionary()])`，与 Android `toJson()` 语义一致，避免对 `Message` 类实例直接 `JSON.stringify` 时因引擎差异产生非协议字段。

### Note

- `JavaScriptAliveKeeper` 仍会周期性调用 `raw(null, connection)` 保活；Web 端可能间歇收到 `raw` 且 `param` 为 `null`，属预期行为。

---

## [1.0.4] (2026-05-12)

### Fixed

- 满足 ArkTS 严格规则：`Message.from` 在 `open` 无 `param` 时不再把缺失字段强转为 `ESObject`；`Webnat` 从 `open.param` 构造连接 `attributes` 时避免隐式 `any`。
- `MethodWebnat`：出站 `send` 与入站 listener 的拒绝路径通过 `Promise.catch((err: ESObject) => …)` 与 `WebnatError.from` 保留错误信息（`try/catch` 在部分工具链下无法为绑定变量标注类型）；`invoke` 处理仍 `await` 整条 Promise 链以保持顺序。

### Added

- 扩充 Hypium 单测：`MethodWebnat`、`BroadcastWebnat`，以及 `Message.from` 对空 `open` 对象的用例。

---

## [1.0.3] (2026-03-12)

### Features

- 去掉发送method请求的await

---

## [1.0.2] (2026-03-06)

### Features

- Connection 增加 `url` 属性：在连接建立时记录当前页面的 URL，便于 Native 端识别来源页面

---

## [1.0.0] (2026-02-27)

### Features

- 支持 Native (HarmonyOS) 与 Web 双向通信
- 支持三种通信模式：原始消息 (Raw)、广播消息 (Broadcast)、方法调用 (Method/RPC)
- 支持 iframe 消息自动转发
- 内置超时控制和主动取消机制 (AbortController)
- 基于 HarmonyOS Web 组件，支持 API 12+

# Changelog

All notable changes to this project will be documented in this file.

## [1.4.0] (2026-10-13)

### Features

- **`onRenderExited()`**：宿主在渲染进程退出时通知 Webnat，Webnat 据此自行结束该页面的所有连接。页面崩溃或被销毁时无法再发送 CLOSE，调用后连接标记为已关闭并从 `getConnections()` 移除，这些连接上待完成的 `method` 调用以 `CLOSED` 失败，正在执行的 method handler 收到取消；不会向页面发送消息，Webnat 实例仍可继续使用，页面重新加载后会照常建立新连接。Android / Darwin / OHOS / Electron 同语义。方法名取各平台自己的回调名：Darwin 为 `webViewWebContentProcessDidTerminate`，Android 和 Electron 为 `onRenderProcessGone`，OHOS 为 `onRenderExited`。调用点：Web 组件自己的 `onRenderExited`，以及丢弃 `WebviewController` 之前（如 `aboutToDisappear`）。

### Fixed

- **同步抛出的 handler 异常现在会回复错误**：`onMethod` 的处理函数在返回 Promise 之前同步抛出时，之前不会产生回复，调用方只能等到超时；现在与 Promise reject 一样回复 `{ code, message }`（没有 code 的错误为 -1）。
- **发送失败不再被吞掉**：参数无法序列化时 `method` 立即以 `SERIALIZATION_FAILED(-1012)` 失败，`WebviewController` 已被回收时以 `CLOSED` 失败，`runJavaScript` 报告的错误会让调用以该错误失败。`raw` / `broadcast` 等仍是 `trySend`，保持静默。
- **无法序列化的方法结果不再被丢弃**：handler 返回的结果无法序列化时，回复 `SERIALIZATION_FAILED` 错误，而不是让调用方等到超时。

---

## [1.3.0] (2026-10-12)

### Features

- **`AbortController` / `AbortSignal` 与 Node.js / Web 标准对齐**：`AbortSignal` 新增 `reason`、`onabort`、`throwIfAborted()`、`addEventListener('abort', listener)` / `removeEventListener`，监听器会收到 `AbortEvent`（`type` / `target`）；`AbortController.abort(reason?)` 支持传入取消原因，缺省为 `name` 为 `AbortError` 的 `Error`。`onMethod` 处理函数里监听取消的写法现在可以与 Web 端一致。新增导出 `AbortEvent`、`AddEventListenerOptions`。

### Deprecated

- `AbortSignal.addListener` / `removeListener` 标记为 `@deprecated`，行为保持不变（包括对已取消的信号立即回调），请迁移到 `addEventListener('abort', …)` / `removeEventListener('abort', …)`。

### Note

- 与标准一致：对**已取消**的信号调用 `addEventListener` 不会再回调，需要先判断 `signal.aborted`；库内调用点已按此处理。
- 与 Node.js 的差异：监听器抛出的异常会被忽略（Node.js 会作为未捕获异常抛出，其余监听器仍会被调用）；`once` 选项仅为签名兼容（`abort` 事件只会触发一次）；不提供 `dispatchEvent`，也暂未提供 `AbortSignal.abort()` / `timeout()` / `any()` 静态方法。

---

## [1.2.1] (2026-09-08)

### Fixed

- **方法回复的错误不再丢 `message`**：`MethodWebnat` 之前把 `WebnatError` 实例直接塞进 reply，而 ArkTS 的 `JSON.stringify` 只序列化类声明字段——`super(message)` 写入的 `message` 会被丢掉（实测 `JSON.stringify(new Error('x'))` 得到 `{}`）。对端因此只收到 `{ code }`，`WebnatError.from` 落到兜底值 `"Unknown Error"`。现改为发送前调 `error.toJson()`，与 Android / Darwin 行为一致。

---

## [1.2.0] (2026-07-02)

### Features

- **`Webnat.method` 广播**：未指定 `connection` 调用时，方法调用会**广播给当前所有连接**（主框架 + 所有 iframe），不再只发给任意首个连接。第一个发来「有意义信号」（`notify` / 成功 `reply` / 真实业务错误）的连接获胜，其余子调用立即被 `abort`，之后只透传胜者的通知与最终结果。
- **广播淘汰语义**：`unimplemented(-1010)` 与 `closed(-1004)` 不会「抢跑」获胜，只把该连接移出候选池；当所有连接都被淘汰时才最终失败——出现过 `closed` 则返回 `closed`，否则返回 `unimplemented`。超时 / 取消作用于整组并 `abort` 全部子调用（子调用本身不设超时）。主要用于「透传 iframe」这一常见场景（同一方法通常只有一个 frame 注册处理器）。

### Note

- 传入具体 `connection` 时，仍保持原有的单连接直连行为。

---

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

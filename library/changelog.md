# Changelog

All notable changes to this project will be documented in this file.

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

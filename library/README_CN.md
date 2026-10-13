# Webnat

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%2012%2B-red.svg)](https://developer.huawei.com/consumer/cn/harmonyos/)
[![ArkTS](https://img.shields.io/badge/ArkTS-5.0-blue.svg)](https://developer.huawei.com/consumer/cn/arkts/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[English](./README.md)

Webnat 是一个用于 Native (HarmonyOS) 与 Web 之间通信的 ArkTS 库。支持多种通信模式，基于 HarmonyOS 的 `Web` 组件。

## 特性

- **HarmonyOS 支持** - 支持 HarmonyOS API 12+
- **iframe 支持** - 自动处理主框架和 iframe 之间的消息转发
- **三种通信模式** - 支持双向的原始消息、广播消息和方法调用（RPC）
- **超时和取消** - 内置超时控制和主动取消机制
- **类型安全** - 完全基于 ArkTS 类型系统

## 安装

### ohpm

```bash
ohpm install webnat
```

或在 `oh-package.json5` 中添加：

```json5
{
  "dependencies": {
    "webnat": "1.4.0"
  }
}
```

## 相关项目

Webnat 需要配合 Web 端实现使用，同时也支持其他 Native 平台：

| 平台 | 仓库 |
|------|------|
| Web (JavaScript/TypeScript) | [webnat-web](https://github.com/auhgnayuo/webnat-web) |
| iOS / macOS (Swift) | [webnat-darwin](https://github.com/auhgnayuo/webnat-darwin) |
| Android (Kotlin) | [webnat-android](https://github.com/auhgnayuo/webnat-android) |

## 基本使用

### 1. 初始化

```typescript
import { Webnat } from 'webnat';
import { webview } from '@kit.ArkWeb';

const webController: webview.WebviewController = new webview.WebviewController();

// 在 Web 组件挂载后初始化 Webnat
// 只能在 onControllerAttached 回调中调用
Web({ src: url, controller: webController })
  .onControllerAttached(() => {
    const webnat = Webnat.of(webController);
  })
```

### 2. 等待 Web 端建立连接

连接是由 **Web 端（JavaScript）主动发起**的，Native 端会自动接收和管理连接。

```typescript
// Web 端（JavaScript）会发送 "open" 消息来建立连接
// Native 端自动创建 Connection 实例并存储在 webnat.getConnections() 中

// 访问所有活跃连接
const connections = webnat.getConnections();
console.log('当前有', connections.size, '个连接');

// 获取第一个连接
const connection = Array.from(connections.values())[0];
if (connection) {
  console.log('找到连接:', connection.id);
  console.log('连接属性:', connection.attributes ?? {});
}
```

### 3. 发送和接收消息

```typescript
// 发送原始消息
webnat.raw("Hello from Native!", connection);

// 监听原始消息
webnat.onRaw((raw: ESObject, connection: Connection) => {
  console.log('From', connection.id, ':', raw);
});

// 广播消息
webnat.broadcast("userLoggedIn", { userId: 123 }, connection);

// 监听广播消息
webnat.onBroadcast("userLoggedIn", (param: ESObject, connection: Connection) => {
  console.log('Broadcast from', connection.id, ':', param ?? 'nil');
});

// 调用 Web 端方法
try {
  const result = await webnat.method(
    {
      method: "getUserInfo",
      param: { userId: 123 }
    },
    { timeout: 5000 },
    connection
  );
  console.log('User info:', result ?? 'nil');
} catch (error) {
  console.error('Error:', error);
}

// 注册方法供 Web 调用
webnat.onMethod("getUserInfo", async (
  param: ESObject,
  signal: AbortSignal,
  notify: (notification: ESObject) => void,
  connection: Connection
): Promise<ESObject> => {
  const userId = param?.userId as number ?? 0;

  // 可以发送途中的通知（如进度更新）
  notify({ progress: 50 });

  // 模拟异步操作
  await new Promise<void>((resolve) => {
    setTimeout(() => resolve(), 1000);
  });

  return {
    userId: userId,
    name: "User"
  };
});
```

### 4. 发送失败与 handler 错误

- 发送失败会让等待它的调用方知道：参数无法序列化时，`method` 立即以 `SERIALIZATION_FAILED` 失败；`WebviewController` 已不存在或连接已关闭时以 `CLOSED` 失败。`runJavaScript` 报告的错误会让调用以该错误失败。`raw`、`broadcast` 仍是发出即忘。
- method handler 失败（抛出异常或 reject）时，对端会收到错误回复 `{ code, message }`（没有 code 的错误为 -1），不会因 handler 的 bug 一直等到超时。结果无法序列化时，回复 `SERIALIZATION_FAILED`。

### 5. 页面崩溃与销毁

页面正常卸载时，Web SDK 会发送 CLOSE，Webnat 随之结束该连接。渲染进程崩溃或 `WebviewController` 被销毁时页面没有机会发送，请把事件转给 Webnat：在 Web 组件自己的 `onRenderExited` 里调用 `Webnat.of(this.controller).onRenderExited()`，丢弃 `WebviewController` 之前也调用一次。Webnat 会自行结束该页面的所有连接：待完成的 `method` 调用以 `CLOSED` 失败，正在执行的 method handler 收到取消。不会向页面发送任何消息，Webnat 仍可继续使用，页面重新加载后会照常建立新连接。

```typescript
Web({ src: 'https://example.com', controller: this.controller })
  .onRenderExited(() => {
    Webnat.of(this.controller).onRenderExited();
  })

aboutToDisappear() {
  Webnat.of(this.controller).onRenderExited();
}
```

## 协议

本项目采用 MIT 协议开源。

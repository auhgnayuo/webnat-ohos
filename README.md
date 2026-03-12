# Webnat

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%2012%2B-red.svg)](https://developer.huawei.com/consumer/cn/harmonyos/)
[![ArkTS](https://img.shields.io/badge/ArkTS-5.0-blue.svg)](https://developer.huawei.com/consumer/cn/arkts/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[中文文档](./README_CN.md)

A lightweight WebView-Native bridge library for HarmonyOS. Supports multiple communication modes based on the HarmonyOS `Web` component.

## Features

- **HarmonyOS Support** - HarmonyOS API 12+
- **iframe Support** - Automatic message forwarding between main frame and iframes
- **Three Communication Modes** - Bidirectional raw messages, broadcast messages, and method calls (RPC)
- **Timeout & Cancellation** - Built-in timeout control and active cancellation mechanism
- **Type Safety** - Fully based on ArkTS type system

## Installation

### ohpm

```bash
ohpm install webnat
```

Or add to your `oh-package.json5`:

```json5
{
  "dependencies": {
    "webnat": "1.0.3"
  }
}
```

## Related Projects

Webnat requires a Web-side implementation and also supports other Native platforms:

| Platform | Repository |
|----------|------------|
| Web (JavaScript/TypeScript) | [webnat-web](https://github.com/auhgnayuo/webnat-web) |
| iOS / macOS (Swift) | [webnat-os](https://github.com/auhgnayuo/webnat-os) |
| Android (Kotlin) | [webnat-android](https://github.com/auhgnayuo/webnat-android) |

## Usage

### 1. Initialization

```typescript
import { Webnat } from 'webnat';
import { webview } from '@kit.ArkWeb';

const webController: webview.WebviewController = new webview.WebviewController();

Web({ src: url, controller: webController })
  .onControllerAttached(() => {
    const webnat = Webnat.of(webController);
  })
```

### 2. Wait for Web-side Connection

Connections are initiated by the **Web side (JavaScript)**. The Native side automatically receives and manages connections.

```typescript
const connections = webnat.getConnections();
console.log('Active connections:', connections.size);

const connection = Array.from(connections.values())[0];
if (connection) {
  console.log('Connection found:', connection.id);
  console.log('Attributes:', connection.attributes ?? {});
}
```

### 3. Send and Receive Messages

```typescript
// Send raw message
webnat.raw("Hello from Native!", connection);

// Listen for raw messages
webnat.onRaw((raw: ESObject, connection: Connection) => {
  console.log('From', connection.id, ':', raw);
});

// Broadcast
webnat.broadcast("userLoggedIn", { userId: 123 }, connection);

// Listen for broadcasts
webnat.onBroadcast("userLoggedIn", (param: ESObject, connection: Connection) => {
  console.log('Broadcast from', connection.id, ':', param ?? 'nil');
});

// Call Web-side method
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

// Register method for Web to call
webnat.onMethod("getUserInfo", async (
  param: ESObject,
  signal: AbortSignal,
  notify: (notification: ESObject) => void,
  connection: Connection
): Promise<ESObject> => {
  const userId = param?.userId as number ?? 0;

  notify({ progress: 50 });

  await new Promise<void>((resolve) => {
    setTimeout(() => resolve(), 1000);
  });

  return {
    userId: userId,
    name: "User"
  };
});
```

## License

This project is licensed under the MIT License.

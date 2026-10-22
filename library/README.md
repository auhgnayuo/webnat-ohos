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
    "webnat": "2.0.1"
  }
}
```

## Related Projects

Webnat requires a Web-side implementation and also supports other Native platforms:

| Platform | Repository |
|----------|------------|
| Web (JavaScript/TypeScript) | [webnat-web](https://github.com/auhgnayuo/webnat-web) |
| iOS / macOS (Swift) | [webnat-darwin](https://github.com/auhgnayuo/webnat-darwin) |
| Android (Kotlin) | [webnat-android](https://github.com/auhgnayuo/webnat-android) |

## 2.0.1 Data Contract and Migration

This 2.0.1 release distinguishes missing values from explicit JSON null. The previously published 2.0.0 contract v1 remains immutable.

Payloads, results, and notifications accept only JSON-compatible data: null, strings, booleans,
finite numbers, plain string-keyed records, and arrays, recursively. Objects use
`Record<string, ESObject>` and arrays use `ESObject[]`; ESObject is an interoperability carrier,
not permission to send arbitrary classes. JavaScript Map is not a JSON object.

Map, Set, Date, class instances, functions, symbol keys, accessors, hidden fields, non-finite numbers, and circular references are rejected. Undefined-valued object properties are recursively omitted; undefined array items / holes become null. At the top level, undefined omits the field while explicit null is preserved. Encoding does not invoke toJSON / toString.

A missing top-level value means the payload field is absent; explicit null remains JSON null. Nested object undefined properties are omitted; array undefined items / holes become null without shifting positions. Explicit nested nulls are preserved, as are empty string keys and special JSON keys such as __proto__.
Connection attributes accept objects only; null, arrays, and scalar connection parameters use an empty object instead.

Invalid sends follow the existing failure semantics: method rejects with SERIALIZATION_FAILED;
invalid method results produce that error reply. Raw / broadcast use trySend and remain silent,
but never transmit implicitly rewritten data. Message.from rejects the entire invalid message.

### Tests

Run `./scripts/test.sh` to execute all local tests in the DevEco / Hvigor ArkTS SDK previewer.
The script verifies the Hypium report as well as the build exit code, so failures / timeouts cannot
be mistaken for success. Requires hvigorw, Python 3, and the SDK; override HVIGORW / NODE_HOME as needed.
System APIs are mocked in the previewer; real-device Web component integration tests remain separate.

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

### 4. Send failures and handler errors

- A failed send is visible to the caller that waits for it: `method` rejects at once with `SERIALIZATION_FAILED` when the parameter cannot be serialized, and with `CLOSED` when the `WebviewController` is gone or the connection is closed. An error reported by `runJavaScript` rejects the call with that error. `raw` and `broadcast` stay fire-and-forget.
- A method handler that fails (throws, or rejects) is answered with an error reply `{ code, message }` (code -1 for an error without one), so the caller never waits for its timeout because of a handler bug. A result that cannot be serialized is answered with `SERIALIZATION_FAILED`.

### 5. Page crash and teardown

When a page unloads normally, the Web SDK sends CLOSE and Webnat ends that connection. A crashed render process or a destroyed `WebviewController` never gets to send it, so forward the event to Webnat: call `Webnat.of(this.controller).onRenderExited()` from the Web component's own `onRenderExited`, and once more before you drop the `WebviewController`. Webnat then ends the page's connections itself: pending `method` calls reject with `CLOSED` and running method handlers are aborted. Nothing is sent to the page, and Webnat stays usable, so a reloaded page opens new connections as usual.

```typescript
Web({ src: 'https://example.com', controller: this.controller })
  .onRenderExited(() => {
    Webnat.of(this.controller).onRenderExited();
  })

aboutToDisappear() {
  Webnat.of(this.controller).onRenderExited();
}
```

## License

This project is licensed under the MIT License.

## Shared regression contracts

See `contracts/README.md` for versioned golden fixtures and `contracts/CI.md` for test gates and runner setup.

## Release

Manual release instructions and migration notes: `RELEASING.md`. Upgrade the Web SDK and native bridge together to 2.0.1.

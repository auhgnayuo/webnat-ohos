import { createMethodWebnatForTest } from './test-fixtures';
import { describe, expect, it } from '@ohos/hypium';
import { AbortSignal } from '../main/ets/abortController';
import { Connection } from '../main/ets/connection';
import { WebnatError, WebnatErrorCode } from '../main/ets/error';
import { Invoke, Message } from '../main/ets/message';
import { Webnat } from '../main/ets/webnat';

/**
 * 只实现 Webnat.of / 发送路径用到的那几个方法的假 WebviewController。
 * 页面发来的消息通过 `post` 灌入（它调用 registerJavaScriptProxy 注册进来的 postMessage）。
 */
class FakeController {
  scripts: string[] = [];
  runError: Error | undefined = undefined;
  onScript: (script: string) => void = (_script: string): void => {};
  post: (text: string) => void = (_text: string): void => {
  };

  getCustomUserAgent(): string {
    return 'Mozilla/5.0 Webnat/1.2.0';
  }

  setCustomUserAgent(_userAgent: string): void {
  }

  getUrl(): string {
    return 'https://demo.example/app/';
  }

  registerJavaScriptProxy(proxyObject: object, _name: string, _methodList: Array<string>): void {
    const proxy: ESObject = proxyObject;
    this.post = (text: string): void => {
      proxy.postMessage(text);
    };
  }

  async runJavaScript(script: string): Promise<string> {
    if (this.runError !== undefined) {
      throw this.runError;
    }
    this.scripts.push(script);
    this.onScript(script);
    return '';
  }
}

class Harness {
  controller: FakeController = new FakeController();
  webnat: Webnat;

  constructor() {
    const asController: ESObject = this.controller;
    this.webnat = Webnat.of(asController);
    // 原样测试桥接 / 分发 / 编解码，仅替换 UUID 依赖（previewer 默认返回空字符串）。
    const boundary: ESObject = this.webnat;
    boundary.methodWebnat = createMethodWebnatForTest();
  }

  /** 模拟页面发来一条协议消息 */
  web(message: Message): void {
    this.controller.post(JSON.stringify(message.toDictionary()));
  }

  /** 模拟页面打开一个连接并返回它 */
  open(id: string): Connection {
    const attributes: Record<string, ESObject> = {};
    attributes['origin'] = 'https://demo.example' as ESObject;
    attributes['isMainframe'] = true as ESObject;
    this.web(Message.open(id, attributes as ESObject));
    return this.webnat.getConnections().get(id) as Connection;
  }
}

export default function webnatTest() {
  describe('Webnat', () => {
    it('decoded_maps_lists_and_native_null_reach_raw_and_broadcast_callbacks', 0, () => {
      const h = new Harness(); h.open('main');
      const payload: ESObject = JSON.parse('{"null":null,"items":[1,null,{"value":null}]}');
      let rawCount: number = 0; let broadcastCount: number = 0;
      h.webnat.onRaw((value: ESObject, _connection: Connection): void => {
        rawCount++; expect(JSON.stringify(value)).assertEqual(JSON.stringify(payload));
      });
      h.webnat.onBroadcast('event', (value: ESObject, _connection: Connection): void => {
        broadcastCount++; expect(JSON.stringify(value)).assertEqual(JSON.stringify(payload));
      });
      h.web(new Message('main', Message.NATIVE_UUID, undefined, undefined, Message.raw('main', payload).raw));
      h.web(new Message('main', Message.NATIVE_UUID, undefined, undefined, undefined, Message.broadcast('main', 'event', payload).broadcast));
      expect(rawCount).assertEqual(1); expect(broadcastCount).assertEqual(1);
      h.webnat.onRenderExited();
    });

    it('native_scripts_parse_json_text_without_turning_proto_keys_into_prototype_changes', 0, () => {
      const h = new Harness(); const connection = h.open('main');
      const payload: ESObject = JSON.parse('{"__proto__":{"safe":true},"text":"你好 😀"}');
      h.webnat.raw(payload, connection);
      const script: string = h.controller.scripts[h.controller.scripts.length - 1];
      const prefix: string = 'window.__web_webnat__.receive(...JSON.parse(';
      expect(script.startsWith(prefix)).assertEqual(true);
      const messages: ESObject = JSON.parse(JSON.parse(script.substring(prefix.length, script.length - 2)) as string);
      expect(JSON.stringify(messages[0].raw.param)).assertEqual(JSON.stringify(payload));
      expect(Object.keys(messages[0].raw.param).indexOf('__proto__') !== -1).assertEqual(true);
      h.webnat.onRenderExited();
    });

    it('missing_and_explicit_null_parameters_are_native_null_in_callbacks', 0, () => {
      const h = new Harness(); h.open('main');
      let count: number = 0;
      h.webnat.onRaw((value: ESObject, _connection: Connection): void => { expect(value).assertEqual(null); count++; });
      h.controller.post('{"magic":"WEBNAT","from":"main","to":"native","raw":{}}');
      h.controller.post('{"magic":"WEBNAT","from":"main","to":"native","raw":{"param":null}}');
      expect(count).assertEqual(2);
      h.webnat.onRenderExited();
    });

    it('method_handler_results_and_notifications_preserve_nested_nulls', 0, (): Promise<void> => {
      const h = new Harness(); h.open('main');
      const payload: ESObject = JSON.parse('{"null":null,"items":[1,null,3]}');
      let notifications: number = 0;
      h.webnat.onMethod('echo', async (value: ESObject, _signal: AbortSignal, notify, _connection: Connection): Promise<ESObject> => {
        expect(JSON.stringify(value)).assertEqual(JSON.stringify(payload)); notify(value); return value;
      });
      return new Promise<void>((resolve) => {
        h.controller.onScript = (script: string): void => {
          const prefix: string = 'window.__web_webnat__.receive(...JSON.parse(';
          if (!script.startsWith(prefix)) return;
          const messages: ESObject = JSON.parse(JSON.parse(script.substring(prefix.length, script.length - 2)) as string);
          const message: ESObject = messages[0];
          if (message.notify) { notifications++; expect(JSON.stringify(message.notify.param)).assertEqual(JSON.stringify(payload)); }
          if (message.reply) {
            expect(notifications).assertEqual(1); expect(JSON.stringify(message.reply.result)).assertEqual(JSON.stringify(payload));
            expect(message.reply.error === undefined).assertEqual(true); h.webnat.onRenderExited(); resolve();
          }
        };
        h.web(new Message('main', Message.NATIVE_UUID, undefined, undefined, undefined, undefined, new Invoke('echo-id', 'echo', payload)));
      });
    });

    it('explicit_null_reply_error_does_not_turn_success_into_failure', 0, (): Promise<void> => {
      const h = new Harness(); const connection = h.open('main');
      const pending: Promise<ESObject> = h.webnat.method({ method: 'remote' }, { timeout: 1000 }, connection);
      const script: string = h.controller.scripts[h.controller.scripts.length - 1];
      const prefix: string = 'window.__web_webnat__.receive(...JSON.parse(';
      const messages: ESObject = JSON.parse(JSON.parse(script.substring(prefix.length, script.length - 2)) as string);
      const dictionary: Record<string, ESObject> = Message.reply('main', messages[0].invoke.id, 42).toDictionary();
      dictionary['from'] = 'main'; dictionary['to'] = Message.NATIVE_UUID; dictionary['reply']['error'] = null;
      h.controller.post(JSON.stringify(dictionary));
      return pending.then((result: ESObject): void => { expect(result).assertEqual(42); h.webnat.onRenderExited(); });
    });

    it('non_finite_method_parameters_fail_without_being_changed_to_null', 0, (): Promise<void> => {
      const h = new Harness(); const connection = h.open('main');
      return h.webnat.method({ method: 'remote', param: NaN }, { timeout: 1000 }, connection).then((): void => {
        throw new Error('expected rejection');
      }).catch((error: Error): void => {
        expect((error as WebnatError).code).assertEqual(WebnatErrorCode.SERIALIZATION_FAILED);
        expect(h.controller.scripts.length).assertEqual(0); h.webnat.onRenderExited();
      });
    });

    it('invalid_method_results_produce_serializable_error_replies', 0, (): Promise<void> => {
      const h = new Harness(); h.open('main');
      h.webnat.onMethod('invalid', async (_value: ESObject, _signal, _notify, _connection): Promise<ESObject> => { return new Date(); });
      return new Promise<void>((resolve) => {
        h.controller.onScript = (script: string): void => {
          const prefix: string = 'window.__web_webnat__.receive(...JSON.parse(';
          if (!script.startsWith(prefix)) return;
          const messages: ESObject = JSON.parse(JSON.parse(script.substring(prefix.length, script.length - 2)) as string);
          if (messages[0].reply) {
            expect(messages[0].reply.error.code).assertEqual(WebnatErrorCode.SERIALIZATION_FAILED);
            expect(messages[0].reply.result === undefined).assertEqual(true); h.webnat.onRenderExited(); resolve();
          }
        };
        h.web(new Message('main', Message.NATIVE_UUID, undefined, undefined, undefined, undefined, new Invoke('invalid-id', 'invalid')));
      });
    });

    it('connection_attributes_only_accept_objects_and_preserve_nested_nulls', 0, () => {
      const h = new Harness();
      const values: ESObject[] = [null, 42, 'string', [1, 2]];
      for (let i = 0; i < values.length; i++) {
        const id: string = 'peer-' + i; h.web(Message.open(id, values[i]));
        expect(JSON.stringify(h.webnat.getConnections().get(id)?.attributes)).assertEqual('{}');
      }
      const payload: ESObject = JSON.parse('{"null":null,"items":[1,null]}');
      h.web(Message.open('object-peer', payload));
      expect(JSON.stringify(h.webnat.getConnections().get('object-peer')?.attributes)).assertEqual(JSON.stringify(payload));
      h.webnat.onRenderExited();
    });

    it('close_all_connections_ends_pending_calls_aborts_handlers_and_a_reload_can_open_again', 0, (): Promise<void> => {
      const h = new Harness();
      const main = h.open('main');
      h.open('frame-1');
      expect(h.webnat.getConnections().size).assertEqual(2);

      const signals: AbortSignal[] = [];
      h.webnat.onMethod('long_task', (_p: ESObject, signal: AbortSignal, _n, _c): Promise<ESObject> => {
        signals.push(signal);
        return new Promise<ESObject>((_resolve, _reject) => {
        });
      });
      h.web(new Message('main', Message.NATIVE_UUID, undefined, undefined, undefined, undefined,
        new Invoke('long-1', 'long_task')));
      expect(signals.length).assertEqual(1);
      const pending: Promise<ESObject> = h.webnat.method({ method: 'never_returns' }, undefined, main);
      const sent = h.controller.scripts.length;

      h.webnat.onRenderExited();
      return pending.then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.CLOSED);
        expect(signals[0].aborted).assertEqual(true);
        expect(h.webnat.getConnections().size).assertEqual(0);
        expect(main.closed).assertEqual(true);
        expect(h.controller.scripts.length).assertEqual(sent);

        h.webnat.onRenderExited();
        const reopened = h.open('main-2');
        expect(h.webnat.getConnections().size).assertEqual(1);
        expect(reopened.closed).assertEqual(false);
      });
    });

    it('method_rejects_at_once_when_the_parameter_cannot_be_serialized_or_the_script_fails', 0, (): Promise<void> => {
      const h = new Harness();
      const connection = h.open('main');
      const circular: Record<string, ESObject> = {};
      circular['self'] = circular as ESObject;
      return h.webnat.method({ method: 'x', param: circular as ESObject }, { timeout: 2000 }, connection).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): Promise<ESObject> => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.SERIALIZATION_FAILED);
        h.controller.runError = new Error('Script failed to execute');
        return h.webnat.method({ method: 'x' }, { timeout: 2000 }, connection);
      }).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        expect(e instanceof WebnatError).assertEqual(true);
        expect(e.message).assertEqual('Script failed to execute');
      });
    });
  });
}

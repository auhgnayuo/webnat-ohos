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
    return '';
  }
}

class Harness {
  controller: FakeController = new FakeController();
  webnat: Webnat;

  constructor() {
    const asController: ESObject = this.controller;
    this.webnat = Webnat.of(asController);
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

import { describe, expect, it } from '@ohos/hypium';
import { AbortController } from '../main/ets/abortController';
import { BroadcastMethodCall } from '../main/ets/broadcast-method-call';
import { ConnectionImpl } from '../main/ets/connection';
import { WebnatError, WebnatErrorCode } from '../main/ets/error';
import { Message } from '../main/ets/message';
import { MethodWebnat } from '../main/ets/method-webnat';

export default function broadcastMethodCallTest() {
  describe('BroadcastMethodCall', () => {

    // 无连接：立即以 closed 结束
    it('broadcast_empty_returns_closed', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const call = new BroadcastMethodCall((): void => {
      });
      return call.start([], mw, { method: 'm' }, undefined).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.CLOSED);
      });
    });

    // 仅一个 frame 实现该方法，其余回 unimplemented：应取实现者的结果
    it('broadcast_success_among_unimplemented', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const dummy = new ConnectionImpl('dummy', {}, undefined, async (): Promise<void> => {
      });
      const conn1 = new ConnectionImpl('c1', {}, undefined, async (m: Message): Promise<void> => {
        if (m.invoke) {
          mw.receive(Message.reply('c1', m.invoke.id, undefined, WebnatError.unimplemented('m').toJson() as ESObject), dummy);
        }
      });
      const conn2 = new ConnectionImpl('c2', {}, undefined, async (m: Message): Promise<void> => {
        if (m.invoke) {
          mw.receive(Message.reply('c2', m.invoke.id, 42 as ESObject, undefined), dummy);
        }
      });
      const call = new BroadcastMethodCall((): void => {
      });
      return call.start([conn1, conn2], mw, { method: 'm' }, undefined).then((result: ESObject): void => {
        expect(result as number).assertEqual(42);
      });
    });

    // 所有 frame 都未实现：最终返回 unimplemented
    it('broadcast_all_unimplemented_returns_unimplemented', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const dummy = new ConnectionImpl('dummy', {}, undefined, async (): Promise<void> => {
      });
      const mk = (id: string): ConnectionImpl => {
        return new ConnectionImpl(id, {}, undefined, async (m: Message): Promise<void> => {
          if (m.invoke) {
            mw.receive(Message.reply(id, m.invoke.id, undefined, WebnatError.unimplemented('m').toJson() as ESObject), dummy);
          }
        });
      };
      const call = new BroadcastMethodCall((): void => {
      });
      return call.start([mk('c1'), mk('c2'), mk('c3')], mw, { method: 'm' }, undefined).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.UNIMPLEMENTED);
      });
    });

    // 首个有意义响应是真实业务错误：直接以该错误获胜
    it('broadcast_real_error_wins', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const dummy = new ConnectionImpl('dummy', {}, undefined, async (): Promise<void> => {
      });
      const conn1 = new ConnectionImpl('c1', {}, undefined, async (m: Message): Promise<void> => {
        if (m.invoke) {
          mw.receive(Message.reply('c1', m.invoke.id, undefined, new WebnatError(123, 'boom').toJson() as ESObject), dummy);
        }
      });
      const conn2 = new ConnectionImpl('c2', {}, undefined, async (m: Message): Promise<void> => {
        if (m.invoke) {
          mw.receive(Message.reply('c2', m.invoke.id, undefined, WebnatError.unimplemented('m').toJson() as ESObject), dummy);
        }
      });
      const call = new BroadcastMethodCall((): void => {
      });
      return call.start([conn1, conn2], mw, { method: 'm' }, undefined).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        expect((e as WebnatError).code).assertEqual(123);
      });
    });

    // 胜者的 notify 应被透传；最终返回胜者结果
    it('broadcast_notify_forwarded_from_winner', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const dummy = new ConnectionImpl('dummy', {}, undefined, async (): Promise<void> => {
      });
      const conn1 = new ConnectionImpl('c1', {}, undefined, async (m: Message): Promise<void> => {
        if (m.invoke) {
          const id = m.invoke.id;
          mw.receive(Message.notify('c1', id, 'p' as ESObject), dummy);
          mw.receive(Message.reply('c1', id, 1 as ESObject, undefined), dummy);
        }
      });
      // conn2 从不主动回复，等待被 abort
      const conn2 = new ConnectionImpl('c2', {}, undefined, async (): Promise<void> => {
      });
      let notified: ESObject = null;
      const call = new BroadcastMethodCall((): void => {
      });
      return call.start([conn1, conn2], mw, { method: 'm' }, {
        onNotification: (p: ESObject): void => {
          notified = p;
        },
      }).then((result: ESObject): void => {
        expect(notified as string).assertEqual('p');
        expect(result as number).assertEqual(1);
      });
    });

    // 外部 signal 在发起后被取消：整组以 cancelled 结束
    it('broadcast_rejects_cancelled_when_outer_signal_aborted_later', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const conn1 = new ConnectionImpl('c1', {}, undefined, async (): Promise<void> => {
      });
      const ac = new AbortController();
      const call = new BroadcastMethodCall((): void => {
      });
      const pending: Promise<ESObject> = call.start([conn1], mw, { method: 'm' }, { signal: ac.signal });
      ac.abort();
      return pending.then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.CANCELLED);
      });
    });

    // 组级超时：无人回复时以 timeout 结束
    it('broadcast_group_timeout', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const conn1 = new ConnectionImpl('c1', {}, undefined, async (): Promise<void> => {
      });
      const conn2 = new ConnectionImpl('c2', {}, undefined, async (): Promise<void> => {
      });
      const call = new BroadcastMethodCall((): void => {
      });
      return call.start([conn1, conn2], mw, { method: 'm' }, { timeout: 100 }).then((): void => {
        throw new Error('expected timeout');
      }).catch((e: Error): void => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.TIMEOUT);
      });
    });
  });
}

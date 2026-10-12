import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { AbortController } from '../main/ets/abortController';
import { ConnectionImpl } from '../main/ets/connection';
import { WebnatError, WebnatErrorCode } from '../main/ets/error';
import { Invoke, Message } from '../main/ets/message';
import { MethodWebnat } from '../main/ets/method-webnat';

export default function methodWebnatTest() {
  describe('MethodWebnat', () => {
    beforeAll(() => {
    });
    beforeEach(() => {
    });
    afterEach(() => {
    });
    afterAll(() => {
    });

    it('method_rejects_when_signal_already_aborted', 0, (): Promise<void> => {
      const ac = new AbortController();
      ac.abort();
      const mw = new MethodWebnat();
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (_m: Message): Promise<void> => {
      });
      return mw.method({ method: 'x' }, { signal: ac.signal }, conn).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        const we = e as WebnatError;
        expect(we.code).assertEqual(WebnatErrorCode.CANCELLED);
      });
    });

    it('method_rejects_and_sends_abort_when_signal_aborted_later', 0, (): Promise<void> => {
      const ac = new AbortController();
      const mw = new MethodWebnat();
      const out: Message[] = [];
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (m: Message): Promise<void> => {
        out.push(m);
      });
      const pending: Promise<ESObject> = mw.method({ method: 'x' }, { signal: ac.signal }, conn);
      ac.abort();
      return pending.then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.CANCELLED);
        expect(out.length).assertEqual(2);
        expect(out[0].invoke !== undefined).assertEqual(true);
        expect(out[1].abort !== undefined).assertEqual(true);
      });
    });

    it('method_removes_abort_listener_after_completion', 0, (): Promise<void> => {
      const ac = new AbortController();
      const mw = new MethodWebnat();
      const out: Message[] = [];
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (m: Message): Promise<void> => {
        out.push(m);
      });
      const pending: Promise<ESObject> = mw.method({ method: 'x' }, { signal: ac.signal }, conn);
      const invokeId = out[0].invoke?.id as string;
      mw.receive(Message.reply('conn-1', invokeId, 1 as ESObject, undefined), conn);
      return pending.then((result: ESObject): void => {
        expect(result as number).assertEqual(1);
        ac.abort();
        expect(out.length).assertEqual(1);
      });
    });

    it('method_rejects_when_connection_undefined', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      return mw.method({ method: 'x' }, {}, undefined).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        const we = e as WebnatError;
        expect(we.code).assertEqual(WebnatErrorCode.CLOSED);
      });
    });

    it('method_rejects_when_send_fails', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (): Promise<void> => {
        throw WebnatError.closed();
      });
      return mw.method({ method: 'remote' }, {}, conn).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): void => {
        const we = e as WebnatError;
        expect(we.code).assertEqual(WebnatErrorCode.CLOSED);
        expect(we.message).assertEqual('Connection Closed');
      });
    });

    it('receive_invoke_unimplemented_sends_reply_error', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      const out: Message[] = [];
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (m: Message): Promise<void> => {
        out.push(m);
      });
      const msg = new Message('conn-1', Message.NATIVE_UUID, undefined, undefined, undefined, undefined,
        new Invoke('rid-1', 'missing_method'));
      return mw.receive(msg, conn).then((): void => {
        expect(out.length).assertEqual(1);
        expect(out[0].reply !== undefined).assertEqual(true);
        const err = WebnatError.from(out[0].reply?.error as ESObject);
        expect(err !== null && err !== undefined).assertEqual(true);
        expect(err?.code).assertEqual(WebnatErrorCode.UNIMPLEMENTED);
      });
    });

    it('receive_invoke_success_sends_reply', 0, (): Promise<void> => {
      const mw = new MethodWebnat();
      mw.on('echo', async (_p: ESObject, _s, _n, _c): Promise<ESObject> => {
        const r: Record<string, ESObject> = {};
        r['v'] = 1 as ESObject;
        return r as ESObject;
      });
      const out: Message[] = [];
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (m: Message): Promise<void> => {
        out.push(m);
      });
      const msg = new Message('conn-1', Message.NATIVE_UUID, undefined, undefined, undefined, undefined,
        new Invoke('rid-2', 'echo'));
      return mw.receive(msg, conn).then((): void => {
        expect(out.length).assertEqual(1);
        expect(out[0].reply !== undefined).assertEqual(true);
        expect(out[0].reply?.id).assertEqual('rid-2');
        expect(out[0].reply?.error === undefined || out[0].reply?.error === null).assertEqual(true);
      });
    });
  });
}

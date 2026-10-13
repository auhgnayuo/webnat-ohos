import { describe, expect, it } from '@ohos/hypium';
import { ConnectionImpl } from '../main/ets/connection';
import { WebnatError, WebnatErrorCode } from '../main/ets/error';
import { Message } from '../main/ets/message';

export default function connectionTest() {
  describe('ConnectionImpl', () => {
    it('send_surfaces_a_failing_transport_and_try_send_swallows_it', 0, (): Promise<void> => {
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (_m: Message): Promise<void> => {
        throw WebnatError.serializationFailed('x');
      });
      return conn.send(Message.raw('conn-1', 1 as ESObject)).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): Promise<void> => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.SERIALIZATION_FAILED);
        return conn.trySend(Message.raw('conn-1', 1 as ESObject));
      });
    });

    it('send_rejects_with_closed_after_dispose_and_try_send_still_swallows', 0, (): Promise<void> => {
      const conn = new ConnectionImpl('conn-1', {}, undefined, async (_m: Message): Promise<void> => {
      });
      conn.dispose();
      expect(conn.closed).assertEqual(true);
      return conn.send(Message.raw('conn-1', 1 as ESObject)).then((): void => {
        throw new Error('expected rejection');
      }).catch((e: Error): Promise<void> => {
        expect((e as WebnatError).code).assertEqual(WebnatErrorCode.CLOSED);
        return conn.trySend(Message.raw('conn-1', 1 as ESObject));
      });
    });
  });
}

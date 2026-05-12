import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { BroadcastWebnat } from '../main/ets/broadcast-webnat';
import { Connection } from '../main/ets/connection';
import { Broadcast, Message } from '../main/ets/message';

export default function broadcastWebnatTest() {
  describe('BroadcastWebnat', () => {
    beforeAll(() => {
    });
    beforeEach(() => {
    });
    afterEach(() => {
    });
    afterAll(() => {
    });

    it('receive_ignores_broadcast_with_empty_name', 0, () => {
      const bw = new BroadcastWebnat();
      let hits = 0;
      bw.on('evt', (_p: ESObject, _c: Connection): void => {
        hits++;
      });
      const stub: Connection = { id: 'c1', closed: false };
      const msg = new Message('c1', Message.NATIVE_UUID, undefined, undefined, undefined, new Broadcast(''));
      bw.receive(msg, stub);
      expect(hits).assertEqual(0);
    });

    it('receive_dispatches_valid_broadcast', 0, () => {
      const bw = new BroadcastWebnat();
      let hits = 0;
      let seenId = '';
      bw.on('evt', (_p: ESObject, c: Connection): void => {
        hits++;
        seenId = c.id;
      });
      const stub: Connection = { id: 'c2', closed: false };
      const msg = new Message('c2', Message.NATIVE_UUID, undefined, undefined, undefined, new Broadcast('evt'));
      bw.receive(msg, stub);
      expect(hits).assertEqual(1);
      expect(seenId).assertEqual('c2');
    });
  });
}

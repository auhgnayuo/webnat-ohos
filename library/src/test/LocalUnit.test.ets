import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { Message } from '../main/ets/message';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('message_open_round_trip', 0, () => {
      const original = Message.open('conn-a');
      const dict = original.toDictionary();
      const parsed = Message.from(dict);
      expect(parsed?.from).assertEqual('conn-a');
      expect(parsed?.open === undefined).assertEqual(false);
    });

    it('message_broadcast_round_trip', 0, () => {
      const original = Message.broadcast('conn-a', 'evt');
      const parsed = Message.from(original.toDictionary());
      expect(parsed?.broadcast?.name).assertEqual('evt');
    });

    it('message_from_rejects_wrong_magic', 0, () => {
      const dict = Message.open('conn-a').toDictionary();
      dict['magic'] = 'NOPE';
      const parsed = Message.from(dict);
      expect(parsed).assertEqual(undefined);
    });

    it('message_from_rejects_missing_fields', 0, () => {
      const invalid = Message.open('conn-a').toDictionary();
      invalid['from'] = '';
      const parsed = Message.from(invalid);
      expect(parsed).assertEqual(undefined);
    });
  });
}
import { describe, expect, it } from '@ohos/hypium';
import { fromJsonValue, toJsonValue } from '../main/ets/json-value';
import { Message } from '../main/ets/message';
import { WebnatError, WebnatErrorCode } from '../main/ets/error';

class CustomValue { value: number = 1; }

function rejected(value: ESObject, decoding: boolean = false): void {
  let failed: boolean = false;
  try {
    if (decoding) fromJsonValue(value); else toJsonValue(value);
  } catch (error) {
    failed = true;
    expect((error as WebnatError).code).assertEqual(decoding ? WebnatErrorCode.DESERIALIZATION_FAILED : WebnatErrorCode.SERIALIZATION_FAILED);
  }
  expect(failed).assertEqual(true);
}

function record(key: string, value: ESObject): Record<string, ESObject> {
  const result: Record<string, ESObject> = {};
  result[key] = value;
  return result;
}

export default function jsonValueTest() {
  describe('JSON value contract', () => {
    it('nested_nulls_empty_keys_and_containers_round_trip', 0, () => {
      const value: Record<string, ESObject> = {};
      value[''] = 'empty key';
      value['null'] = null;
      value['list'] = [1, null, record('nested', null)];
      value['emptyObject'] = {} as Record<string, ESObject>;
      value['emptyList'] = [] as ESObject[];
      const json: string = JSON.stringify(toJsonValue(value));
      const decoded: ESObject = fromJsonValue(JSON.parse(json));
      expect(JSON.stringify(decoded)).assertEqual(json);
      expect(Object.keys(decoded).indexOf('null') !== -1).assertEqual(true);
      expect(decoded['null']).assertEqual(null);
      expect(decoded['list'].length).assertEqual(3);
      expect(decoded['list'][1]).assertEqual(null);
    });

    it('missing_and_explicit_null_remain_distinct', 0, () => {
      expect(fromJsonValue(undefined) === undefined).assertEqual(true);
      expect(fromJsonValue(null)).assertEqual(null);
      expect(toJsonValue(null)).assertEqual(null);
      expect(Message.open('peer').open?.param === undefined).assertEqual(true);
      expect(Message.raw('peer').raw?.param === undefined).assertEqual(true);
    });

    it('top_level_lists_scalars_and_booleans_are_preserved', 0, () => {
      const values: ESObject[] = ['text', true, false, 0, 1, -1, 1.5, [1, null, 3]];
      for (let i = 0; i < values.length; i++) expect(JSON.stringify(fromJsonValue(toJsonValue(values[i])))).assertEqual(JSON.stringify(values[i]));
    });

    it('rejects_non_finite_numbers_at_every_level', 0, () => {
      const values: number[] = [NaN, Infinity, -Infinity];
      for (let i = 0; i < values.length; i++) {
        const value: ESObject = values[i];
        rejected(value); rejected([value]); rejected(record('nested', [value]));
        rejected(value, true); rejected([value], true);
      }
    });

    it('rejects_map_set_date_classes_and_functions_without_stringifying', 0, () => {
      const values: ESObject[] = [new Map<string, number>(), new Set<number>(), new Date(), new CustomValue(), (): void => {}];
      for (let i = 0; i < values.length; i++) {
        const value: ESObject = values[i];
        rejected(value); rejected([value]); rejected(record('nested', value));
        rejected(value, true);
      }
    });

    it('omits_object_undefined_and_normalizes_array_undefined_to_null', 0, () => {
      const value: Record<string, ESObject> = record('drop', undefined);
      value['keep'] = null;
      value['list'] = [undefined, null, 1];
      expect(JSON.stringify(toJsonValue(value))).assertEqual('{"keep":null,"list":[null,null,1]}');
      expect(JSON.stringify(fromJsonValue(value))).assertEqual('{"keep":null,"list":[null,null,1]}');
      expect(toJsonValue(undefined) === undefined).assertEqual(true);
      const hole: ESObject[] = new Array(2);
      expect(JSON.stringify(toJsonValue(hole))).assertEqual('[null,null]');
    });

    it('rejects_cycles_but_permits_shared_children', 0, () => {
      const circular: Record<string, ESObject> = {};
      circular['self'] = circular;
      rejected(circular); rejected(circular, true);
      const array: ESObject[] = [];
      array.push(array);
      rejected(array); rejected(array, true);
      const child: ESObject[] = [1, null];
      const value: Record<string, ESObject> = record('a', child);
      value['b'] = child;
      expect(JSON.stringify(fromJsonValue(toJsonValue(value)))).assertEqual(JSON.stringify(value));
    });

    it('does_not_invoke_toJSON_or_toString_hooks', 0, () => {
      let called: boolean = false;
      const value: Record<string, ESObject> = {};
      value['toJSON'] = (): string => { called = true; return 'hidden'; };
      rejected(value);
      expect(called).assertEqual(false);
    });

    it('rejects_symbol_keys_instead_of_silently_dropping_them', 0, () => {
      const symbolFactory: ESObject = Symbol;
      const value: Record<string, ESObject> = {};
      const dynamic: ESObject = value;
      const key: ESObject = symbolFactory('key');
      dynamic[key] = 1;
      rejected(value); rejected(value, true);
    });

    it('rejects_accessors_without_executing_them', 0, () => {
      const objectApi: ESObject = Object;
      const value: Record<string, ESObject> = {};
      const descriptor: Record<string, ESObject> = {};
      let called: boolean = false;
      descriptor['get'] = (): string => { called = true; return 'hidden'; };
      descriptor['enumerable'] = true;
      objectApi.defineProperty(value, 'getter', descriptor);
      rejected(value); rejected(value, true);
      expect(called).assertEqual(false);
    });

    it('rejects_hidden_fields_instead_of_silently_dropping_them', 0, () => {
      const objectApi: ESObject = Object;
      const value: Record<string, ESObject> = {};
      const descriptor: Record<string, ESObject> = {};
      descriptor['value'] = 1;
      descriptor['enumerable'] = false;
      objectApi.defineProperty(value, 'hidden', descriptor);
      rejected(value); rejected(value, true);
    });

    it('preserves_proto_keys_without_prototype_mutation', 0, () => {
      const value: ESObject = JSON.parse('{"__proto__":{"x":1},"constructor":null,"":null}');
      const encoded: ESObject = toJsonValue(value);
      expect(JSON.stringify(encoded)).assertEqual(JSON.stringify(value));
      expect(Object.keys(encoded).indexOf('__proto__') !== -1).assertEqual(true);
      expect(JSON.stringify(fromJsonValue(encoded))).assertEqual(JSON.stringify(value));
    });

    it('all_message_payload_fields_round_trip_and_reject_invalid_data', 0, () => {
      const value: Record<string, ESObject> = record('nested', [1, null, 3]);
      value['missing'] = null;
      const messages: Message[] = [Message.open('p', value), Message.close('p', value), Message.raw('p', value),
        Message.broadcast('p', 'event', value), Message.invoke('p', 'i', 'method', value),
        Message.reply('p', 'i', value), Message.reply('p', 'i', undefined, value), Message.notify('p', 'i', value), Message.abort('p', 'i')];
      for (const message of messages) {
        const json: string = JSON.stringify(message.toDictionary());
        const parsed: Message | undefined = Message.from(JSON.parse(json));
        expect(parsed !== undefined).assertEqual(true);
        expect(JSON.stringify(parsed?.toDictionary())).assertEqual(json);
      }
      const invalid: ESObject = new Date();
      const invalidMessages: Message[] = [Message.open('p', invalid), Message.close('p', invalid), Message.raw('p', invalid),
        Message.broadcast('p', 'e', invalid), Message.invoke('p', 'i', 'm', invalid), Message.reply('p', 'i', invalid),
        Message.reply('p', 'i', undefined, invalid), Message.notify('p', 'i', invalid)];
      for (const message of invalidMessages) {
        let failed: boolean = false;
        try { message.toDictionary(); } catch (_error) { failed = true; }
        expect(failed).assertEqual(true);
      }
    });

    it('missing_payload_fields_are_omitted_and_explicit_null_is_preserved', 0, () => {
      const messages: Message[] = [Message.open('p'), Message.close('p'), Message.raw('p'), Message.broadcast('p', 'e'),
        Message.invoke('p', 'i', 'm'), Message.reply('p', 'i'), Message.notify('p', 'i')];
      for (const message of messages) {
        const json: string = JSON.stringify(message.toDictionary());
        expect(json.indexOf('"param"') === -1).assertEqual(true);
        expect(JSON.stringify(Message.from(JSON.parse(json))?.toDictionary())).assertEqual(json);
      }
      const reply: Message | undefined = Message.from(JSON.parse('{"magic":"WEBNAT","from":"p","to":"native","reply":{"id":"i","result":null,"error":null}}'));
      expect(reply?.reply?.result).assertEqual(null);
      expect(reply?.reply?.error).assertEqual(null);
      expect(JSON.stringify(reply?.toDictionary())).assertEqual('{"magic":"WEBNAT","from":"p","to":"native","reply":{"id":"i","result":null,"error":null}}');
    });

    it('invalid_decoded_data_in_every_payload_field_rejects_the_message', 0, () => {
      const bodies: string[] = ['open', 'close', 'raw', 'broadcast', 'invoke', 'reply', 'notify'];
      const invalidValues: ESObject[] = [new Date(), NaN, new Map<string, number>()];
      for (const body of bodies) {
        const fields: string[] = body === 'reply' ? ['result', 'error'] : ['param'];
        for (const field of fields) {
          for (let i = 0; i < invalidValues.length; i++) {
            const payload: Record<string, ESObject> = record('id', 'i'); payload['method'] = 'm'; payload['name'] = 'e';
            payload[field] = invalidValues[i];
            const envelope: Record<string, ESObject> = record('magic', Message.MAGIC); envelope['from'] = 'p'; envelope['to'] = 'n'; envelope[body] = payload;
            expect(Message.from(envelope) === undefined).assertEqual(true);
          }
        }
      }
    });

    it('malformed_body_types_are_not_treated_as_missing_fields', 0, () => {
      const bodies: string[] = ['open', 'close', 'raw', 'broadcast', 'invoke', 'reply', 'notify', 'abort'];
      const invalid: ESObject[] = [null, 'string', [1, 2]];
      for (const body of bodies) {
        for (let i = 0; i < invalid.length; i++) {
          const envelope: Record<string, ESObject> = record('magic', Message.MAGIC); envelope['from'] = 'p'; envelope['to'] = 'n'; envelope[body] = invalid[i];
          expect(Message.from(envelope) === undefined).assertEqual(true);
        }
      }
    });

    it('unicode_controls_and_quoted_strings_round_trip', 0, () => {
      const strings: string[] = ['', '你好 😀', '\n\r\t\\\"', '\u0000\u2028\u2029'];
      const json: string = JSON.stringify(toJsonValue(strings));
      expect(JSON.stringify(fromJsonValue(JSON.parse(json)))).assertEqual(json);
    });

    it('invalid_incoming_data_rejects_the_whole_message', 0, () => {
      const value: Record<string, ESObject> = record('magic', Message.MAGIC);
      value['from'] = 'p'; value['to'] = 'native'; value['raw'] = record('param', new Date());
      expect(Message.from(value) === undefined).assertEqual(true);
      expect(Message.from(JSON.parse('{"magic":"WEBNAT","from":"p","to":"native","raw":{"param":1e400}}')) === undefined).assertEqual(true);
    });
  });
}

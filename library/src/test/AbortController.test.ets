import { describe, expect, it } from '@ohos/hypium';
import { AbortController, AbortEvent } from '../main/ets/abortController';

export default function abortControllerTest() {
  describe('AbortController', () => {

    it('signal_initial_state', 0, (): void => {
      const ac = new AbortController();
      expect(ac.signal.aborted).assertEqual(false);
      expect(ac.signal.reason === undefined).assertEqual(true);
      expect(ac.signal.onabort === null).assertEqual(true);
    });

    it('abort_sets_default_abort_error_reason', 0, (): void => {
      const ac = new AbortController();
      ac.abort();
      expect(ac.signal.aborted).assertEqual(true);
      const reason = ac.signal.reason as Error;
      expect(reason instanceof Error).assertEqual(true);
      expect(reason.name).assertEqual('AbortError');
      expect(reason.message).assertEqual('This operation was aborted');
    });

    it('abort_keeps_custom_reason', 0, (): void => {
      const error = new Error('custom');
      const ac1 = new AbortController();
      ac1.abort(error as ESObject);
      expect((ac1.signal.reason as Error) === error).assertEqual(true);

      const ac2 = new AbortController();
      ac2.abort('timeout' as ESObject);
      expect(ac2.signal.reason as string).assertEqual('timeout');
    });

    it('abort_twice_only_first_takes_effect', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      ac.signal.addEventListener('abort', (): void => {
        count++;
      });
      ac.abort('first' as ESObject);
      ac.abort('second' as ESObject);
      expect(count).assertEqual(1);
      expect(ac.signal.reason as string).assertEqual('first');
    });

    it('listener_receives_abort_event', 0, (): void => {
      const ac = new AbortController();
      const events: AbortEvent[] = [];
      ac.signal.addEventListener('abort', (event: AbortEvent): void => {
        events.push(event);
      });
      ac.abort();
      expect(events.length).assertEqual(1);
      expect(events[0].type).assertEqual('abort');
      expect(events[0].target === ac.signal).assertEqual(true);
    });

    it('listener_registered_twice_is_called_once', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      const listener = (): void => {
        count++;
      };
      ac.signal.addEventListener('abort', listener);
      ac.signal.addEventListener('abort', listener);
      ac.abort();
      expect(count).assertEqual(1);
    });

    it('removed_listener_is_not_called', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      const listener = (): void => {
        count++;
      };
      ac.signal.addEventListener('abort', listener);
      ac.signal.removeEventListener('abort', listener);
      ac.abort();
      expect(count).assertEqual(0);
    });

    it('listener_added_after_abort_is_not_called', 0, (): void => {
      const ac = new AbortController();
      ac.abort();
      let count = 0;
      ac.signal.addEventListener('abort', (): void => {
        count++;
      });
      expect(count).assertEqual(0);
    });

    it('listener_removed_during_dispatch_is_skipped', 0, (): void => {
      const ac = new AbortController();
      const calls: string[] = [];
      const second = (): void => {
        calls.push('second');
      };
      ac.signal.addEventListener('abort', (): void => {
        calls.push('first');
        ac.signal.removeEventListener('abort', second);
      });
      ac.signal.addEventListener('abort', second);
      ac.abort();
      expect(calls.join(',')).assertEqual('first');
    });

    it('throwing_listener_does_not_block_others', 0, (): void => {
      const ac = new AbortController();
      const calls: string[] = [];
      ac.signal.addEventListener('abort', (): void => {
        throw new Error('boom');
      });
      ac.signal.addEventListener('abort', (): void => {
        calls.push('after');
      });
      ac.abort();
      expect(calls.join(',')).assertEqual('after');
    });

    it('unknown_event_type_is_ignored', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      ac.signal.addEventListener('foo', (): void => {
        count++;
      });
      ac.abort();
      expect(count).assertEqual(0);
    });

    it('once_option_is_accepted', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      ac.signal.addEventListener('abort', (): void => {
        count++;
      }, { once: true });
      ac.abort();
      expect(count).assertEqual(1);
    });

    it('onabort_is_called_in_first_assignment_order', 0, (): void => {
      const ac = new AbortController();
      const calls: string[] = [];
      ac.signal.addEventListener('abort', (): void => {
        calls.push('a');
      });
      ac.signal.onabort = (): void => {
        calls.push('x');
      };
      ac.signal.addEventListener('abort', (): void => {
        calls.push('b');
      });
      ac.signal.onabort = (): void => {
        calls.push('y');
      };
      ac.abort();
      expect(calls.join(',')).assertEqual('a,y,b');
    });

    it('onabort_null_stops_calling', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      ac.signal.onabort = (): void => {
        count++;
      };
      ac.signal.onabort = null;
      ac.abort();
      expect(count).assertEqual(0);
    });

    it('throw_if_aborted', 0, (): void => {
      const ac = new AbortController();
      ac.signal.throwIfAborted();
      const reason = new Error('stop');
      ac.abort(reason as ESObject);
      const thrown: Error[] = [];
      try {
        ac.signal.throwIfAborted();
      } catch (e) {
        thrown.push(e as Error);
      }
      expect(thrown.length).assertEqual(1);
      expect(thrown[0] === reason).assertEqual(true);
    });

    it('deprecated_add_listener_is_called_on_abort', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      const listener = (): void => {
        count++;
      };
      ac.signal.addListener(listener);
      ac.signal.addListener(listener);
      ac.abort();
      expect(count).assertEqual(1);
    });

    it('deprecated_add_listener_on_aborted_signal_calls_immediately', 0, (): void => {
      const ac = new AbortController();
      ac.abort();
      let count = 0;
      ac.signal.addListener((): void => {
        count++;
      });
      expect(count).assertEqual(1);
    });

    it('deprecated_remove_listener_prevents_call', 0, (): void => {
      const ac = new AbortController();
      let count = 0;
      const listener = (): void => {
        count++;
      };
      ac.signal.addListener(listener);
      ac.signal.removeListener(listener);
      ac.abort();
      expect(count).assertEqual(0);
    });
  });
}

import { MethodWebnat } from '../main/ets/method-webnat';

let nextCallId: number = 0;

/** Previewer 的 UUID 为模拟值；保持唯一的合法 ID，以验证真正的协议往返与并发调用。 */
export function createMethodWebnatForTest(): MethodWebnat {
  return new MethodWebnat((): string => 'test-call-' + nextCallId++);
}

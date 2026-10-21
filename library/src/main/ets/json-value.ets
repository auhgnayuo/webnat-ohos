import { WebnatError, WebnatErrorCode } from './error';

/**
 * 将业务数据递归转换为可编码的 JSON 值。
 * 仅支持 null、string、boolean、有限 number、普通字符串键对象和数组。
 * ESObject 只是承载类型，不代表允许任意对象。拒绝 undefined、Map、Set、Date、
 * 类实例、函数、Symbol 键、访问器、隐藏字段、非有限数字和循环引用；不调用 toJSON / toString，也不删除字段。
 */
export function toJsonValue(value: ESObject): ESObject {
  return convert(value, false, []);
}

/**
 * 将接收的 JSON 数据转换为业务数据；缺失的顶层字段和 JSON null 均为 null。
 * 嵌套 null 保留键和数组位置，嵌套 undefined 非法；不会跳过非法元素。
 */
export function fromJsonValue(value: ESObject): ESObject {
  return convert(value === undefined ? null : value, true, []);
}

function convert(value: ESObject, decoding: boolean, ancestors: ESObject[]): ESObject {
  const fail = (reason: string): never => {
    throw new WebnatError(decoding ? WebnatErrorCode.DESERIALIZATION_FAILED : WebnatErrorCode.SERIALIZATION_FAILED, reason);
  };
  if (value === null) return null;
  const type = typeof value;
  if (type === 'string' || type === 'boolean') return value;
  if (type === 'number') {
    if (!Number.isFinite(value as number)) fail('JSON numbers must be finite');
    return value;
  }
  if (type !== 'object') fail('Unsupported JSON value type: ' + type);
  if (ancestors.indexOf(value) !== -1) fail('Circular JSON value');
  ancestors.push(value);
  try {
    if (Array.isArray(value)) {
      const result: ESObject[] = [];
      const array: ESObject = value;
      for (let i = 0; i < array.length; i++) result.push(convert(array[i], decoding, ancestors));
      return result;
    }
    // ESObject 是与 JS JSON 值互操作的边界；反射只在此处使用。
    const objectApi: ESObject = Object;
    const prototype: ESObject = objectApi.getPrototypeOf(value);
    if (prototype !== objectApi.prototype && prototype !== null) fail('JSON objects must be plain records');
    if (objectApi.getOwnPropertySymbols(value).length !== 0) fail('JSON object keys must be strings');
    const keys: string[] = Object.keys(value);
    if (objectApi.getOwnPropertyNames(value).length !== keys.length) fail('JSON records cannot contain hidden fields');
    const result: Record<string, ESObject> = {};
    for (const key of keys) {
      const source: ESObject = objectApi.getOwnPropertyDescriptor(value, key);
      if (source.get !== undefined || source.set !== undefined) fail('JSON records cannot contain accessors');
      // defineProperty 保留 __proto__ 等合法 JSON 键，不能意外修改原型。
      const descriptor: Record<string, ESObject> = {};
      descriptor['value'] = convert(source.value, decoding, ancestors);
      descriptor['enumerable'] = true;
      descriptor['writable'] = true;
      descriptor['configurable'] = true;
      objectApi.defineProperty(result, key, descriptor);
    }
    return result;
  } finally {
    ancestors.pop();
  }
}

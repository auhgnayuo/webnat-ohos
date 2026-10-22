import {describe,expect,it} from '@ohos/hypium';
import {contractJson} from './contract-fixtures';
import {Message} from '../main/ets/message';
import {WebnatError} from '../main/ets/error';
import {toJsonValue,fromJsonValue} from '../main/ets/json-value';

export default function sharedContractsTest() {
 const fixtures: ESObject=JSON.parse(contractJson);
 describe('shared contract v2',()=>{
  const errors:ESObject=fixtures.errors;
  for(let i=0;i<errors.length;i++) {
   const c:ESObject=errors[i];it('contract/'+c.id,0,()=>{
    const e=WebnatError.from(c.input);
    if(c.expected===null) expect(e===null).assertEqual(true);
    else {expect(e?.code).assertEqual(c.expected.code);expect(e?.message).assertEqual(c.expected.message)}
   });
  }
  const messages:ESObject=fixtures.messages;
  for(let i=0;i<messages.length;i++) {const c:ESObject=messages[i];it('contract/'+c.id,0,()=>{
   const m=Message.from(c.input);expect(m!==undefined).assertEqual(true);
   expect(JSON.stringify(m?.toDictionary())).assertEqual(JSON.stringify(c.canonical));
  })}
  const rejected:ESObject=fixtures.rejectedMessages;
  for(let i=0;i<rejected.length;i++){const c:ESObject=rejected[i];it('contract/'+c.id,0,()=>expect(Message.from(c.input)===undefined).assertEqual(true))}
  const invalid:ESObject=fixtures.invalidValues;
  for(let i=0;i<invalid.length;i++){const c:ESObject=invalid[i];it('contract/'+c.id,0,()=>{
   let value:ESObject;
   if(c.kind==='nan') value=NaN; else if(c.kind==='positive-infinity') value=Infinity;else if(c.kind==='negative-infinity') value=-Infinity;
   else if(c.kind==='array-cycle'){const a:ESObject[]=[];a.push(a);value=a}
   else {const o:Record<string,ESObject>={};o['self']=o;value=o}
   let encoding:boolean=false;let decoding:boolean=false;
   try{toJsonValue(value)}catch(e){encoding=true;expect((e as WebnatError).code).assertEqual(c.encodeCode)}
   try{fromJsonValue(value)}catch(e){decoding=true;expect((e as WebnatError).code).assertEqual(c.decodeCode)}
   expect(encoding&&decoding).assertEqual(true);
  })}
 });
}

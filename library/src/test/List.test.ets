import sharedContractsTest from './SharedContracts.test';
import jsonValueTest from './JsonValue.test';
import abortControllerTest from './AbortController.test';
import broadcastMethodCallTest from './BroadcastMethodCall.test';
import broadcastWebnatTest from './BroadcastWebnat.test';
import connectionTest from './Connection.test';
import localUnitTest from './LocalUnit.test';
import methodWebnatTest from './MethodWebnat.test';
import webnatTest from './Webnat.test';

export default function testsuite() {
  abortControllerTest();
  localUnitTest();
  sharedContractsTest();
  jsonValueTest();
  connectionTest();
  methodWebnatTest();
  webnatTest();
  broadcastWebnatTest();
  broadcastMethodCallTest();
}
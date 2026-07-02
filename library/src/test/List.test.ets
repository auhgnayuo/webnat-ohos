import broadcastMethodCallTest from './BroadcastMethodCall.test';
import broadcastWebnatTest from './BroadcastWebnat.test';
import localUnitTest from './LocalUnit.test';
import methodWebnatTest from './MethodWebnat.test';

export default function testsuite() {
  localUnitTest();
  methodWebnatTest();
  broadcastWebnatTest();
  broadcastMethodCallTest();
}
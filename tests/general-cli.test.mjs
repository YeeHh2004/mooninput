import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
test('generic CLI configuration and compositional replay run the same engine',()=>{
  const run=args=>JSON.parse(execFileSync(process.execPath,['cli/mooninput.mjs',...args],{encoding:'utf8'}));
  assert.equal(run(['--config','examples/dynamic-config.json','123456']).active,'long');
  const replay=run(['--replay','examples/composite-events.json']);
  assert.equal(replay.state.value,'12:59');assert.deepEqual(replay.state.fields,[{name:'hour',value:'12'},{name:'minute',value:'59'}]);
});

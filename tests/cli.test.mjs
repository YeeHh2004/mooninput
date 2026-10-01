import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
function run(args){const result=spawnSync(process.execPath,['cli/mooninput.mjs',...args],{cwd:root,encoding:'utf8'});return{code:result.status,data:JSON.parse(result.stdout)};}
test('CLI formats exact decimal values',()=>{
  const result=run(['--decimal','9007199254740993.10']);
  assert.equal(result.code,0);assert.equal(result.data.value,'9007199254740993.10');
});
test('CLI replay uses selections and returns a trace',()=>{
  const result=run(['--replay','examples/events.json']);
  assert.equal(result.code,0);assert.equal(result.data.state.value,'2024-02-28');assert.equal(result.data.trace.length,3);
});
test('CLI differentiates invalid date and malformed arguments',()=>{
  assert.equal(run(['--date','2023-02-29']).code,1);
  assert.equal(run(['--unknown']).code,2);
  assert.equal(run(['--replay','does-not-exist.json']).code,2);
});

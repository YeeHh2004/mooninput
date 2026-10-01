import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const expected='138 0013 8000\n13800138000\n9,007,199,254,740,993.10\n9007199254740993.10\nValue is day is outside this month\n2024-02-29';
for(const target of ['js','wasm-gc']){
  const output=execFileSync('moon',['run','examples/basic','--target',target],{encoding:'utf8'}).trim().replaceAll('\r\n','\n');
  assert.equal(output,expected,`${target} example output`);
}
console.log('README example output matches on JS and Wasm GC.');

import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const expected='138 0013 8000\n13800138000\n9,007,199,254,740,993.10\n9007199254740993.10\nValue is day is outside this month\n2024-02-29';
for(const target of ['js','wasm-gc']){
  const output=execFileSync('moon',['run','examples/basic','--target',target],{encoding:'utf8'}).trim().replaceAll('\r\n','\n');
  assert.equal(output,expected,`${target} example output`);
  const rules=execFileSync('moon',['run','examples/rules','--target',target],{encoding:'utf8'}).trim().replaceAll('\r\n','\n');
  assert.equal(rules,'dynamic=long:123-456\ncomposite=23:59\ndefinition=AB:12\nregex=moon_bit\nrepeat=ONOFF\nnumber=9007199254740993.10\ndate=2024-02-29\nvalidation=1216\nfunction=135\npresentation=**-__',`${target} general rules output`);
}
console.log('README example output matches on JS and Wasm GC.');

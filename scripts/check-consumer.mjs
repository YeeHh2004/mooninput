import {mkdtempSync,cpSync,writeFileSync,readFileSync,rmSync,readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../',import.meta.url)).replaceAll('\\','/');
const workspace=mkdtempSync(join(tmpdir(),'mooninput-consumer-')),consumer=join(workspace,'consumer');
const registry=process.argv.includes('--registry');
try{
  cpSync(new URL('../examples/consumer/',import.meta.url),consumer,{recursive:true,filter:source=>!/[\\/](_build|\.mooncakes)([\\/]|$)/.test(source)});
  const run=args=>execFileSync('moon',args,{cwd:consumer,encoding:'utf8',stdio:['ignore','pipe','inherit']});
  if(registry){
    writeFileSync(join(consumer,'moon.mod'),'name = "mooninput-examples/consumer"\n\nversion = "0.1.1"\n');
    run(['add','YeeHh2004/mooninput@0.1.1']);
    run(['build','--target','js']);
    const downloaded=join(consumer,'.mooncakes','YeeHh2004','mooninput');
    for(const name of readdirSync(root).filter(n=>n.endsWith('.mbt')||n.endsWith('.mbti'))){
      const norm=text=>text.replaceAll('\r\n','\n');
      assert.equal(norm(readFileSync(join(downloaded,name),'utf8')),norm(readFileSync(join(root,name),'utf8')),`Published source: ${name}`);
    }
  }else writeFileSync(join(workspace,'moon.work'),`members = [\n  ${JSON.stringify(root)},\n  "consumer",\n]\n`);
  run(['fmt','--check']);
  for(const target of ['js','wasm-gc']){
    process.stdout.write(run(['test','--target',target]));
    assert.equal(run(['run','.','--target',target]).trim().replaceAll('\r\n','\n'),'AB-1234\nAB1234');
  }
  console.log(`${registry?'Public registry':'Local workspace'} consumer verified on JS and Wasm GC.`);
}finally{
  assert.equal(dirname(resolve(workspace)),resolve(tmpdir()));
  rmSync(workspace,{recursive:true,force:true});
}

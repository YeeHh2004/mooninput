import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {startServer} from '../scripts/serve.mjs';
const engines=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const engine=process.env.BROWSER_ENGINE||'chromium';
if(!['chromium','firefox','webkit'].includes(engine))throw new Error('Unsupported BROWSER_ENGINE');
const server=await startServer();
let browser;
const checks=[],failures=[];
function check(name,actual,expected){
  try{assert.deepEqual(actual,expected,name);checks.push(name);}
  catch(error){failures.push({name,message:error.message,actual,expected});}
}
try{
  browser=await engines[engine].launch({headless:true,...(process.env.BROWSER_CHANNEL?{channel:process.env.BROWSER_CHANNEL}:{})});
  const page=await browser.newPage({viewport:{width:1280,height:900}});
  const exceptions=[];page.on('pageerror',error=>exceptions.push(error.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.waitForFunction(()=>document.documentElement.dataset.ready==='true');
  const initialCallback=await page.evaluate(async()=>{
    const {bindInput}=await import('./adapter.mjs');
    const element=document.createElement('input');element.value='12';document.body.append(element);
    let initialError='',retryError='',retry;
    try{bindInput(element,{kind:'pattern',pattern:'##'},{onChange(){throw new Error('consumer initialization failure');}});}
    catch(error){initialError=error.message;}
    try{retry=bindInput(element,{kind:'pattern',pattern:'##'});retry.setValue('34');}
    catch(error){retryError=error.message;}
    const result={initialError,retryError,value:element.value};
    retry?.destroy();element.remove();return result;
  });
  check('initial callback exceptions release listeners and attachment for rebinding',initialCallback,{initialError:'consumer initialization failure',retryError:'',value:'34'});
  const lockedBlur=await page.evaluate(async()=>{
    const {bindInput}=await import('./adapter.mjs');
    const result=[];
    for(const property of ['readOnly','disabled']){
      const element=document.createElement('input');element.value='12';document.body.append(element);
      let accepted=0;
      const binding=bindInput(element,{kind:'number',precision:2,padFraction:true},{onAccept(){accepted++;}});
      element[property]=true;element.dispatchEvent(new FocusEvent('blur'));
      result.push({property,display:element.value,raw:binding.state.raw,value:binding.state.value,accepted});
      binding.destroy();element.remove();
    }
    return result;
  });
  check('readonly blur preserves uncommitted numeric display',lockedBlur[0],{property:'readOnly',display:'12',raw:'12',value:'12.00',accepted:0});
  check('disabled blur preserves uncommitted numeric display',lockedBlur[1],{property:'disabled',display:'12',raw:'12',value:'12.00',accepted:0});
  const nestedOptions=await page.evaluate(async()=>{
    const {bindInput}=await import('./adapter.mjs');
    const cases=[
      {name:'number',config:{kind:'validate',rule:{kind:'number',precision:3,radix:'.',groupSeparator:','}},initial:'1.234',changed:'2.345',patch:{rule:{kind:'number',precision:3,radix:',',groupSeparator:'.'}}},
      {name:'date',config:{kind:'validate',rule:{kind:'date',format:'DD/MM/YYYY'}},initial:'01022024',changed:'03042024',patch:{rule:{kind:'date',format:'MM/DD/YYYY'}}}
    ];
    return cases.map(item=>{
      const element=document.createElement('input');element.value=item.initial;document.body.append(element);
      let accepted=0;
      const binding=bindInput(element,item.config,{onAccept(){accepted++;}});
      binding.setValue(item.changed);const before=JSON.stringify(binding.state),beforeAccepted=accepted;
      const update=binding.updateOptions(item.patch);
      const preserved=JSON.stringify(binding.state)===before&&accepted===beforeAccepted;
      const undone=binding.undo(),restored=binding.state.value;
      const result={name:item.name,ok:update.ok,preserved,undone,restored};
      binding.destroy();element.remove();return result;
    });
  });
  check('nested numeric rule changes cannot silently reinterpret values or erase history',nestedOptions[0],{name:'number',ok:false,preserved:true,undone:true,restored:'1.234'});
  check('nested date rule changes cannot silently reinterpret values or erase history',nestedOptions[1],{name:'date',ok:false,preserved:true,undone:true,restored:'2024-02-01'});
  const nativeHistory=await page.evaluate(async()=>{
    const {bindInput}=await import('./adapter.mjs');
    const element=document.createElement('input');element.value='1234';document.body.append(element);element.focus();
    const binding=bindInput(element,{kind:'number',precision:2});
    element.setSelectionRange(2,2);
    const event=new InputEvent('beforeinput',{bubbles:true,cancelable:true,inputType:'insertText',data:'9'});
    element.dispatchEvent(event);
    const inserted={prevented:event.defaultPrevented,raw:binding.state.raw,display:element.value,start:element.selectionStart,end:element.selectionEnd};
    element.setSelectionRange(element.value.length,element.value.length);
    const undone=binding.undo(),undo={raw:binding.state.raw,display:element.value,start:element.selectionStart,end:element.selectionEnd};
    const redone=binding.redo(),redo={raw:binding.state.raw,display:element.value,start:element.selectionStart,end:element.selectionEnd};
    binding.destroy();element.remove();return {inserted,undone,undo,redone,redo};
  });
  check('insertion next to generated grouping maps the caret to the raw boundary',nativeHistory.inserted,{prevented:true,raw:'19234',display:'19,234',start:2,end:2});
  check('undo restores pre-edit grouping selection',{ok:nativeHistory.undone,...nativeHistory.undo},{ok:true,raw:'1234',display:'1,234',start:2,end:2});
  check('redo restores the selection captured when undo was requested',{ok:nativeHistory.redone,...nativeHistory.redo},{ok:true,raw:'19234',display:'19,234',start:6,end:6});
  const callbackRecovery=await page.evaluate(async()=>{
    const {bindInput}=await import('./adapter.mjs');
    const element=document.createElement('input');element.value='11';document.body.append(element);
    let throwNext=false;
    const binding=bindInput(element,{kind:'pattern',pattern:'##'},{onChange(){if(throwNext){throwNext=false;throw new Error('consumer update failure');}}});
    throwNext=true;let error='';try{binding.setValue('22');}catch(failure){error=failure.message;}
    const committed={raw:binding.state.raw,display:element.value};
    const undone=binding.undo(),undo=binding.state.raw,redone=binding.redo(),redo=binding.state.raw;
    binding.destroy();const replacement=bindInput(element,{kind:'pattern',pattern:'##'});replacement.destroy();element.remove();
    return {error,committed,undone,undo,redone,redo};
  });
  check('consumer callback failures leave committed data and history recoverable',callbackRecovery,{error:'consumer update failure',committed:{raw:'22',display:'22'},undone:true,undo:'11',redone:true,redo:'22'});
  const failedResets=await page.evaluate(async()=>{
    const {bindInput}=await import('./adapter.mjs');
    const results=[];
    for(const native of [false,true]){
      const form=document.createElement('form'),element=document.createElement('input');
      element.defaultValue='1234';form.append(element);document.body.append(form);
      const errors=[];const binding=bindInput(element,{kind:'pattern',pattern:'##-##'},{onError:error=>errors.push(error.code)});
      binding.setValue('5678');element.focus();element.setSelectionRange(1,4);element.defaultValue='bad';
      if(native){form.reset();await Promise.resolve();}else binding.reset();
      const rejected={raw:binding.state.raw,display:element.value,start:element.selectionStart,end:element.selectionEnd,errors};
      const undone=binding.undo(),undo=binding.state.raw,redone=binding.redo(),redo={raw:binding.state.raw,start:element.selectionStart,end:element.selectionEnd};
      results.push({native,rejected,undone,undo,redone,redo});binding.destroy();form.remove();
    }
    return results;
  });
  for(const item of failedResets){
    check(`${item.native?'native':'explicit'} failed reset preserves selection and history`,item,{native:item.native,rejected:{raw:'5678',display:'56-78',start:1,end:4,errors:['character']},undone:true,undo:'1234',redone:true,redo:{raw:'5678',start:1,end:4}});
  }
  const partitionHistory=await page.evaluate(async()=>{
    const {bindInput}=await import('./adapter.mjs');
    const config={kind:'composite',parts:[{kind:'block',name:'head',rule:{kind:'enum',values:['A','AB']}},{kind:'literal',literal:' '},{kind:'block',name:'tail',rule:{kind:'regex',source:'[A-Z]{1,2}'}}]};
    const element=document.createElement('input');element.value='A BC';document.body.append(element);element.focus();
    const binding=bindInput(element,config);
    binding.setValue('AB C');const repartitioned={raw:binding.state.raw,display:element.value,fields:binding.state.fields};
    const undone=binding.undo(),undo={raw:binding.state.raw,display:element.value,fields:binding.state.fields};
    element.setSelectionRange(2,4);
    const failed=new InputEvent('beforeinput',{bubbles:true,cancelable:true,inputType:'insertText',data:'12'});element.dispatchEvent(failed);
    const afterError={raw:binding.state.raw,display:element.value,start:element.selectionStart,end:element.selectionEnd};
    const redone=binding.redo(),redo={raw:binding.state.raw,display:element.value,fields:binding.state.fields};
    binding.destroy();element.remove();return {repartitioned,undone,undo,afterError,redone,redo};
  });
  check('same raw composite repartition creates a meaningful history entry',partitionHistory.repartitioned,{raw:'ABC',display:'AB C',fields:[{name:'head',value:'AB'},{name:'tail',value:'C'}]});
  check('composite undo restores display partition and fields',{ok:partitionHistory.undone,...partitionHistory.undo},{ok:true,raw:'ABC',display:'A BC',fields:[{name:'head',value:'A'},{name:'tail',value:'BC'}]});
  check('failed composite edits retain explicit partition and selection',partitionHistory.afterError,{raw:'ABC',display:'A BC',start:2,end:4});
  check('failed composite edits retain the redo branch',{ok:partitionHistory.redone,...partitionHistory.redo},{ok:true,raw:'ABC',display:'AB C',fields:[{name:'head',value:'AB'},{name:'tail',value:'C'}]});
  check('lifecycle acceptance cases have no uncaught browser exceptions',exceptions,[]);
  await mkdir(new URL('../dist/',import.meta.url),{recursive:true});
  await writeFile(new URL(`../dist/acceptance-${engine}-results.json`,import.meta.url),JSON.stringify({engine,checks:checks.length,passed:checks,failures},null,2));
  assert.equal(failures.length,0,JSON.stringify(failures,null,2));
  console.log(`${engine} lifecycle acceptance checks passed: ${checks.length}`);
}finally{await browser?.close();await new Promise(resolve=>server.close(resolve));}

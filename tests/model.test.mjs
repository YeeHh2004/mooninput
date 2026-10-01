import test from 'node:test';
import assert from 'node:assert/strict';
import {createEditor} from '../web/adapter.mjs';
function random(seed){return max=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%max;};}
test('12,000 seeded digit edits agree with an independent array model',()=>{
  for(let seed=1;seed<=12;seed++){
    const rand=random(seed),editor=createEditor({kind:'pattern',pattern:'### #### ####'});
    let raw='';
    const fmt=s=>[s.slice(0,3),s.slice(3,7),s.slice(7)].filter(Boolean).join(' ');
    const offset=i=>i+(i>3?1:0)+(i>7?1:0);
    for(let step=0;step<1000;step++){
      const start=rand(raw.length+1),end=start+rand(raw.length-start+1),op=['insert','backspace','delete'][rand(3)];
      const text=rand(10).toString();let expected=raw,caret=start;
      if(op==='insert'){expected=raw.slice(0,start)+text+raw.slice(end);caret=start+1;}
      else if(start!==end)expected=raw.slice(0,start)+raw.slice(end);
      else if(op==='backspace'&&start>0){expected=raw.slice(0,start-1)+raw.slice(start);caret=start-1;}
      else if(op==='delete'&&start<raw.length)expected=raw.slice(0,start)+raw.slice(start+1);
      const result=editor.apply(op,op==='insert'?text:'',offset(start),offset(end));
      if(expected.length>11){assert.equal(result.ok,false);expected=raw;}
      else {assert.equal(result.ok,true);assert.equal(editor.state.start,offset(caret));}
      raw=expected;
      assert.equal(editor.state.raw,raw,`seed=${seed}, step=${step}`);
      assert.equal(editor.state.display,fmt(raw));
      assert.ok(editor.state.start>=0&&editor.state.end<=editor.state.display.length);
    }
  }
});
test('decimal whole-value roundtrips preserve 1,000 exact strings',()=>{
  const rand=random(27),editor=createEditor({kind:'decimal',precision:8,signed:true});
  for(let i=0;i<1000;i++){
    const digits=Array.from({length:1+rand(50)},()=>rand(10)).join('');
    const fraction=Array.from({length:1+rand(8)},()=>rand(10)).join('');
    const raw=(rand(2)?'-':'')+digits+'.'+fraction;
    assert.equal(editor.apply('set',raw).ok,true);
    assert.equal(editor.state.raw,raw);
    const formatted=editor.state.display;
    assert.equal(editor.apply('set',formatted).ok,true);
    assert.equal(editor.state.raw,raw);
    assert.equal(editor.state.value,raw.replace(/^(-?)0+(?=\d)/,'$1'));
  }
});
test('date validity matches an independent leap-year reference for 4,800 dates',()=>{
  const editor=createEditor({kind:'date'});
  for(let year=1800;year<2200;year++)for(let month=1;month<=12;month++){
    const leap=year%4===0&&(year%100!==0||year%400===0);
    const max=month===2?(leap?29:28):[4,6,9,11].includes(month)?30:31;
    const day=month===2?29:31;
    editor.apply('set',`${year}${String(month).padStart(2,'0')}${day}`);
    assert.equal(editor.state.status,day<=max?'complete':'invalid');
  }
});
test('protocol rejects non-integer selection and hostile input shapes',()=>{
  const editor=createEditor({kind:'pattern',pattern:'##'},'12');
  for(const pos of [-1,.5,Infinity,NaN,1e20])assert.equal(editor.apply('insert','3',pos,pos).ok,false);
  assert.equal(editor.state.raw,'12');
});

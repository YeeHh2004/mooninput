import test from 'node:test';
import assert from 'node:assert/strict';
import {createEditor} from '../web/adapter.mjs';
import {process as engine} from '../web/mooninput.mjs';

test('dynamic candidates reroute on insert, delete and snapshot restore',()=>{
  const e=createEditor({kind:'dynamic',masks:[{name:'short',kind:'pattern',pattern:'##-##'},{name:'long',kind:'pattern',pattern:'###-###'}]},'1234');
  assert.equal(e.state.active,'short');const before=e.state;
  assert.equal(e.apply('insert','5').state.active,'long');
  assert.equal(e.state.display,'123-45');
  assert.equal(e.apply('backspace').state.active,'short');
  assert.equal(e.restore(before).state.display,'12-34');
});

test('declarative compositions expose named fields and support edited ranges',()=>{
  const e=createEditor({kind:'composite',parts:[{kind:'block',name:'hour',rule:{kind:'range',from:0,to:23,width:2}},{kind:'literal',literal:':'},{kind:'block',name:'minute',rule:{kind:'range',from:0,to:59,width:2}}]},'2359');
  assert.equal(e.state.display,'23:59');
  assert.deepEqual(e.state.fields,[{name:'hour',value:'23'},{name:'minute',value:'59'}]);
  assert.throws(()=>{e.state.fields[0].value='corrupt';},TypeError);
  assert.throws(()=>e.state.fields.push({name:'x',value:'x'}),TypeError);
  assert.equal(e.state.fields[0].value,'23');
  assert.equal(e.apply('insert','25',0,2).ok,false);
  assert.equal(e.state.raw,'2359');
  assert.equal(e.apply('insert','12',0,2).state.display,'12:59');
});

test('regex and custom definitions admit prefixes and reject impossible input',()=>{
  const e=createEditor({kind:'regex',source:'^[A-Za-z][A-Za-z0-9_]{2,15}$'});
  assert.equal(e.apply('insert','a').state.status,'incomplete');
  assert.equal(e.apply('insert','_b').state.value,'a_b');
  assert.equal(e.apply('insert','!').ok,false);
  const hex=createEditor({kind:'pattern',pattern:'HH:HH',definitions:[{token:'H',characters:'0123456789abcdefABCDEF',uppercase:true}]},'ab12');
  assert.equal(hex.state.display,'AB:12');assert.equal(hex.apply('insert','G',0,1).ok,false);
});

test('repeat, optional composition and validation wrappers are configuration-driven',()=>{
  const e=createEditor({kind:'repeat',rule:{kind:'enum',values:['ON','OFF']},minRepeat:1,maxRepeat:3},'ONOFF');
  assert.equal(e.state.status,'complete');assert.equal(e.state.fields.length,2);
  const v=createEditor({kind:'validate',rule:{kind:'pattern',pattern:'####'},startsWith:'12'},'1399');
  assert.equal(v.state.status,'invalid');
  assert.equal(v.apply('insert','2',1,2).state.value,'1299');
});

test('localized numbers preserve exact canonical strings and bounded dates are editable',()=>{
  const e=createEditor({kind:'number',precision:2,radix:',',groupSeparator:'.',max:'9007199254740994.00'},'9.007.199.254.740.993,10');
  assert.equal(e.state.value,'9007199254740993.10');
  const raw=e.state.raw;assert.equal(createEditor({kind:'number',precision:2,radix:',',groupSeparator:'.'},raw).state.value,e.state.value);
  const d=createEditor({kind:'date',format:'DD/MM/YYYY',min:'2020-01-01',max:'2030-12-31'},'29022023');
  assert.equal(d.state.status,'invalid');assert.equal(d.apply('insert','4',9,10).state.value,'2024-02-29');
});

test('presentation metadata, preparation, overwrite and skipping cross protocol',()=>{
  const e=createEditor({kind:'presentation',rule:{kind:'pattern',pattern:'##-##'},placeholder:'_',concealed:'*'},'12');
  assert.equal(e.state.display,'**-__');assert.equal(e.state.raw,'12');
  const prepared=createEditor({kind:'regex',source:'[A-Z]{2,4}',prepare:'uppercase',overwrite:true},'ab');
  assert.equal(prepared.state.value,'AB');assert.equal(prepared.apply('insert','xy',0).state.raw,'XY');
  const skip=createEditor({kind:'pattern',pattern:'####',skipInvalid:true});
  assert.equal(skip.apply('insert','1a2-34').state.value,'1234');
});

test('option changes are atomic, clear ambiguity and reject invalid schemas',()=>{
  const e=createEditor({kind:'pattern',pattern:'####'},'1234');
  assert.equal(e.updateOptions({pattern:'##-##'}).state.display,'12-34');
  assert.equal(e.updateOptions({pattern:'AA'}).ok,false);assert.equal(e.state.raw,'1234');
  assert.equal(e.updateOptions(null).ok,false);
  const locale=createEditor({kind:'number',radix:',',groupSeparator:'.'},'12,50');
  assert.equal(locale.updateOptions({radix:'.',groupSeparator:','}).ok,false);
  assert.equal(locale.state.value,'12.50');
  let nested={kind:'pattern',pattern:'##'};
  for(let i=0;i<60;i++)nested={kind:'repeat',minRepeat:1,maxRepeat:1,rule:nested};
  assert.throws(()=>createEditor(nested),/nesting/);
  assert.equal(JSON.parse(engine('{"config":'+ '['.repeat(100)+'0'+']'.repeat(100)+'}')).ok,false);
});

test('completion padding is committed after editing without changing magnitude',()=>{
  const e=createEditor({kind:'number',radix:',',groupSeparator:' ',precision:2,padFraction:true,commit:'trim'},'12');
  assert.equal(e.state.display,'12');assert.equal(e.state.value,'12.00');
  assert.equal(e.apply('insert',',5').state.display,'12,5');
  assert.equal(e.apply('commit').state.display,'12,50');
  assert.equal(e.apply('insert','7',3,4).state.value,'12.70');
  assert.equal(createEditor({kind:'pattern',pattern:'####'},'12').apply('commit').ok,false);
  assert.throws(()=>createEditor({kind:'pattern',pattern:'##',commit:'unknown'}),/commit/);
});

test('bounded regex composite agrees with independent finite language and editing model',()=>{
  const config={kind:'composite',parts:[{kind:'block',name:'letters',rule:{kind:'regex',source:'[AB]{2}'}},{kind:'literal',literal:'/'},{kind:'block',name:'digits',rule:{kind:'regex',source:'[12]{2}'}}]};
  const words=[];for(const a of 'AB')for(const b of 'AB')for(const c of '12')for(const d of '12')words.push(a+b+c+d);
  for(const word of words){const e=createEditor(config);for(const c of word)assert.equal(e.apply('insert',c).ok,true);assert.equal(e.state.display,word.slice(0,2)+'/'+word.slice(2));assert.equal(e.state.raw,word);assert.equal(e.state.value,word.slice(0,2)+'/'+word.slice(2));assert.equal(e.apply('backspace').state.status,'incomplete');}
});

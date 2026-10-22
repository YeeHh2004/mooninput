import test from 'node:test';
import assert from 'node:assert/strict';
import {createEditor} from '../web/adapter.mjs';

const partitionConfig={kind:'composite',parts:[
  {kind:'block',name:'head',rule:{kind:'enum',values:['A','AB']}},
  {kind:'literal',literal:' '},
  {kind:'block',name:'tail',rule:{kind:'regex',source:'[A-Z]{1,2}'}}
]};
const fields=(head,tail)=>[{name:'head',value:head},{name:'tail',value:tail}];

test('snapshot restore rejects damaged content or selection without changing the current editor',()=>{
  const editor=createEditor({kind:'number',precision:2},'1234.50');
  editor.apply('select','',2,6);
  const before=editor.state;
  const saved=structuredClone(before);
  const damaged=[
    null,[],{},
    {...saved,raw:1234},
    {...saved,display:1234},
    {...saved,raw:'9999'},
    {...saved,display:'9,999.50'},
    {...saved,start:-1},
    {...saved,start:0,end:99},
    {...saved,start:5,end:2},
    {...saved,start:NaN},
    {...saved,end:Infinity},
    {...saved,start:1.5},
    {...saved,start:'0'}
  ];
  for(const candidate of damaged){
    const result=editor.restore(candidate);
    assert.equal(result.ok,false,JSON.stringify(candidate));
    assert.equal(typeof result.code,'string');
    assert.equal(typeof result.error,'string');
    assert.deepEqual(editor.state,before,'a rejected snapshot must preserve content, metadata and selection');
  }
  assert.equal(editor.apply('insert','9',2,3).ok,true,'the original editor remains usable after rejected snapshots');
});

test('snapshot restore recomputes semantic metadata instead of trusting saved values',()=>{
  const editor=createEditor(partitionConfig,'A BC');
  const saved={...structuredClone(editor.state),start:2,end:4,value:'forged',status:'invalid',active:'forged',fields:[{name:'forged',value:'forged'}]};
  assert.equal(editor.apply('set','A DE').ok,true);
  const result=editor.restore(saved);
  assert.equal(result.ok,true);
  assert.equal(editor.state.value,'A BC');
  assert.equal(editor.state.status,'complete');
  assert.equal(editor.state.active,null);
  assert.deepEqual(editor.state.fields,fields('A','BC'));
  assert.equal(editor.state.start,2);
  assert.equal(editor.state.end,4);
  saved.fields[0].value='changed again';
  assert.deepEqual(editor.state.fields,fields('A','BC'));
});

test('identical raw text retains explicit composite partitions through selection edits errors and restore',()=>{
  const editor=createEditor(partitionConfig,'A BC');
  const rawReplay=createEditor(partitionConfig,editor.state.raw);
  assert.equal(rawReplay.state.display,'AB C','raw text alone has a different valid partition');
  assert.deepEqual(editor.state.fields,fields('A','BC'));
  const selected=editor.apply('select','',2,4);
  assert.equal(selected.ok,true);
  const original=editor.state;
  assert.equal(original.display,'A BC');
  assert.equal(editor.apply('insert','12').ok,false);
  assert.deepEqual(editor.state,original,'a rejected edit must not repartition ambiguous raw text');
  assert.equal(editor.apply('insert','DE').state.display,'A DE');
  assert.deepEqual(editor.state.fields,fields('A','DE'));
  assert.equal(editor.restore(original).state.display,'A BC');
  assert.equal(editor.apply('insert','BC').state.display,'A BC','replacing with the same raw text retains explicit block boundaries');
  assert.equal(editor.apply('set','AB C').state.display,'AB C');
  assert.equal(editor.state.raw,original.raw);
  assert.deepEqual(editor.state.fields,fields('AB','C'));
  assert.equal(editor.restore(original).state.display,'A BC');
  assert.deepEqual(editor.state.fields,fields('A','BC'));
});

test('non JSON option patches return typed errors atomically instead of throwing or changing rules',()=>{
  const editor=createEditor({kind:'pattern',pattern:'####'},'1234');
  editor.apply('select','',1,3);
  const before=editor.state;
  const circular={};circular.self=circular;
  const cases=[
    {pattern:'AA',extra:NaN},
    {pattern:'AA',extra:Infinity},
    {pattern:'AA',extra:-Infinity},
    {pattern:'AA',extra:1n},
    {pattern:'AA',extra:()=>true},
    {pattern:'AA',extra:Symbol('invalid')},
    {pattern:'AA',extra:circular},
    null,[],true,'invalid'
  ];
  for(const patch of cases){
    let result;
    assert.doesNotThrow(()=>{result=editor.updateOptions(patch);});
    assert.equal(result.ok,false);
    assert.equal(result.code,'config');
    assert.equal(typeof result.error,'string');
    assert.deepEqual(editor.state,before,'bad options must not change the current selection or configuration');
  }
  assert.equal(editor.apply('insert','9',1,2).state.value,'1934','a partially valid rejected patch must not install its pattern');
});

test('raw display snapshot roundtrips preserve ambiguous literals concealed input and Unicode offsets',()=>{
  const cases=[
    [{kind:'pattern',pattern:'1X[XX]'},'12',1,3],
    [{kind:'presentation',rule:{kind:'pattern',pattern:'XX[XXX]'},concealed:'*'},'你😀',0,2],
    [{kind:'presentation',rule:{kind:'pattern',pattern:'##-##'},placeholder:'_'},'',3,3],
    [{kind:'number',precision:2,radix:',',groupSeparator:' ',padFraction:true},'1234,5',3,5]
  ];
  for(const [config,value,start,end] of cases){
    const editor=createEditor(config,value);
    assert.equal(editor.apply('select','',start,end).ok,true);
    const saved=editor.state;
    assert.equal(editor.apply('set','').ok,true);
    assert.equal(editor.restore(saved).ok,true);
    assert.deepEqual(editor.state,saved);
    const replay=createEditor(config);
    assert.equal(replay.restore(saved).ok,true);
    assert.deepEqual(replay.state,saved);
  }
});

test('external configuration mutation cannot change nested dynamic or composite rules',()=>{
  const config=structuredClone(partitionConfig);
  const editor=createEditor(config,'A BC');
  config.parts[0].rule.values[0]='X';config.parts[1].literal='!';
  config.parts[2].rule.source='[0-9]';
  assert.equal(editor.apply('select','',2,4).state.display,'A BC');
  assert.equal(editor.apply('insert','DE').state.value,'A DE');
  assert.deepEqual(editor.state.fields,fields('A','DE'));
});

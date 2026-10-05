import test from 'node:test';
import assert from 'node:assert/strict';
import {createEditor} from '../web/adapter.mjs';
import {process as processInput} from '../web/mooninput.mjs';
test('public protocol supports editing and preserves error snapshot',()=>{
  const editor=createEditor({kind:'pattern',pattern:'### ### ####'},'123456');
  assert.equal(editor.state.display,'123 456');
  assert.equal(editor.apply('insert','9',2,2).state.raw,'1293456');
  assert.equal(editor.apply('insert','x',2,2).ok,false);
  assert.equal(editor.state.raw,'1293456');
});
test('date validation is semantic and recoverable',()=>{
  const editor=createEditor({kind:'date'},'20230229');
  assert.equal(editor.state.status,'invalid');
  assert.equal(editor.state.value,null);
  assert.equal(editor.apply('insert','4',3,4).state.value,'2024-02-29');
});
test('configuration errors and malformed protocol are explicit',()=>{
  assert.throws(()=>createEditor({kind:'other'}),/unknown mask kind/);
  for(const input of ['{','null','[]','{}','x'.repeat(65537)]){
    assert.equal(JSON.parse(processInput(input)).ok,false);
  }
});
test('exact decimal strings cross JS boundary without precision loss',()=>{
  const editor=createEditor({kind:'decimal',precision:4},'9007199254740993.1200');
  assert.equal(editor.state.value,'9007199254740993.1200');
  assert.equal(editor.apply('insert','1',editor.state.end).ok,false);
});
test('snapshots are isolated and restorations preserve caret',()=>{
  const editor=createEditor({kind:'pattern',pattern:'####'},'12');
  const snapshot=editor.state;
  assert.throws(()=>{snapshot.raw='x';},TypeError);
  editor.apply('insert','3',2);
  editor.restore(snapshot);
  assert.equal(editor.state.raw,'12');
  assert.equal(editor.state.start,2);
});

test('implicit edits preserve the selected range; explicit start collapses it',()=>{
  const editor=createEditor({kind:'pattern',pattern:'####'},'1234');
  editor.apply('select','',1,3);
  assert.equal(editor.apply('insert','9').state.raw,'194');
  editor.apply('select','',0,2);
  assert.equal(editor.apply('insert','8',3).state.raw,'1948');
  editor.apply('select','',1,3);
  assert.equal(editor.apply('backspace').state.raw,'18');
});

test('unchanged ambiguous display survives composition reconciliation',()=>{
  const editor=createEditor({kind:'pattern',pattern:'1####'},'23');
  for(let i=0;i<10;i++)assert.equal(editor.apply('reconcile','123',2,2).state.raw,'23');
  assert.equal(editor.state.start,2);
});

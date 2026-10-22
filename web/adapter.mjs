import {process as processInput} from './mooninput.mjs';
const attached=new WeakSet();
const changed=(a,b)=>['raw','display','value','status','reason','active'].some(key=>a[key]!==b[key])||JSON.stringify(a.fields)!==JSON.stringify(b.fields);
function serialize(value){return JSON.stringify(value,(_key,item)=>{
  if(typeof item==='bigint'||typeof item==='function'||typeof item==='symbol'||(typeof item==='number'&&!Number.isFinite(item)))throw new TypeError('Configuration and requests must contain finite JSON data');
  return item;
});}
function semanticRule(config){
  const pending=[config];
  while(pending.length){const rule=pending.pop();if(!rule||typeof rule!=='object')continue;
    if(['number','decimal','date'].includes(rule.kind))return true;
    if(rule.rule)pending.push(rule.rule);
    for(const key of ['masks','parts'])if(Array.isArray(rule[key]))pending.push(...rule[key]);
  }
  return false;
}

// This file transports events and selections. All value rules are in MoonBit.
export function createEditor(config, initial = '') {
  let settings = Object.freeze(structuredClone(config));
  let state;
  function request(op, text='', start=state?.start??0, end=state?.end??start, value=state?.raw??initial, display=state?.display) {
    try{return JSON.parse(processInput(serialize({config:settings,value,display,op,start,end,text})));}
    catch(error){return {ok:false,code:'config',error:error.message};}
  }
  const first=request('init');
  if (!first.ok) throw new TypeError(first.error);
  state=first.state;
  function snapshot(){
    const copy=structuredClone(state);
    copy.fields=Object.freeze((copy.fields??[]).map(field=>Object.freeze(field)));
    return Object.freeze(copy);
  }
  return {
    get state(){return snapshot();},
    apply(op,text='',start,end){
      const from=start??state.start;
      const to=end??(start==null?state.end:from);
      const result=request(op,text,from,to);
      if (result.state) state=result.state;
      return structuredClone(result);
    },
    restore(saved){
      if(!saved||typeof saved!=='object'||typeof saved.raw!=='string'||(saved.display!==undefined&&typeof saved.display!=='string')||!Number.isInteger(saved.start)||!Number.isInteger(saved.end))return {ok:false,code:'config',error:'Invalid editor snapshot'};
      const init=request('init','',0,0,saved.raw,saved.display??null);
      if (!init.ok) return init;
      const result=request('select','',saved.start,saved.end,init.state.raw,init.state.display);
      if (result.ok) state=result.state;
      return structuredClone(result);
    },
    updateOptions(patch){
      if(!patch||typeof patch!=='object'||Array.isArray(patch))return {ok:false,code:'config',error:'Options must be an object',state:snapshot()};
      let next,result;
      try{
        next=Object.freeze(structuredClone({...settings,...patch}));
        result=JSON.parse(processInput(serialize({config:next,value:state.raw,op:'init',start:0,end:0,text:''})));
      }catch(error){return {ok:false,code:'config',error:error.message,state:snapshot()};}
      if(result.ok&&state.status==='complete'&&(semanticRule(settings)||semanticRule(next))&&result.state.value!==state.value){
        return {ok:false,code:'value',error:'These options reinterpret the current value. Clear or explicitly convert it before changing the format.',state:snapshot()};
      }
      if(result.ok){settings=next;state=result.state;}
      return structuredClone(result);
    }
  };
}

export function bindInput(element, config, {onChange=()=>{},onAccept=()=>{},onComplete=()=>{},onError=()=>{},historyLimit=100}={}) {
  if (!element || element.tagName!=='INPUT' || !['text','tel','search','password','url'].includes(element.type)) {
    throw new TypeError('bindInput requires a text-like input with selection APIs');
  }
  if (!Number.isInteger(historyLimit)||historyLimit<1||historyLimit>1000) throw new RangeError('historyLimit must be 1..1000');
  if(attached.has(element))throw new Error('Destroy the previous binding before rebinding this input');
  const editor=createEditor(config,element.value);
  const original={value:element.value,start:element.selectionStart,end:element.selectionEnd,aria:element.getAttribute('aria-invalid')};
  attached.add(element);
  const listeners=[];
  let composing=false, disposed=false;
  let past=[], future=[];
  let rendered;
  const readSelection=()=>({start:element.selectionStart??0,end:element.selectionEnd??0});
  const editable=()=>!disposed&&!element.disabled&&!element.readOnly;
  function render(focus=false){
    const state=editor.state;
    element.value=state.display;
    if (focus || element.ownerDocument.activeElement===element) element.setSelectionRange(state.start,state.end);
    element.setAttribute('aria-invalid',String(state.status==='invalid'));
    const previous=rendered;rendered=state;
    onChange(state);
    if(previous&&changed(previous,state))onAccept(state);
    if(previous&&state.status==='complete'&&(previous.status!=='complete'||previous.value!==state.value))onComplete(state);
  }
  function transition(op,text='',selection=readSelection()) {
    if (disposed) throw new Error('binding has been destroyed');
    const before=op==='reconcile'?editor.state:currentSnapshot();
    const result=editor.apply(op,text,selection.start,selection.end);
    if(!result.ok&&op==='set'){editor.restore(before);result.state=editor.state;}
    if (result.ok && changed(before,editor.state)) {
      past.push(before); if(past.length>historyLimit)past.shift(); future=[];
    }
    render();
    if (!result.ok) onError({code:result.code,message:result.error});
    return result;
  }
  function currentSnapshot(){
    const saved=editor.state,selection=readSelection();
    return selection.start>=0&&selection.end>=selection.start&&selection.end<=saved.display.length?{...saved,...selection}:saved;
  }
  function moveHistory(source,destination){
    if(disposed)throw new Error('binding has been destroyed');
    if(!source.length)return false;
    const current=currentSnapshot(),result=editor.restore(source[source.length-1]);
    if(!result.ok){onError({code:result.code,message:result.error});return false;}
    source.pop();destination.push(current);render();return true;
  }
  function undo(){
    return moveHistory(past,future);
  }
  function redo(){
    return moveHistory(future,past);
  }
  function resetTo(value,before){
    if(disposed)throw new Error('binding has been destroyed');
    composing=false;
    const result=editor.apply('set',value,0,0);
    if(result.ok){past=[];future=[];}
    else{editor.restore(before);result.state=editor.state;}
    render();
    if(!result.ok)onError({code:result.code,message:result.error});
    return result;
  }
  function reset(value=element.defaultValue){return resetTo(value,currentSnapshot());}
  function listen(name,fn,target=element,capture=false){target.addEventListener(name,fn,capture);listeners.push([target,name,fn,capture]);}
  function destroy(){if(disposed)return;disposed=true;attached.delete(element);for(const [target,name,fn,capture]of listeners)target.removeEventListener(name,fn,capture);past=[];future=[];}
  try{
  // Reset is cancelable and fires before the browser restores default values.
  // Document capture also covers controls associated through the form attribute.
  listen('reset',event=>{
    if(event.target!==element.form)return;
    // Capture selection before the browser replaces value and collapses the
    // native caret. An invalid default must restore the pre-reset selection.
    const before=currentSnapshot();
    queueMicrotask(()=>{if(!disposed&&!event.defaultPrevented)resetTo(element.defaultValue,before);});
  },element.ownerDocument,true);
  listen('beforeinput',event=>{
    if(!editable()||composing||event.isComposing||!event.cancelable)return;
    const type=event.inputType;
    if(type==='historyUndo'||type==='historyRedo'){
      event.preventDefault(); type==='historyUndo'?undo():redo(); return;
    }
    let op,text='';
    if(type==='deleteContentBackward')op='backspace';
    else if(type==='deleteContentForward')op='delete';
    else if(type==='deleteByCut')op='insert';
    else if(['insertText','insertReplacementText','insertFromPaste','insertFromDrop'].includes(type)){
      const data=event.data??event.dataTransfer?.getData('text/plain');
      if(data==null)return;
      op='insert';text=data;
    } else return; // Unintercepted native edits are normalized by the input listener.
    event.preventDefault();transition(op,text);
  });
  listen('paste',event=>{
    if(!editable()||composing||!event.clipboardData)return;
    event.preventDefault(); transition('insert',event.clipboardData.getData('text/plain'));
  });
  listen('input',event=>{
    if(!editable()||composing||event.isComposing)return;
    if(element.value===editor.state.display)return;
    transition('reconcile',element.value);
  });
  listen('compositionstart',()=>{if(editable())composing=true;});
  listen('compositionend',()=>{
    if(!composing)return;
    composing=false;
    if(editable())transition('reconcile',element.value);
  });
  listen('blur',()=>{if(editable()&&!composing&&editor.state.status==='complete')transition('commit');});
  listen('keydown',event=>{
    if(!editable()||composing||event.isComposing||event.altKey||!(event.ctrlKey||event.metaKey))return;
    const key=event.key.toLowerCase();
    if(key==='z'||key==='y'){
      event.preventDefault(); if(key==='y'||event.shiftKey)redo();else undo();
    }
  });
  render();
  }catch(error){
    destroy();element.value=original.value;
    if(original.start!==null&&original.end!==null)element.setSelectionRange(original.start,original.end);
    if(original.aria===null)element.removeAttribute('aria-invalid');else element.setAttribute('aria-invalid',original.aria);
    throw error;
  }
  return {
    get state(){return editor.state;},
    setValue(value){return transition('set',value,{start:0,end:0});},
    commit(){return transition('commit');},
    updateOptions(patch){
      if(disposed)throw new Error('binding has been destroyed');
      const result=editor.updateOptions(patch);
      if(result.ok){past=[];future=[];}
      render();if(!result.ok)onError({code:result.code,message:result.error});return result;
    },
    reset,undo,redo,
    destroy
  };
}

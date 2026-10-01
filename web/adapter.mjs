import {process as processInput} from './mooninput.mjs';

// This file transports events and selections. All value rules are in MoonBit.
export function createEditor(config, initial = '') {
  const settings = Object.freeze(structuredClone(config));
  let state;
  function request(op, text='', start=state?.start??0, end=state?.end??start, value=state?.raw??initial) {
    return JSON.parse(processInput(JSON.stringify({config:settings,value,op,start,end,text})));
  }
  const first=request('init');
  if (!first.ok) throw new TypeError(first.error);
  state=first.state;
  return {
    get state(){return Object.freeze({...state});},
    apply(op,text='',start=state.start,end=start){
      const result=request(op,text,start,end);
      if (result.state) state=result.state;
      return structuredClone(result);
    },
    restore(snapshot){
      const init=request('init','',0,0,snapshot.raw);
      if (!init.ok) return init;
      const result=request('select','',snapshot.start,snapshot.end,init.state.raw);
      if (result.ok) state=result.state;
      return structuredClone(result);
    }
  };
}

export function bindInput(element, config, {onChange=()=>{},onError=()=>{},historyLimit=100}={}) {
  if (!element || element.tagName!=='INPUT' || !['text','tel','search','password','url'].includes(element.type)) {
    throw new TypeError('bindInput requires a text-like input with selection APIs');
  }
  if (!Number.isInteger(historyLimit)||historyLimit<1||historyLimit>1000) throw new RangeError('historyLimit must be 1..1000');
  const editor=createEditor(config,element.value);
  const listeners=[];
  let composing=false, disposed=false;
  let past=[], future=[];
  const readSelection=()=>({start:element.selectionStart??0,end:element.selectionEnd??0});
  const editable=()=>!disposed&&!element.disabled&&!element.readOnly;
  function render(focus=false){
    const state=editor.state;
    element.value=state.display;
    if (focus || element.ownerDocument.activeElement===element) element.setSelectionRange(state.start,state.end);
    element.setAttribute('aria-invalid',String(state.status==='invalid'));
    onChange(state);
  }
  function transition(op,text='',selection=readSelection()) {
    if (disposed) throw new Error('binding has been destroyed');
    const before={...editor.state,...selection};
    const result=editor.apply(op,text,selection.start,selection.end);
    if (result.ok && (before.raw!==editor.state.raw)) {
      past.push(before); if(past.length>historyLimit)past.shift(); future=[];
    }
    render();
    if (!result.ok) onError({code:result.code,message:result.error});
    return result;
  }
  function undo(){
    if(disposed)throw new Error('binding has been destroyed');
    if(!past.length)return false;
    future.push(editor.state); editor.restore(past.pop()); render(); return true;
  }
  function redo(){
    if(disposed)throw new Error('binding has been destroyed');
    if(!future.length)return false;
    past.push(editor.state); editor.restore(future.pop()); render(); return true;
  }
  function listen(name,fn){element.addEventListener(name,fn);listeners.push([name,fn]);}
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
  listen('keydown',event=>{
    if(!editable()||composing||event.isComposing||event.altKey||!(event.ctrlKey||event.metaKey))return;
    const key=event.key.toLowerCase();
    if(key==='z'||key==='y'){
      event.preventDefault(); if(key==='y'||event.shiftKey)redo();else undo();
    }
  });
  render();
  return {
    get state(){return editor.state;},
    setValue(value){return transition('set',value,{start:0,end:0});},
    undo,redo,
    destroy(){if(disposed)return; disposed=true;for(const [name,fn]of listeners)element.removeEventListener(name,fn);past=[];future=[];}
  };
}

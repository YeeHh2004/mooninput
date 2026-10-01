#!/usr/bin/env node
import {readFileSync,statSync} from 'node:fs';
import {createEditor} from '../web/adapter.mjs';
function output(value){process.stdout.write(JSON.stringify(value,null,2)+'\n');}
try{
  const args=process.argv.slice(2);
  if(args.length===0||args[0]==='--help'){
    console.log('MoonInput\n  node cli/mooninput.mjs --replay examples/events.json\n  node cli/mooninput.mjs --date 2026-10-02\n  node cli/mooninput.mjs --decimal 1234.50\n  node cli/mooninput.mjs --pattern "AA-####" ab1234');
  }else if(args[0]==='--replay'&&args.length===2){
    if(statSync(args[1]).size>1048576)throw new Error('Replay file exceeds 1 MiB');
    const input=JSON.parse(readFileSync(args[1],'utf8'));
    if(!input||!Array.isArray(input.steps)||input.steps.length>10000||typeof(input.value??'')!=='string')throw new Error('Expected config, optional string value and at most 10000 steps');
    const editor=createEditor(input.config,input.value??'');
    const trace=[];let ok=true;
    for(const [i,step]of input.steps.entries()){
      if(!step||!['set','insert','select','backspace','delete','reconcile'].includes(step.op)||typeof(step.text??'')!=='string')throw new Error(`Invalid step ${i}`);
      const start=step.start??editor.state.start,end=step.end??(step.start??editor.state.end);
      const result=editor.apply(step.op,step.text??'',start,end);
      trace.push({index:i,...result});if(!result.ok)ok=false;
    }
    output({ok,state:editor.state,trace});if(!ok)process.exitCode=1;
  }else{
    let config,value;
    if(args[0]==='--date'&&args.length===2){config={kind:'date'};value=args[1];}
    else if(args[0]==='--decimal'&&args.length===2){config={kind:'decimal',signed:true};value=args[1];}
    else if(args[0]==='--pattern'&&args.length===3){config={kind:'pattern',pattern:args[1]};value=args[2];}
    else throw new Error('Unknown arguments; use --help');
    const editor=createEditor(config,value);output(editor.state);if(editor.state.status!=='complete')process.exitCode=1;
  }
}catch(error){output({ok:false,error:error.message});process.exitCode=2;}

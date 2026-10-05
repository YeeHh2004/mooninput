import {bindInput,createEditor} from './adapter.mjs';
const $=id=>document.getElementById(id);
const bindings=new Map();
const statusText={empty:'等待输入',incomplete:'尚未填完',complete:'可以提交',invalid:'请检查日期'};
const errorText={character:'这个位置不接受该字符。',length:'已超过允许的长度。',value:'小数精度或分组格式不符合规则。',selection:'选区已变化，请重新选择。',config:'请检查规则配置。',pattern:'请检查格式规则。'};
function setup(id,config){
  const binding=bindInput($(id),config,{
    onChange(state){
      $(id+'-status').textContent=statusText[state.status];
      $(id+'-status').className='status '+state.status;
      $(id+'-error').textContent=state.status==='invalid'?'这个日期不存在，请继续修改。':'';
      const output=$(id+'-value');if(output)output.textContent=(id==='playground'?state.raw:state.value)??'—';
    },
    onError(error){$(id+'-error').textContent=errorText[error.code]??error.message;}
  });
  bindings.set(id,binding);return binding;
}
setup('phone',{kind:'pattern',pattern:'### #### ####'});
setup('amount',{kind:'decimal',precision:2,signed:true});
setup('date',{kind:'date'});
setup('code',{kind:'pattern',pattern:'AA-####[/**]'});
setup('playground',{kind:'pattern',pattern:$('pattern').value});
for(const button of document.querySelectorAll('[data-fill]'))button.addEventListener('click',()=>{
  const key=button.dataset.fill;
  if(key==='phone')bindings.get('phone').setValue('13800138000');
  if(key==='amount')bindings.get('amount').setValue('9007199254740993.10');
  if(key==='invalid-date')bindings.get('date').setValue('20230229');
});
for(const [form,ids,resultId] of [['contact-form',['phone'],'contact-result'],['pricing-form',['amount'],'pricing-result'],['booking-form',['date','code'],'booking-result']]){
  $(form).addEventListener('reset',event=>queueMicrotask(()=>{if(!event.defaultPrevented)$(resultId).hidden=true;}));
  $(form).addEventListener('submit',event=>{
    event.preventDefault();const result=$(resultId);result.hidden=false;
    const invalid=ids.find(id=>bindings.get(id).state.status!=='complete');
    if(invalid){result.textContent='请先完成有效输入，再预览提交。';$(invalid).focus();return;}
    result.textContent=JSON.stringify(Object.fromEntries(ids.map(id=>[id,bindings.get(id).state.value])),null,2);
  });
}
$('apply-pattern').addEventListener('click',()=>{
  const config={kind:'pattern',pattern:$('pattern').value};
  try{createEditor(config);}catch(error){$('pattern-error').textContent=error.message;return;}
  bindings.get('playground').destroy();$('playground').value='';setup('playground',config);$('pattern-error').textContent='';$('playground').focus();
});
$('copy-install').addEventListener('click',async()=>{
  try{await navigator.clipboard.writeText('moon add YeeHh2004/mooninput');$('copy-install').textContent='已复制';}catch{$('copy-install').textContent='请选中复制';}
});
document.documentElement.dataset.ready='true';

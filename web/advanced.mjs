import {bindInput,createEditor} from './adapter.mjs';

const presets={
  dynamic:{label:'动态 · 短编码 / 长编码',config:{kind:'dynamic',masks:[{name:'short',kind:'pattern',pattern:'##-##'},{name:'long',kind:'pattern',pattern:'###-###'}]}},
  regex:{label:'正则 · 可编辑的用户名',config:{kind:'regex',source:'[A-Za-z][A-Za-z0-9_]{2,15}'}},
  time:{label:'组合 · 小时与分钟',config:{kind:'composite',parts:[{kind:'block',name:'hour',rule:{kind:'range',from:0,to:23,width:2}},{kind:'literal',literal:':'},{kind:'block',name:'minute',rule:{kind:'range',from:0,to:59,width:2}}]}},
  hex:{label:'自定义字符 · 十六进制',config:{kind:'pattern',pattern:'HH:HH:HH',definitions:[{token:'H',characters:'0123456789abcdefABCDEF',uppercase:true}]}},
  number:{label:'数值 · 小数逗号与精确范围',config:{kind:'number',precision:2,signed:true,radix:',',groupSeparator:'.',min:'-10000.00',max:'10000.00'}},
  date:{label:'日期 · 日 / 月 / 年',config:{kind:'date',format:'DD/MM/YYYY',min:'2024-01-01',max:'2030-12-31'}},
  repeat:{label:'重复 · 1–4 个双字符区块',config:{kind:'repeat',rule:{kind:'pattern',pattern:'**'},minRepeat:1,maxRepeat:4}},
  enum:{label:'枚举 · 配送方式',config:{kind:'enum',values:['STANDARD','EXPRESS','PICKUP'],caseSensitive:false}},
  validate:{label:'校验 · AB 开头的标识',config:{kind:'validate',rule:{kind:'regex',source:'[A-Z][A-Z0-9]{2,15}'},startsWith:'AB',minLength:3,maxLength:16}},
  presentation:{label:'显示 · 占位与字符隐藏',config:{kind:'presentation',rule:{kind:'pattern',pattern:'##-##'},placeholder:'_',concealed:'●'}}
};
const statusLabels={empty:'等待输入',incomplete:'还可以继续输入',complete:'完整有效',invalid:'需要修改'};
const $=id=>document.getElementById(id);
const cardDefinitions=[
  {key:'dynamic',number:'01',tag:'动态选择',title:'一个字段，多种规格',description:'四位与六位标识随内容切换。增加或删除字符，查看当前选择的规则。',label:'多规格标识',hint:'输入 1234，再输入 5；删除后会重新选择短规则。',example:'123456',button:'试填六位编码',inputmode:'numeric'},
  {key:'regex',number:'02',tag:'正则与中间状态',title:'输入途中，也有章法',description:'字母开头，后续字母、数字或下划线；长度为 3–16 个字符。',label:'用户名示例',hint:'先输入 A，此时尚未完成；继续输入便可成为有效值。',example:'Alice_7',button:'试填用户名',inputmode:'text'},
  {key:'time',number:'03',tag:'命名区块组合',title:'组合规则，读出字段',description:'小时和分钟各自使用范围规则，以冒号组合，并分别返回字段值。',label:'时间参数',hint:'小时 00–23，分钟 00–59；例如输入 0930。',example:'0930',button:'试填 09:30',inputmode:'numeric'},
  {key:'hex',number:'04',tag:'自定义字符定义',title:'字符规则，由你扩展',description:'用自定义 H 表示十六进制字符，复用格式、粘贴与选区编辑。',label:'十六进制编码',hint:'允许 0–9、a–f；字母显示为大写。这里是三段编码示例。',example:'a1b2c3',button:'试填十六进制',inputmode:'text'},
  {key:'number',number:'05',tag:'精确小数与范围',title:'格式随配置，精度保留',description:'小数点使用逗号，千位用点分组。完整值仍以精确十进制字符串返回。',label:'带范围的测量值',hint:'允许 −10000.00 到 10000.00，最多两位小数；例如 1234,50。',example:'1234,50',button:'试填 1.234,50',inputmode:'decimal'},
  {key:'date',number:'06',tag:'日期格式与边界',title:'显示习惯，可独立配置',description:'以日／月／年输入，输出 ISO 日期；同时检查公历与日期范围。',label:'日历日期',hint:'范围 2024–2030；试试 29/02/2024 和 29/02/2025。',example:'29022024',button:'试填闰日',inputmode:'numeric'}
];

function markup(){
  return `<section id="adv-examples" class="advanced" aria-labelledby="adv-title">
    <div class="adv-heading"><div><p class="eyebrow">COMPOSE RULES, EXPAND POSSIBILITIES</p><h2 id="adv-title">规则可以组合，能力可以扩展</h2></div><p>动态选择、自定义规则和命名区块使用同一个引擎。<br>这里的每个输入框都可以编辑、粘贴与撤销。</p></div>
    <div class="adv-grid">${cardDefinitions.map(card=>`<article class="adv-card" aria-labelledby="adv-${card.key}-title">
      <div class="adv-card-top"><span>${card.number}</span><span>${card.tag}</span></div>
      <h3 id="adv-${card.key}-title">${card.title}</h3><p class="adv-description">${card.description}</p>
      <label for="adv-${card.key}">${card.label}</label><input id="adv-${card.key}" type="text" inputmode="${card.inputmode}" autocomplete="off" spellcheck="false" aria-describedby="adv-${card.key}-hint adv-${card.key}-error">
      <p id="adv-${card.key}-hint" class="adv-hint">${card.hint}</p><div class="adv-feedback"><span id="adv-${card.key}-status" class="adv-status" role="status"></span><span id="adv-${card.key}-error" class="adv-error" role="status"></span></div>
      <dl class="adv-values"><div><dt>提交值</dt><dd><output id="adv-${card.key}-value">—</output></dd></div>${card.key==='dynamic'?'<div><dt>当前规则</dt><dd><output id="adv-dynamic-active">—</output></dd></div>':''}${card.key==='time'?'<div><dt>命名字段</dt><dd><output id="adv-time-fields">—</output></dd></div>':''}</dl>
      <div class="adv-card-actions"><button type="button" class="button secondary" data-adv-fill="${card.key}">${card.button}</button><details><summary>查看配置</summary><pre>${JSON.stringify(presets[card.key].config,null,2)}</pre></details></div>
    </article>`).join('')}</div>
    <section class="adv-workbench" aria-labelledby="adv-config-title">
      <div class="adv-workbench-intro"><p class="eyebrow">YOUR CONFIGURATION, THE SAME CORE</p><h3 id="adv-config-title">用一份配置，构建你的输入规则</h3><p>选择预设或直接修改 JSON，再应用到测试输入。可以嵌套动态、组合、重复和校验规则。</p><p class="adv-workbench-note">应用成功后清空测试值；配置有误时保留原来的输入和规则。字符隐藏仅改变显示，原始值仍可由应用读取。</p></div>
      <div class="adv-workbench-grid"><div class="adv-config-editor"><label for="adv-preset">选择起点</label><select id="adv-preset">${Object.entries(presets).map(([key,preset])=>`<option value="${key}">${preset.label}</option>`).join('')}</select><label for="adv-config">规则配置 · JSON</label><textarea id="adv-config" spellcheck="false" aria-describedby="adv-config-error"></textarea><div class="adv-config-actions"><button id="adv-apply" class="button primary" type="button">应用规则</button><span id="adv-config-status" role="status"></span></div><p id="adv-config-error" class="adv-error" role="alert"></p></div>
      <div class="adv-config-preview"><label for="adv-config-input">测试输入</label><input id="adv-config-input" type="text" autocomplete="off" spellcheck="false" aria-describedby="adv-config-input-error"><div class="adv-feedback"><span id="adv-config-input-status" class="adv-status" role="status"></span><span id="adv-config-input-error" class="adv-error" role="status"></span></div><div class="adv-preview-actions"><button id="adv-clear" class="button secondary" type="button">清空输入</button><button id="adv-undo" class="button secondary" type="button">撤销</button><button id="adv-redo" class="button secondary" type="button">重做</button></div><p class="adv-state-label">引擎返回的状态</p><pre id="adv-state" tabindex="0" aria-label="测试输入的引擎状态"></pre><a class="adv-doc-link" href="https://github.com/YeeHh2004/mooninput/blob/main/docs/IMASK-COVERAGE.md">查看能力范围与行为差异 ↗</a></div></div>
    </section>
  </section>`;
}

function connect(id,config,onState=()=>{}){
  return bindInput($(id),config,{
    onChange(state){
      const status=$(id+'-status');status.textContent=statusLabels[state.status]??state.status;status.dataset.state=state.status;
      $(id+'-error').textContent=state.status==='invalid'?(state.reason||'当前值不符合规则，请继续修改。'):'';
      const value=$(id+'-value');if(value)value.textContent=state.value??'—';
      onState(state);
    },
    onError(error){$(id+'-error').textContent=error.message;}
  });
}

export function mountAdvanced(){
  if($('adv-examples'))return;
  const anchor=document.querySelector('.workbench');
  if(!anchor)throw new Error('Advanced examples require the workbench anchor');
  anchor.insertAdjacentHTML('beforebegin',markup());
  const bindings=new Map();
  for(const card of cardDefinitions){
    bindings.set(card.key,connect('adv-'+card.key,presets[card.key].config,state=>{
      if(card.key==='dynamic')$('adv-dynamic-active').textContent=state.active??'—';
      if(card.key==='time')$('adv-time-fields').textContent=state.fields?.length?state.fields.map(field=>`${field.name}=${field.value}`).join(' · '):'—';
    }));
  }
  for(const button of document.querySelectorAll('[data-adv-fill]')){
    button.addEventListener('click',()=>{
      const card=cardDefinitions.find(candidate=>candidate.key===button.dataset.advFill);
      bindings.get(card.key).setValue(card.example);
    });
  }
  let preview=connect('adv-config-input',presets.dynamic.config,state=>{$('adv-state').textContent=JSON.stringify(state,null,2);});
  function loadPreset(){
    $('adv-config').value=JSON.stringify(presets[$('adv-preset').value].config,null,2);
    $('adv-config-error').textContent='';$('adv-config').removeAttribute('aria-invalid');
    $('adv-config-status').textContent='已载入配置，点击应用';
  }
  $('adv-preset').addEventListener('change',loadPreset);
  $('adv-apply').addEventListener('click',()=>{
    try{
      const config=JSON.parse($('adv-config').value);
      // Validate through MoonBit before replacing a working binding.
      createEditor(config);
      preview.destroy();$('adv-config-input').value='';
      preview=connect('adv-config-input',config,state=>{$('adv-state').textContent=JSON.stringify(state,null,2);});
      $('adv-config-error').textContent='';$('adv-config').removeAttribute('aria-invalid');
      $('adv-config-status').textContent='规则已应用';
    }catch(error){
      $('adv-config-error').textContent='配置未应用：'+error.message;
      $('adv-config').setAttribute('aria-invalid','true');$('adv-config-status').textContent='继续使用原规则';
    }
  });
  $('adv-clear').addEventListener('click',()=>preview.setValue(''));
  $('adv-undo').addEventListener('click',()=>preview.undo());
  $('adv-redo').addEventListener('click',()=>preview.redo());
  loadPreset();$('adv-config-status').textContent='动态规则已应用';
  document.documentElement.dataset.advancedReady='true';
}

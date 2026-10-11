// Run against failed_attempt_browser_fixture.dart and isolated Chromium only.
// Defaults: fixture localhost:8875, CDP localhost:9335. No live accounts.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
const debuggerOrigin = process.env.G29_CDP_ORIGIN ?? 'http://127.0.0.1:9335';
const fixtureOrigin = process.env.G29_FIXTURE_ORIGIN ?? 'http://127.0.0.1:8875';
const artifacts = process.env.G29_ARTIFACTS ?? 'build/g29-evidence';
await mkdir(artifacts, { recursive: true });
const page = await (await fetch(`${debuggerOrigin}/json/new?about:blank`, {method:'PUT'})).json();
const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(resolve => socket.addEventListener('open',resolve,{once:true}));
let sequence = 0, apiRequests = 0, credentialRequests = 0;
const pending = new Map(), errors = [], results = [];
socket.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const call = pending.get(message.id); pending.delete(message.id);
    if (message.error) call?.reject(new Error(message.error.message));
    else call?.resolve(message.result);
  }
  if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails.text);
  if (message.method === 'Network.requestWillBeSent') {
    const request = message.params.request;
    if (request.url.startsWith('https://api.example.test')) apiRequests++;
    if (Object.keys(request.headers).some(key => key.toLowerCase() === 'authorization')) credentialRequests++;
  }
});
const send = (method,params={}) => new Promise((resolve,reject) => {
  const id = ++sequence; pending.set(id,{resolve,reject}); socket.send(JSON.stringify({id,method,params}));
});
const delay = ms => new Promise(resolve => setTimeout(resolve,ms));
async function evaluate(expression) {
  const result = await send('Runtime.evaluate',{expression,returnByValue:true});
  assert.equal(result.exceptionDetails,undefined,expression); return result.result.value;
}
async function text() { return evaluate('document.body?.textContent ?? \"\"'); }
async function wheel(deltaY) {
  const width=await evaluate('innerWidth');
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:width/2,y:600,deltaX:0,deltaY});
  await delay(150);
}
async function waitText(value) {
  for (let i=0;i<60;i++) {
    if ((await text()).includes(value)) return;
    if (i>12 && i%3===0) await wheel(400);
    await delay(150);
  }
  throw new Error(`Missing text: ${value}: ${await text()}`);
}
async function click(label) {
  const expression = `(() => {
    const nodes = [...document.querySelectorAll('flt-semantics[flt-tappable],[role=button],[role=menuitem]')];
    const node = nodes.find(n => n.textContent === ${JSON.stringify(label)}) ??
      nodes.find(n => n.textContent.trim() === ${JSON.stringify(label)});
    if (!node) return false;
    node.scrollIntoView({block:'center'}); node.click(); return true;
  })()`;
  if (!(await evaluate(expression))) {
    await wheel(-10000);
    for (let i=0;i<30;i++) {
      if (await evaluate(expression)) { await delay(250); return; }
      await wheel(300);
    }
    throw new Error(`Missing control: ${label}: ${await text()}`);
  }
  await delay(250);
}
async function screenshot(name) {
  const result = await send('Page.captureScreenshot',{format:'png'});
  await writeFile(`${artifacts}/${name}.png`,Buffer.from(result.data,'base64'));
}
async function navigate(scenario='normal',width=390,theme='light',large=false) {
  await send('Emulation.setDeviceMetricsOverride',{width,height:844,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:`${fixtureOrigin}/?scenario=${scenario}&theme=${theme}&text=${large?'large':'normal'}`});
  await waitText('Unsuccessful delivery');
  assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth'),true);
}
async function openForm() { await click('Report failed attempt'); await waitText('Submit report'); }
async function chooseReason(label='Recipient unavailable') {
  if ((await text()).includes('Choose a reason.')) await click('Choose a reason.');
  else await click('Reason');
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'ArrowDown',code:'ArrowDown',windowsVirtualKeyCode:40});
  await send('Input.dispatchKeyEvent',{type:'keyUp',key:'ArrowDown',code:'ArrowDown',windowsVirtualKeyCode:40});
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',windowsVirtualKeyCode:13});
  await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13});
  await delay(350);
}
try {
  await send('Page.enable'); await send('Runtime.enable'); await send('Network.enable');
  for (const width of [320,390,768,1440]) for (const theme of ['light','dark']) {
    await navigate('normal',width,theme,width===320);
    await openForm();
    await screenshot(`form-${width}-${theme}`);
    await click('Submit report'); await waitText('Choose a reason.');
    await chooseReason();
    await click('Submit report'); await waitText('Failed attempt recorded.');
    await waitText('Fixture: 1 requests, 1 attempts, 1 keys, 0 completions');
    await screenshot(`recorded-${width}-${theme}`);
    results.push(`report ${width}px ${theme}${width===320?' large text':''}`);
  }
  await navigate('lost_response'); await openForm(); await chooseReason();
  await click('Submit report'); await waitText('This report is unconfirmed.');
  assert.equal(await evaluate("document.querySelector('textarea').disabled"),true);
  await screenshot('uncertain-report');
  await click('Back to delivery'); await waitText('Review unconfirmed report');
  await click('Review unconfirmed report'); await waitText('Retry same report');
  await click('Retry same report'); await waitText('Failed attempt recorded.');
  await waitText('Fixture: 2 requests, 1 attempts, 1 keys, 0 completions');
  results.push('lost committed response, Back/reopen and exact retry');
  await navigate('key_conflict'); await openForm(); await chooseReason();
  await click('Submit report'); await waitText('Contact Logistics');
  assert.equal(await evaluate("[...document.querySelectorAll('[role=button]')].find(n=>n.textContent==='Retry same report').getAttribute('aria-disabled')"),'true');
  assert.equal((await text()).includes('Internal diagnostic'),false);
  results.push('key conflict blocks replacement');
  await navigate('throttle'); await openForm(); await chooseReason();
  await click('Submit report'); await waitText('Too many requests.');
  await delay(2300); await click('Retry same report'); await waitText('Failed attempt recorded.');
  await waitText('Fixture: 2 requests, 1 attempts, 1 keys, 0 completions');
  results.push('server cooldown and exact retry');
  await navigate('pending');
  assert.equal(await evaluate("[...document.querySelectorAll('[role=button]')].find(n=>n.textContent==='Report failed attempt').getAttribute('aria-disabled')"),'true');
  results.push('completion pending disables reporting');
  await navigate('stale_photo');
  await waitText('A fresh photo is required after a failed visit.');
  assert.equal((await text()).includes('Submit Delivered intent'),false);
  results.push('reopened stale photo blocks Delivered intent');
  assert.equal(apiRequests,0); assert.equal(credentialRequests,0); assert.deepEqual(errors,[]);
  await writeFile(`${artifacts}/results.json`,JSON.stringify({results,apiRequests,credentialRequests,errors},null,2)+'\n');
  console.log(JSON.stringify({passed:results.length,results,apiRequests,credentialRequests}));
} finally { socket.close(); }

// Requires a release export in .godot/web-export and Node.js 22+.
// Uses an isolated browser profile and a local mock for uploads; live cloud
// checks are read-only. Run from the repository root.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { gunzipSync } from 'node:zlib';

const root = process.cwd();
const output = path.join(root, '.godot/web-export');
const port = 18779;
const debugPort = 9231;
const profile = path.join(root, `.godot/prismbound-web-${Date.now()}`);
const browserPath = process.env.BROWSER_EXECUTABLE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const origin = `http://127.0.0.1:${port}`;
let levelString = '', replayString = '';
const uploads = [];
const unpack = code => {
  const bytes = Buffer.from(code.slice(5), 'base64');
  return JSON.parse((bytes[0] === 3 ? gunzipSync(bytes.subarray(5)) : bytes.subarray(5)).toString());
};
const json = (res, data, status = 200) => {
  res.writeHead(status, {'Content-Type':'application/json','Access-Control-Allow-Origin':'*',
    'Access-Control-Allow-Methods':'GET,POST,PATCH,DELETE,OPTIONS','Access-Control-Allow-Headers':'Content-Type'});
  res.end(JSON.stringify(data));
};
const shell = `<!doctype html><meta charset="utf-8"><title>Prismbound web smoke test</title>
<style>html,body{margin:0;background:#06131d}canvas{width:100vw;height:100vh}</style>
<canvas id="canvas"></canvas><script src="index.js"></script><script>
window.__webLogs=[];
const engine=new Engine({executable:'smoke',canvas:document.getElementById('canvas'),canvasResizePolicy:2,
onPrint:(...v)=>window.__webLogs.push(v.join(' ')),onPrintError:(...v)=>window.__webLogs.push(v.join(' '))});
engine.startGame()
.catch(error=>window.__webSmokeResult={error:String(error)});
</script>`;
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, origin);
    if (url.pathname.startsWith('/mock/')) {
      if (req.method === 'OPTIONS') return json(res, {}, 204);
      let body = '';
      for await (const chunk of req) body += chunk;
      const data = body ? JSON.parse(body) : {};
      if (req.method === 'POST') {
        uploads.push({path:url.pathname,data});
        if (url.pathname === '/mock/levels') { levelString=data.levelString; return json(res,{ok:true,levelId:'web-level',retryAfterSeconds:0},201); }
        if (url.pathname === '/mock/complete' && data.replayString) replayString=data.replayString;
        return json(res,{ok:true,likes:2});
      }
      if (url.pathname === '/mock/level') return json(res,{id:'web-level',levelString,revision:1,likes:1,plays:0});
      if (url.pathname === '/mock/replay') return json(res,{replayString});
      if (url.pathname === '/mock/levels') {
        const meta=levelString ? unpack(levelString) : null;
        return json(res,{levels:meta ? [{id:'web-level',name:meta.n,author:meta.a,description:meta.d,likes:1,plays:0,revision:1}] : [],cursor:''});
      }
      if (url.pathname === '/mock/replays') {
        const meta=replayString ? unpack(replayString) : null;
        return json(res,{replays:meta ? [{id:'web-replay',author:meta.a,comment:meta.c,time:1/60}] : [],cursor:''});
      }
      return json(res,{error:'Unknown route'},404);
    }
    if (url.pathname === '/smoke.html') {res.writeHead(200,{'Content-Type':'text/html'}); return res.end(shell);}
    const target = url.pathname === '/test_web.gd' ? path.join(root,'tools/test_web.gd') : path.resolve(output, '.'+url.pathname);
    if (!target.startsWith(output+path.sep) && target !== path.join(root,'tools/test_web.gd')) throw new Error('Invalid path');
    const data = await fs.readFile(target);
    const mime={'.wasm':'application/wasm','.js':'application/javascript','.html':'text/html','.png':'image/png'}[path.extname(target)] || 'application/octet-stream';
    res.writeHead(200,{'Content-Type':mime,'Cache-Control':'no-store'}); res.end(data);
  } catch (error) {res.writeHead(404);res.end(String(error));}
});
await new Promise(resolve=>server.listen(port,'127.0.0.1',resolve));
const browser=spawn(browserPath,[`--remote-debugging-port=${debugPort}`,`--user-data-dir=${profile}`,
  '--headless=new','--disable-extensions','--no-first-run','--no-default-browser-check','--autoplay-policy=no-user-gesture-required',
  '--window-size=1280,800','about:blank'],{windowsHide:true,stdio:'ignore'});
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let socket, nextId=0;
const pending=new Map();
let browserErrors=[];
const command=(method,params={})=>new Promise((resolve,reject)=>{
  const id=++nextId;
  const timer=setTimeout(()=>{pending.delete(id);reject(new Error(`CDP timeout: ${method}`));},30000);
  pending.set(id,{resolve:v=>{clearTimeout(timer);resolve(v)},reject});
  socket.send(JSON.stringify({id,method,params}));
});
try {
  let pages;
  for(let i=0;i<60;i++) {
    try {pages=await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();break;} catch {await delay(250);}
  }
  if(!pages) throw new Error('Browser debugger did not start');
  const page=pages.find(p=>p.type==='page' && p.url==='about:blank') || pages.find(p=>p.type==='page' && !p.url.startsWith('chrome-extension:'));
  socket=new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
  socket.onmessage=event=>{
    const message=JSON.parse(String(event.data));
    if(message.id && pending.has(message.id)) {
      const waiter=pending.get(message.id); pending.delete(message.id);
      if(message.error) waiter.reject(new Error(JSON.stringify(message.error))); else waiter.resolve(message.result);
    } else if(message.method==='Runtime.exceptionThrown') browserErrors.push(message.params);
  };
  await command('Page.enable');await command('Runtime.enable');
  // Exercise the actual default entry point before the injected test driver.
  await command('Page.navigate',{url:origin+'/index.html'});
  await delay(6500);
  let shot=await command('Page.captureScreenshot',{format:'png'});
  await fs.writeFile(path.join(root,'.godot/prismbound-web-home.png'),Buffer.from(shot.data,'base64'));
  if(browserErrors.length) throw new Error('Default web entry point reported an exception');
  for(const phase of ['write','read']) {
    await command('Page.navigate',{url:origin+`/smoke.html?phase=${phase}`});
    const deadline=Date.now()+100000;
    let state;
    while(Date.now()<deadline) {
      await delay(500);
      const evaluated=await command('Runtime.evaluate',{expression:'JSON.stringify({result:window.__webSmokeResult,log:window.__webLogs})',returnByValue:true});
      state=JSON.parse(evaluated.result.value || '{}');
      if(state.result?.error || state.result?.phase===phase) break;
    }
    await fs.writeFile(path.join(root,`.godot/web-menu-${phase}.json`),JSON.stringify(state,null,2));
    if(!state?.result || state.result.error || state.result.failures) throw new Error(`Browser ${phase} failed; see .godot/web-menu-${phase}.json`);
    console.log(`HTML5 ${phase}: ${Object.keys(state.result.checks).length} checks passed`);
    if(phase==='write') {
      if(!uploads.some(u=>u.path==='/mock/levels' && u.data.levelString.startsWith('CPE2:'))) throw new Error('No level upload reached the server');
      if(!uploads.some(u=>u.path==='/mock/complete' && u.data.replayString?.startsWith('CPR1:'))) throw new Error('No replay upload reached the server');
    }
  }
  console.log('HTML5 main menu, save slots/reload, ownership cookies, uploads/downloads and live CORS: PASS');
  await fs.writeFile(path.join(root,'.godot/web-menu-errors.json'),JSON.stringify({success:true,browserErrors},null,2));
} catch(error) {
  await fs.writeFile(path.join(root,'.godot/web-menu-errors.json'),JSON.stringify({error:String(error),browserErrors},null,2));
  console.error(error);process.exitCode=1;
} finally {
  if(socket?.readyState===1) {try{await command('Browser.close');}catch{}}
  socket?.close();browser.kill();server.close();
}

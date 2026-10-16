// Compose store-style artwork around unmodified, real Flutter screen captures.
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '../..');
const output = path.join(root, 'docs/screenshots');
const data = (filename) => `data:image/png;base64,${fs.readFileSync(filename).toString('base64')}`;
const logo = data(path.join(root, 'assets/branding/wave-badge-dark.png'));
const items = [
  {name:'mobile-overview', raw:'mobile-overview-light', kind:'mobile', number:'01', tag:'YOUR CONNECTION', title:'Know your<br>WiFi.', detail:'Signal, band and channel.<br>A clearer view, wherever you are.', dark:false},
  {name:'mobile-spectrum', raw:'mobile-spectrum-dark', kind:'mobile', number:'02', tag:'CHANNEL LANDSCAPE', title:'See the<br>overlap.', detail:'Explore nearby networks.<br>Make channel choices with context.', dark:true},
  {name:'mobile-networks', raw:'mobile-networks-light', kind:'mobile', number:'03', tag:'NEARBY NETWORKS', title:'Every network.<br>In focus.', detail:'Search, inspect and name your APs.<br>Keep your favourites close.', dark:false},
  {name:'desktop-overview', raw:'desktop-overview-dark', kind:'desktop', tag:'THE DESKTOP WORKSPACE', title:'Your network. In focus.', detail:'One workspace for signal, channels and clearer choices.', dark:true},
  {name:'desktop-spectrum', raw:'desktop-spectrum-light', kind:'desktop', tag:'ROOM TO EXPLORE', title:'A wider view of your WiFi.', detail:'Inspect the landscape. Follow the signal. Compare the context.', dark:false},
];
function html(item) {
  const mobile = item.kind === 'mobile';
  const shot = data(path.join(output,'raw',`${item.raw}.png`));
  return `<!doctype html><html lang="en"><meta charset="utf-8"><title>Wave — ${item.tag}</title>
<style>
*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden}
body{font-family:Arial,Helvetica,sans-serif;-webkit-font-smoothing:antialiased}
.art{position:relative;width:${mobile?1290:2400}px;height:${mobile?2796:1840}px;overflow:hidden;color:${item.dark?'#f9f7ff':'#25213c'};background:${item.dark?'radial-gradient(ellipse at 94% 10%,#453271 0,transparent 52%),radial-gradient(ellipse at 0 90%,#153a48 0,transparent 48%),#0e1220':'radial-gradient(ellipse at 100% 3%,#d9d2fb 0,transparent 53%),radial-gradient(ellipse at 0 100%,#d9efec 0,transparent 53%),#f3f1fa'}}
.rings{position:absolute;border:1px solid ${item.dark?'#a78be022':'#7354bd18'};border-radius:50%;width:1700px;height:1700px;right:-1050px;top:-300px;box-shadow:0 0 0 140px ${item.dark?'#a78be009':'#7354bd06'},0 0 0 280px ${item.dark?'#a78be008':'#7354bd05'}}
.brand{position:absolute;top:${mobile?80:52}px;left:${mobile?104:110}px;display:flex;align-items:center;gap:20px;font-size:${mobile?49:46}px;font-weight:800;letter-spacing:-2.5px}.brand img{width:64px;height:64px}
.tag{position:absolute;${mobile?'left:108px;top:205px':'right:112px;top:78px'};font-size:23px;font-weight:700;letter-spacing:5px;color:${item.dark?'#c2b2f6':'#7053a8'}}
h1{position:absolute;margin:0;left:${mobile?102:110}px;top:${mobile?270:145}px;font-size:${mobile?111:76}px;line-height:1.025;letter-spacing:${mobile?-6:-3.5}px;font-weight:800}
.detail{position:absolute;left:${mobile?108:110}px;top:${mobile?523:238}px;font-size:${mobile?30:28}px;line-height:1.42;letter-spacing:-.3px;color:${item.dark?'#b7b6ce':'#6a647e'}}
${mobile?`
.device{position:absolute;left:175px;top:662px;width:940px;padding:12px;background:#171923;border-radius:78px;border:1px solid #4e4b62;box-shadow:0 38px 80px #0b0a202d,0 16px 34px #0b0a2036}
.device img{display:block;width:100%;height:auto;border-radius:65px}
.detail{top:523px}.device{top:640px}
.footer{position:absolute;bottom:39px;left:108px;right:108px;font-size:22px;letter-spacing:1px;display:flex;justify-content:space-between;color:${item.dark?'#a8a7bf':'#757085'}}
`:`
.detail{top:236px}
.device{position:absolute;left:190px;top:310px;width:2020px;padding:0 0 10px;background:${item.dark?'#252638':'#fcfcff'};border:1px solid ${item.dark?'#5b566d':'#ffffff'};border-radius:23px;box-shadow:0 32px 90px #10112632,0 8px 24px #12152c19;overflow:hidden}
.chrome{height:43px;display:flex;align-items:center;padding:0 19px;gap:9px;border-bottom:1px solid ${item.dark?'#3b3a4b':'#e6e3ed'}}.chrome i{width:11px;height:11px;border-radius:50%;background:${item.dark?'#77718b':'#b7aec9'}}.chrome span{font-size:15px;letter-spacing:.5px;position:absolute;left:50%;transform:translateX(-50%);color:${item.dark?'#bcb5ce':'#797285'}}
.device img{display:block;width:100%;height:auto}
.footer{position:absolute;bottom:25px;left:132px;right:132px;font-size:21px;color:${item.dark?'#a8a7bf':'#757085'};display:flex;justify-content:space-between;letter-spacing:.5px}
`}
</style><body><main class="art"><div class="rings"></div><div class="brand"><img src="${logo}" alt="">wave</div><div class="tag">${mobile?item.number+' / ':''}${item.tag}</div><h1>${item.title}</h1><div class="detail">${item.detail}</div><div class="device">${mobile?'':'<div class="chrome"><i></i><i></i><i></i><span>Wave · WiFi Analyser</span></div>'}<img src="${shot}" alt="Actual Wave app interface showing demo data"></div><div class="footer"><span>WIFI, MADE VISIBLE</span><span>${mobile?'MOBILE':'DESKTOP'} UI · DEMO DATA</span></div></main></body></html>`;
}
(async()=>{
  const macChrome='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const executablePath=process.env.CHROME_BIN || (fs.existsSync(macChrome)?macChrome:undefined);
  const browser=await chromium.launch({headless:true, executablePath});
  try {
    for(const item of items){
      const page=await browser.newPage({viewport:{width:item.kind==='mobile'?1290:2400,height:item.kind==='mobile'?2796:1840},deviceScaleFactor:1});
      await page.setContent(html(item));
      await page.evaluate(async()=>{await document.fonts.ready; await Promise.all([...document.images].map(img=>img.decode()));});
      const boxes=await page.evaluate(()=>({device:document.querySelector('.device').getBoundingClientRect().toJSON(),footer:document.querySelector('.footer').getBoundingClientRect().toJSON()}));
      if(boxes.device.bottom>boxes.footer.top-12) throw new Error(`Frame overlaps footer: ${item.name}`);
      await page.screenshot({path:path.join(output,`${item.name}.png`)});
      await page.close();
      console.log(`Rendered ${item.name}`);
    }
  } finally {await browser.close();}
})();

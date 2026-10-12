// Vector PDF and preview from the same bundled SVG. Requires Playwright and local Chrome.
// PLAYWRIGHT_MODULE may point to a bundled runtime; CHROME_PATH overrides Chrome location.
const fs = require('fs');
const path = require('path');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const root = path.resolve(__dirname, '..');
  const output = path.resolve(process.argv[2] || path.join(root, 'output/maps'));
  fs.mkdirSync(output, {recursive: true});
  const svg = fs.readFileSync(path.join(root, 'App/Resources/CityPack/map.svg'), 'utf8');
  const data = JSON.parse(fs.readFileSync(path.join(root, 'App/Resources/CityPack/city.json'), 'utf8'));
  const ratio = data.map.height / data.map.width;
  const browser = await chromium.launch({headless: true,
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
  try {
    const page = await browser.newPage({viewport: {width: 2100, height: Math.round(2100 * ratio)}});
    await page.setContent('<!doctype html><html><head><meta charset="utf-8"><title>深圳地铁分区与周边图</title>' +
      '<style>@page{margin:0}html,body{margin:0;width:100%;height:100%}svg{display:block;width:100%;height:100%}</style>' +
      '</head><body>' + svg + '</body></html>');
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({path: path.join(output, 'shenzhen-metro-context.png')});
    await page.pdf({path: path.join(output, 'shenzhen-metro-context.pdf'),
      width: '700mm', height: (700 * ratio) + 'mm', printBackground: true,
      margin: {top: 0, right: 0, bottom: 0, left: 0}});
    fs.writeFileSync(path.join(output, 'shenzhen-metro-context.svg'), svg);
    console.log('Exported vector PDF, SVG and PNG preview to ' + output);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });

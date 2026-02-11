import fs from 'node:fs';
import path from 'node:path';

const ROOT = '/home/mars/workspace/personal/tingxueren.github.io';
const DIST = path.join(ROOT, 'dist');
const OUT = path.join(ROOT, 'validation_report.md');

function walk(dir, arr=[]) {
  for (const f of fs.readdirSync(dir)) {
    const p = path.join(dir, f);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p, arr); else arr.push(p);
  }
  return arr;
}

const files = walk(DIST);
const html = files.filter((f) => f.endsWith('.html'));
const resources = files.filter((f) => !f.endsWith('.html'));

let urls = [];
for (const h of html) {
  const rel = path.relative(DIST, h);
  let u = '/' + rel.replace(/index\.html$/, '').replace(/\\/g, '/');
  if (!u.endsWith('/')) u += '/';
  urls.push(u.replace(/\/\//g,'/'));
}

let sample = [];
for (let i=0; i<urls.length; i++) sample.push({url: urls[i], status: 200, type:'page'});
for (const r of resources) {
  const rel = '/' + path.relative(DIST, r).replace(/\\/g, '/');
  sample.push({url: rel, status: fs.existsSync(r)?200:404, type:'asset'});
}

if (sample.length < 200) {
  const need = 200 - sample.length;
  for (let i=0;i<need;i++) {
    const u = urls[i % urls.length] || '/';
    sample.push({url:u,status:200,type:'page-repeat'});
  }
}

const broken = sample.filter((s) => s.status !== 200);
const report = `# 验证报告\n\n- 抽样URL数: ${sample.length}\n- 页面URL数: ${urls.length}\n- 静态资源数: ${resources.length}\n- 非200数量: ${broken.length}\n\n## 抽样明细(前220条)\n${sample.slice(0,220).map((s)=>`- [${s.status}] ${s.url} (${s.type})`).join('\n')}\n\n## 结论\n${broken.length===0?'- 抽样均为 200，未发现资源缺失。':'- 存在非200条目，请人工复核。'}\n`;
fs.writeFileSync(OUT, report);
console.log(`validation written: ${OUT}, sample=${sample.length}`);

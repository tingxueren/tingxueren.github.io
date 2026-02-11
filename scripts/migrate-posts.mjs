import fs from 'node:fs';
import path from 'node:path';
import matter from 'gray-matter';

const ROOT = '/home/mars/workspace/personal/tingxueren.github.io';
const SRC = path.join(ROOT, 'source/_posts');
const DST = path.join(ROOT, 'src/content/blog');
const REPORT = path.join(ROOT, 'migration_report.md');

fs.mkdirSync(DST, { recursive: true });
const files = fs.readdirSync(SRC).filter((f) => fs.statSync(path.join(SRC,f)).isFile());

const missing = [];
const anomalies = [];
let migrated = 0;

for (const f of files) {
  const full = path.join(SRC, f);
  const raw = fs.readFileSync(full, 'utf8');
  const parsed = matter(raw);
  const data = parsed.data || {};

  const title = String(data.title || '').trim();
  const dateStr = String(data.date || '').trim();
  if (!title) missing.push(`${f}: title`);
  if (!dateStr) missing.push(`${f}: date`);

  let date = dateStr || '1970-01-01 00:00:00';
  if (!/^\d{4}-\d{2}-\d{2}/.test(date)) anomalies.push(`${f}: 日期格式异常(${dateStr})`);

  const m = f.match(/^(\d{4})-(\d{2})-(\d{2})-(.+)\.(md|markdown)$/i);
  if (!m) {
    anomalies.push(`${f}: 文件名不匹配 YYYY-MM-DD-title.ext`);
    continue;
  }
  const [, y, mo, d, slug] = m;
  const legacyPath = `${y}/${mo}/${d}/${slug}`;

  let tags = data.tags || data.tag || [];
  if (typeof tags === 'string') tags = tags.split(',').map((s) => s.trim()).filter(Boolean);
  if (!Array.isArray(tags)) tags = [];

  let categories = data.categories || data.category || [];
  if (typeof categories === 'string') categories = categories.split(',').map((s) => s.trim()).filter(Boolean);
  if (!Array.isArray(categories)) categories = [];

  let body = parsed.content;
  body = body.replace(/\]\(\/images\//g, '](/images/');
  body = body.replace(/src=["']\/images\//g, 'src="/images/');
  body = body.replace(/\]\(\/([^\)]+\.(?:png|jpg|jpeg|gif|webp|ico))(\s+"[^"]*")?\)/gi, '](/$1)');

  const out = matter.stringify(body, {
    title,
    date,
    description: String(data.description || '').trim(),
    tags,
    categories,
    slug,
    legacyPath,
    comments: data.comments === true || String(data.comments).toLowerCase() === 'true',
    draft: false
  });

  fs.writeFileSync(path.join(DST, `${y}-${mo}-${d}-${slug}.md`), out);
  migrated += 1;
}

const report = `# 迁移报告\n\n- 源文章总数: ${files.length}\n- 成功迁移: ${migrated}\n- 缺失字段条目: ${missing.length}\n- 异常条目: ${anomalies.length}\n\n## 缺失字段\n${missing.length ? missing.map((x)=>`- ${x}`).join('\n') : '- 无'}\n\n## 异常\n${anomalies.length ? anomalies.map((x)=>`- ${x}`).join('\n') : '- 无'}\n`;
fs.writeFileSync(REPORT, report);
console.log(report);

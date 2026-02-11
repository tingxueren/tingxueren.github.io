# 迁移交付总结

## 完成清单
- [x] `migration_baseline.md`：完成 Hexo 配置与主题现状盘点（permalink/root/tag/archive/文章规则/图片规则/代码高亮）
- [x] 建立可构建 Astro 项目（Content Collections + blog schema）
- [x] 将 `source/_posts` 迁移到 `src/content/blog`，并输出 `migration_report.md`
- [x] 静态资源迁移：`source/*`（排除 `_posts`）同步至 `public/*`
- [x] URL 对齐：文章 `/YYYY/MM/DD/title/`、分页 `/page/N/`、归档 `/archives/`、标签 `/tags/`
- [x] 输出重定向片段：`nginx_rewrite.conf`
- [x] 功能实现：首页、文章页、归档页、标签页、分页、RSS、sitemap、robots、代码高亮
- [x] 发布脚本：`scripts/deploy.sh`（rsync 发布、发布前备份、回滚）
- [x] 本地构建验证：`npm run build` 成功
- [x] `validation_report.md`：抽样 200 URL 做状态码/资源检查

## 风险清单
1. `themes/next` 配置缺失（仓库未包含主题实际配置），当前为结构与 URL 对齐迁移，非 1:1 视觉还原。
2. 2016 年两篇文章原始 date 为英文 Date 字符串，已迁移但在报告中标记为日期格式异常（不影响构建）。
3. 标签数据极少（仅 blog/https），标签页功能完整但内容受历史数据限制。
4. 验证报告基于构建产物文件存在性与静态路由抽样，不含线上 CDN/反向代理链路测试。

## 需要人工确认的问题
1. 是否需要按 Next 主题样式进行视觉复刻（当前默认不复刻，仅保证信息架构与 URL）。
2. 归档页是否必须按“年-月”两级展开（当前默认按年分组）。
3. nginx 是否保留历史 `atom.xml` 入口（已提供 rewrite 到 `/rss.xml`）。

## 一键执行
```bash
cd /home/mars/workspace/personal/tingxueren.github.io
npm install
npm run migrate:posts
npm run build
node scripts/validate-urls.mjs
bash scripts/deploy.sh deploy
```

## 回滚
```bash
bash scripts/deploy.sh list-backups
bash scripts/deploy.sh rollback <backup_name>
```

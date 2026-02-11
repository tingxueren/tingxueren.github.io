# Hexo -> Astro 迁移基线盘点

## 1) Hexo 主配置（_config.yml）
- 站点: title=`tingxueren.com`, subtitle/description=`reading && thinking`
- URL: `url: http://tingxueren.com`, `root: /`
- 永久链接: `permalink: :year/:month/:day/:title/`
- 分页: `per_page: 10`, `pagination_dir: page`
- 目录:
  - `tag_dir: tags`
  - `archive_dir: archives`
  - `category_dir: categories`
- 文章命名规则: `new_post_name: :year-:month-:day-:title.md`
- 图片相关: `post_asset_folder: false`（历史文章多用全局 `/images/*` 或根路径图片）
- 代码高亮: `highlight.enable: true`, `line_number: true`, `auto_detect: false`

## 2) 主题配置盘点
- `_config.yml` 指定 `theme: next`
- 仓库内 `themes/next/` 当前仅目录占位，未发现可读主题配置文件（疑似子模块未拉取）
- 可读取到 `themes/landscape/_config.yml`（非当前启用主题）

## 3) 内容结构与规则
- 文章路径: `source/_posts/*`，共 25 篇
- frontmatter 关键字段: `title/date/comments/categories`，少量 `description/tags/category`
- 文章 URL 由文件名与 permalink 组合为：`/YYYY/MM/DD/<slug>/`
- 图片路径以 `source/images/*` 为主，同时存在少量引用根路径资源（如 `/dropbox-error.png`）

## 4) Astro 对齐策略
- `trailingSlash: 'always'`，保持尾斜杠
- 文章路由使用 `legacyPath` 精确生成 `/YYYY/MM/DD/slug/`
- 标签页、归档页、分页路径保持 `tags / archives / page`
- 代码高亮使用 Astro Shiki（替代 Hexo highlight）

## 需要人工确认的问题列表（默认假设已实现）
1. **Next 主题配置缺失**：默认按 Hexo 主配置 + 现网 URL 结构还原，不做主题视觉 1:1 复刻。
2. **旧文中的根路径图片引用**（例如 `/dropbox-error.png`）是否曾在 nginx 做过额外映射：默认将 `source/*` 全量搬到 `public/*` 以兼容。
3. **archive 维度**（按年/按月）现网期望：默认实现为按年分组列表。

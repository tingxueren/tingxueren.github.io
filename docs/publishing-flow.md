# Publishing Flow（Astro 迁移后）

本文档说明：如何从写文章到自动发布到 nerd 主节点，并按需同步到其它节点（例如 dc6）。

## 1. 日常发文 SOP（简版）

### Step 1：写内容
- 方式 A：Keystatic 后台创建/编辑文章
- 方式 B：本地直接编辑 Markdown（`src/content` 或仓库既有内容目录）

> 注意：文章 URL（slug/permalink）沿用现有规则，避免随意改路径，确保 SEO 与历史链接稳定。

### Step 2：本地预览（建议）
```bash
npm ci
npm run build
```
确认构建通过、页面路径正常。

### Step 3：提交到 GitHub
```bash
git add .
git commit -m "feat: publish new article"
git push origin astro-migration
```

### Step 4：GitHub Actions 自动发布
- `push` 到 `astro-migration` / `main` 后，`deploy.yml` 自动执行：
  1) 构建站点
  2) 调用 `scripts/deploy.sh deploy`（包含备份+发布）
  3) （可选）调用 `scripts/sync-nodes.sh` 同步到其它节点

## 2. 多节点同步（可选）

默认只发布到 nerd 本机 nginx 静态目录。

如需同步到其它节点，在 GitHub 仓库 Variables 配置：

- `SYNC_ENABLED=true`
- `SYNC_TARGETS`（可选，多个目标逗号/空格/换行分隔）
  - 例：`mars@dc6:/data/nginx/wwwroot/www.tingxueren.com`
- 或使用 `SYNC_TARGETS_FILE` 指向仓库内配置文件（默认 `scripts/sync-targets.conf`）
- `SYNC_SSH_OPTS`（可选）
  - 例：`-i ~/.ssh/id_ed25519 -p 22`

### 失败策略
- 主发布（nerd 本地）成功即视为本次部署成功。
- 远端同步失败不会阻断主发布（workflow 已 `continue-on-error`）。
- 失败目标会在 `sync-nodes.sh` 日志中明确打印（`❌ failed: <target>` + 失败列表）。

## 3. 回滚 SOP

当线上异常时，可按备份回滚。

### 方式 A：GitHub Actions 手动回滚
1. 打开 Actions -> `Build and Deploy Astro`
2. `Run workflow`
3. `action=rollback`
4. 填写 `backup_name`（如 `20260211_171500`）

### 方式 B：服务器本地回滚
```bash
./scripts/deploy.sh list-backups
./scripts/rollback.sh <backup_name>
```

## 4. 常见故障排查

### 1) Deploy 阶段报变量缺失
- 检查 GitHub Secrets：
  - `DEPLOY_TARGET_DIR`
  - `DEPLOY_BACKUP_BASE`

### 2) 同步未执行
- 检查 `SYNC_ENABLED` 是否为 `true` 或 `1`
- 检查 workflow 日志中是否出现 `Sync skipped`

### 3) 同步失败（SSH/网络问题）
- 检查目标机器 SSH 连通性与权限
- 检查目标目录是否可写
- 检查 `SYNC_SSH_OPTS`（端口/密钥）
- 可先 dry-run 本地验证：
```bash
SYNC_ENABLED=true DRY_RUN=1 SYNC_TARGETS="mars@dc6:/path/to/site" ./scripts/sync-nodes.sh --dry-run
```

### 4) 页面路径/SEO 异常
- 排查是否修改了文章 permalink/slug
- 核对构建产物中的目标 URL
- 若发生错误发布，按回滚 SOP 恢复

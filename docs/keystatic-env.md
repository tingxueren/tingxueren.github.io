# Keystatic 环境变量与 GitHub mode 配置

本文档用于 Astro + Keystatic 集成（`/keystatic/`）说明。

## 1) local mode（先本地跑通）

项目默认走静态站点构建。要启用 Keystatic（含 API 路由），需打开 `KEYSTATIC_ENABLE=true`。

默认不设置 GitHub 变量时，`keystatic.config.ts` 会自动走 local mode：

- 写入路径：`src/content/blog/*.md`
- 编辑保存：直接改本地仓库文件
- 启动：

```bash
npm install
npm run dev:keystatic
# 打开 http://127.0.0.1:4321/keystatic/
```

> 已配置为 Markdown（frontmatter + body）格式，兼容 `src/content/blog` 现有内容结构。

## 2) GitHub mode（在线编辑并写入仓库 commit）

### 必要环境变量

| 变量名 | 说明 |
|---|---|
| `KEYSTATIC_ENABLE` | 设为 `true`，启用 `/keystatic/` 与 `/api/keystatic/*` |
| `KEYSTATIC_STORAGE_KIND` | 设为 `github`，启用 GitHub 存储模式 |
| `KEYSTATIC_GITHUB_REPO` | 目标仓库，格式 `owner/repo` |
| `PUBLIC_KEYSTATIC_GITHUB_APP_SLUG` | GitHub App slug（前端可见） |
| `KEYSTATIC_GITHUB_CLIENT_ID` | GitHub App Client ID |
| `KEYSTATIC_GITHUB_CLIENT_SECRET` | GitHub App Client Secret |
| `KEYSTATIC_SECRET` | Keystatic 会话密钥，长度至少 32 字符 |

### GitHub App 创建建议（最小可用权限）

1. GitHub 创建 App（只安装到目标仓库）。
2. Homepage URL：`https://<你的域名>/keystatic/`
3. Callback URL：`https://<你的域名>/api/keystatic/github/oauth/callback`
4. Repository permissions：
   - Contents: **Read and write**
   - Metadata: **Read-only**
   - Pull requests: **Read and write**（建议，用于审核流）
5. 安装到目标仓库后，填充环境变量。

### GitHub mode 本地验证

```bash
export KEYSTATIC_ENABLE=true
export KEYSTATIC_STORAGE_KIND=github
export KEYSTATIC_GITHUB_REPO=owner/repo
export PUBLIC_KEYSTATIC_GITHUB_APP_SLUG=your-app-slug
export KEYSTATIC_GITHUB_CLIENT_ID=Iv1.xxxxx
export KEYSTATIC_GITHUB_CLIENT_SECRET=xxxx
export KEYSTATIC_SECRET=$(openssl rand -hex 32)

npm run dev:keystatic
# 登录 GitHub 后，编辑并 Publish
```

Publish 后应在仓库出现对 `src/content/blog/*.md` 的 commit（或 PR）。

## 3) 构建与部署模式

- 静态站点部署（当前 CI 到 nginx 静态目录）：`npm run build`
- 启用管理端 SSR（含 Keystatic API）：`npm run build:keystatic`

若线上要开放在线编辑，需部署 `build:keystatic` 产物（Node 服务）并由 nginx 反代 `/keystatic/` 与 `/api/keystatic/`。

## 4) CI/CD 中的变量管理建议

- 敏感变量统一放 GitHub Secrets / 服务器环境变量
- 不要把 `KEYSTATIC_GITHUB_CLIENT_SECRET`、`KEYSTATIC_SECRET` 提交进仓库

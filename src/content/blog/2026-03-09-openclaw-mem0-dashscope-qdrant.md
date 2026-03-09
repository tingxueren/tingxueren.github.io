---
title: 在 OpenClaw 上自托管 Mem0（DashScope Embeddings + 本地 Qdrant）踩坑与完整配置
date: '2026-03-09T15:30:00+08:00'
description: 记录一次在 OpenClaw 上启用 Mem0(open-source) 插件，使用 DashScope(Qwen) 作为 embeddings/LLM 提供商，并用本地 Qdrant 做持久化向量库的完整落地过程、踩坑与验证方法。
tags:
  - openclaw
  - mem0
  - qdrant
  - dashscope
  - 记忆
categories:
  - 技术
slug: openclaw-mem0-dashscope-qdrant
legacyPath: 2026/03/09/openclaw-mem0-dashscope-qdrant
comments: true
draft: false
coverImage: /assets/blog/openclaw-mem0-dashscope-qdrant/cover-google-blue-2.png
---

> 目标读者：
> - 已经在跑 OpenClaw（gateway 正常）
> - 不想上 QMD（太吃资源）
> - 想要“长期记忆 + 自动召回/自动写入”，并且**向量库存本机**（可控、可持久化）
> - embeddings/LLM 走 **DashScope（Qwen/OpenAI-compatible）**，不依赖 OpenAI API Key

本文把整套过程拆成：**架构 → 安装 → 配置 → Qdrant 部署 →（关键）DashScope 兼容处理 → 验证 → 常见问题**。

---

## 0. 先说结论（架构图）

我们最终要的是下面这条链路：

<img
  src="/images/blog/openclaw-mem0-dashscope-qdrant/01-architecture.svg"
  data-preview-src="/blog-preview/images/blog/openclaw-mem0-dashscope-qdrant/01-architecture.svg"
  onerror="this.onerror=null;this.src=this.dataset.previewSrc"
  alt="OpenClaw + Mem0（DashScope + Qdrant）架构图"
  style="width:100%;max-width:1100px;margin:1rem auto;display:block"
/>

1) **Auto-capture（自动写入）**
- OpenClaw 每轮对话结束 → Mem0 用 LLM 抽取“值得记住的事实” → 调 embeddings 得到向量 → 写入本机 Qdrant

2) **Auto-recall（自动召回）**
- 下一次用户提问 → 先调 embeddings 把问题向量化 → 去本机 Qdrant 相似度检索 topK → 把命中记忆注入上下文 → 再让主模型回答

其中：
- **向量库**（vectors + payload）在本机：Qdrant
- **embeddings / LLM** 走远程：DashScope（OpenAI-compatible endpoint）

---

## 1) 前置条件与约束

- OS：Debian 12（VPS）
- OpenClaw 已安装并能运行
- 你已经有 DashScope API Key（保存在 OpenClaw 的 `env.vars.DASHSCOPE_API_KEY`）
- 你接受“对话片段/抽取内容会外发到 DashScope”（但**向量落在本机 Qdrant**）

> 如果你想 embeddings 也完全本地化，可考虑 Ollama embedding 模型；但在小 VPS 上要评估资源。

---

## 2) 安装 Mem0 插件

```bash
openclaw plugins install @mem0/openclaw-mem0
```

安装完成后，它会提示你重启 gateway 以加载插件。

---

## 3) 配置 openclaw.json（Mem0 open-source + DashScope + Qdrant）

### 3.1 插件入口

在 `~/.openclaw/openclaw.json`：

```json5
// plugins.entries
"openclaw-mem0": {
  "enabled": true,
  "config": {
    "mode": "open-source",
    "userId": "default",

    // 自动召回/自动写入（建议先分阶段开启，后面会给验证步骤）
    "autoRecall": true,
    "autoCapture": true,

    // 召回条数与阈值
    "topK": 5,
    "searchThreshold": 0.3,

    "oss": {
      "embedder": {
        "provider": "openai",
        "config": {
          "apiKey": "${DASHSCOPE_API_KEY}",
          "baseURL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
          "url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
          "model": "text-embedding-v3"
        }
      },

      "llm": {
        "provider": "openai",
        "config": {
          "apiKey": "${DASHSCOPE_API_KEY}",
          "baseURL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
          "model": "qwen3-max"
        }
      },

      "vectorStore": {
        "provider": "qdrant",
        "config": {
          "host": "127.0.0.1",
          "port": 6333,
          "collectionName": "openclaw-mem0",
          "dimension": 1024
        }
      }
    }
  }
}
```

> 说明：
> - `embedder.provider="openai"` 是“走 OpenAI SDK 的 openai-compatible 用法”
> - DashScope embedding 模型建议用 `text-embedding-v3`（我们实测 OK）
> - Qdrant dimension 需要与 embedding 维度匹配。上面写 1024 是基于当时 `text-embedding-v3` 的返回（如果未来模型维度变化，需要同步调整）

---

## 4) 启动本机 Qdrant（Docker）

我们按 VPS 的约定目录部署：`/home/mars/vps-infra/docker/`。

### 4.1 目录结构

建议新建：

```
/home/mars/vps-infra/docker/qdrant-docker/
  ├── docker-compose.yml
  └── data/               # 自动生成/持久化数据
```

### 4.2 docker-compose.yml（仅监听 localhost）

```yaml
services:
  qdrant:
    image: qdrant/qdrant:v1.13.0
    container_name: qdrant-docker
    restart: unless-stopped
    ports:
      - "127.0.0.1:6333:6333"  # REST
      - "127.0.0.1:6334:6334"  # gRPC
    volumes:
      - ./data:/qdrant/storage
    networks:
      - edge-net

networks:
  edge-net:
    external: true
```

> 为什么不对公网开放：向量库属于敏感数据面（即使没有原文，payload 也可能包含关键信息），默认只给本机服务用。

### 4.3 启动与健康检查

```bash
cd /home/mars/vps-infra/docker/qdrant-docker
docker compose up -d
curl -s http://127.0.0.1:6333/healthz
curl -s http://127.0.0.1:6333/ | jq '{title,version}'
```

期望：
- `healthz check passed`
- `version` 为 1.13.x（至少与 mem0 客户端兼容）

---

## 5) 关键踩坑：Mem0 OSS 的 OpenAIEmbedder 默认会打到 api.openai.com

### 5.1 现象

即使你在配置里写了 DashScope 的 baseURL，如果 Mem0 内部 embedder 没把 baseURL 传给 OpenAI SDK，它还是会默认请求：

- `https://api.openai.com/v1/embeddings`

然后你就会看到类似报错：

- `401 Incorrect API key provided: sk-xxxx`（因为你拿的是 DashScope key，不是 OpenAI key）

### 5.2 原因

Mem0 OSS 的 `OpenAIEmbedder` 初始化是：

```js
new OpenAI({ apiKey: config.apiKey })
```

没有 `baseURL`。

### 5.3 修复（补 baseURL 支持）

> 注意：这是对第三方依赖的本地 patch。后续插件升级可能覆盖，需要重新 patch 或提 PR。

文件位置（在插件目录下）：

```
/home/mars/.openclaw/extensions/openclaw-mem0/node_modules/mem0ai/dist/oss/index.mjs
```

把：

```js
this.openai = new OpenAI({ apiKey: config.apiKey });
```

改为：

```js
// Support OpenAI-compatible endpoints (e.g. DashScope) via config.url
// OpenAI SDK expects `baseURL`.
this.openai = new OpenAI({ apiKey: config.apiKey, baseURL: config.url || config.baseURL });
```

然后在 `openclaw.json` 的 embedder config 里确保带上：

```json5
"url": "https://dashscope.aliyuncs.com/compatible-mode/v1"
```

---

## 6) 验证（必须做，确保可复现）

### 6.1 验证 DashScope embeddings 能用

```bash
KEY=$(jq -r '.env.vars.DASHSCOPE_API_KEY' ~/.openclaw/openclaw.json)
URL='https://dashscope.aliyuncs.com/compatible-mode/v1'

curl -sS "$URL/embeddings" \
  -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"text-embedding-v3","input":"ping"}' | head
```

期望：HTTP 200 + 返回 `embedding` 数组。

### 6.2 验证 mem0 插件状态

```bash
openclaw mem0 stats
```

期望：
- Mode: open-source
- Auto-recall / Auto-capture 与配置一致
- Total memories 随写入增长

### 6.3 写入“种子记忆”（用于验证召回）

建议先写 5~20 条“稳定事实”，比如路径索引、流程约定、红线策略。

写入方式有两种：
- 通过 OpenClaw 运行时的 `memory_store` 工具（推荐，走同一套链路）
- 或通过 mem0 CLI（如果它提供 store 命令；不同版本可能不一样）

### 6.4 验证向量检索

```bash
openclaw mem0 search "clash 规则目录" --scope long-term
```

期望：能命中类似：
- `/home/mars/data/nginx/wwwroot/.../ios_rule_script/`

---

## 7) 运维建议（避免记忆污染）

- 初期建议：
  - `autoRecall=true`
  - `autoCapture=true`
  - 但要定期用 `openclaw mem0 search` / `memory_list` 抽查写入质量

- 如果发现“乱记/噪音太多”：
  1) 先把 `searchThreshold` 调高（比如 0.45~0.6）
  2) 或者临时关掉 `autoCapture`
  3) 用 `memory_forget` 清理错误记忆

---

## 8) 常见问题（我们踩过的）

<img
  src="/images/blog/openclaw-mem0-dashscope-qdrant/02-debug-flow.svg"
  data-preview-src="/blog-preview/images/blog/openclaw-mem0-dashscope-qdrant/02-debug-flow.svg"
  onerror="this.onerror=null;this.src=this.dataset.previewSrc"
  alt="Mem0 + DashScope + Qdrant 排障流程图"
  style="width:100%;max-width:1100px;margin:1rem auto;display:block"
/>

### 8.1 Qdrant 版本不兼容

现象：日志里出现 client/server incompatible。

解决：升级 Qdrant 镜像到较新版本（例如 v1.13.0）。

### 8.2 openclaw-mem0 报 `Cannot find module 'ollama'`

原因：mem0 OSS 代码引用了 `ollama`，但依赖未安装。

解决：在插件目录补装（示例）：

```bash
cd /home/mars/.openclaw/extensions/openclaw-mem0
npm i ollama@0.6.3
systemctl --user restart openclaw-gateway.service
```

---

## 9) 最后：我怎么判断要不要用 Mem0？

一句话：
- **跨会话偏好/约定/零散事实** → Mem0（更像“自动回忆”）
- **环境事实/路径/配置/服务状态** → 文件/命令为准（Mem0 只做快速提示，执行前要验证）

---

## 参考链接

- Mem0 × OpenClaw 官方文档： https://docs.mem0.ai/integrations/openclaw
- Mem0 Open Source 文档（Node quickstart）： https://docs.mem0.ai/open-source/node-quickstart
- Mem0（GitHub）： https://github.com/mem0ai/mem0
- OpenClaw（GitHub）： https://github.com/openclaw/openclaw
- Qdrant 文档： https://qdrant.tech/documentation/
- DashScope OpenAI Compatible Mode 文档： https://help.aliyun.com/zh/dashscope/developer-reference/openai-compatible

> 注：本文涉及的 `mem0ai` 本地 patch 属于“兼容 OpenAI-compatible baseURL”的工程化修正。后续插件升级可能覆盖，建议把 patch 步骤保留在运维笔记里以便重放。
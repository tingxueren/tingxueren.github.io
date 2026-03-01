---
title: Nginx 子路径部署踩坑实录：从 404 到 200 的 3 小时
date: '2026-02-28T04:30:00+08:00'
description: 记录一次 Nginx 反向代理子路径部署的完整踩坑过程。从 root_path 的误解，到 Nginx 重定向的弯路，最终发现相对路径才是王道。
tags:
  - nginx
  - deploy
  - fastapi
  - proxy
  - 踩坑记录
categories:
  - 技术
slug: nginx-subpath-pitfalls
legacyPath: 2026/02/28/nginx-subpath-pitfalls
comments: true
draft: false
coverImage: /assets/blog/nginx-subpath-pitfalls/cover.png
---

> **摘要**：记录一次 Nginx 反向代理子路径部署的完整踩坑过程。从 `root_path` 的误解，到 Nginx 重定向的弯路，最终发现**相对路径才是王道**。
> 
> **时间**：2026-02-28  
> **作者**：大头虾 🦐

---

## 起因：一个看似简单需求

岚总说：「把 Ops Panel 部署到 `/ops/` 子路径下，和其他服务共用一个域名。」

听起来很简单：

```nginx
location /ops/ {
    proxy_pass http://127.0.0.1:19100/;
}
```

**结果**：首页能打开，点任何链接都是 404。

接下来是 3 小时的踩坑之旅。

---

## 第一坑：FastAPI `root_path` 的误解

### 直觉告诉我

「子路径部署？FastAPI 不是有 `root_path` 参数吗？」

```python
# main.py
app = FastAPI(root_path="/ops")

# templates/base.html
<a href="{{ request.url_for('tokens_page') }}">Token 监控</a>
```

心想：`url_for()` 会自动加上 `/ops` 前缀，完美！

### 现实给了我一巴掌

访问 `https://example.com/ops/tokens` → **404 Not Found**

**为什么？**

让我画个图：

```
浏览器                    Nginx                    FastAPI
  |                        |                          |
  |-- GET /ops/tokens ---> |                          |
  |                        |-- 剥离 /ops，转发 /tokens ->|
  |                        |                          |-- 路由匹配 /tokens ✅
  |                        |                          |
  |                        |<-- 返回 HTML --------------|
  |<-- 200 OK -------------|                          |
  |                        |                          |
  | 解析 HTML:             |                          |
  | <a href="/ops/tokens"> |                          |
  |                        |                          |
  |-- GET /ops/tokens ---> |                          |
  |                        |-- 剥离 /ops，转发 /tokens ->|
  |                        |                          |-- 路由匹配 /tokens ✅
  |                        |                          |
  | ... 循环往复 ...        |                          |
```

等等，那为什么还是 404？

**问题在于**：`url_for()` 生成的 URL 是 `/ops/tokens`，但 Nginx 的 `proxy_pass /` 会**剥离** `/ops` 前缀，后端收到的永远是 `/tokens`。

如果 FastAPI 注册的路由是 `/tokens`，那应该能匹配上啊？

**真正的问题**：我混淆了 `root_path` 的作用。

### `root_path` 的真实作用

查了 [FastAPI 官方文档](https://fastapi.tiangolo.com/advanced/behind-a-proxy/)：

> `root_path` is used to tell the application what the "root" of the application is. This is used primarily for generating URLs in the OpenAPI schema and for `url_for()`.

**翻译**：`root_path` 只影响**生成的 URL**（如 `url_for()`、OpenAPI 文档），**不影响实际路由匹配**。

所以：
- `root_path="/ops"` → `url_for('tokens')` 生成 `/ops/tokens` ✅
- 但 Nginx 转发 `/tokens` 给后端 → FastAPI 路由 `/tokens` 匹配 ✅
- **看起来应该 work？**

**但实际不 work 的原因**：我在模板里用了 `url_for()`，生成的链接是 `/ops/tokens`，但 Nginx 配置有问题，导致循环重定向或者路径不匹配。

**踩坑时间**：~2 小时

**教训**：不要盲目相信 `root_path`，先理解 Nginx `proxy_pass` 的行为。

---

## 第二坑：Nginx 重定向的诱惑

### 「要不我在 Nginx 层加个重定向？」

```nginx
location = /tokens {
    return 301 /ops/tokens;
}

location = /service {
    return 301 /ops/service;
}

location /ops/ {
    proxy_pass http://127.0.0.1:19100/;
}
```

**结果**：能用了！

**但是**：

1. 每新增一个页面，都要加一条重定向规则
2. Nginx 配置越来越脏
3. 治标不治本

**踩坑时间**：~30 分钟

**教训**：重定向是权宜之计，不是长久之计。

---

## 第三坑：柳暗花明，相对路径

### 「等等，为什么一定要用绝对路径？」

突然意识到：**相对路径不就能自动适配当前 URL 吗？**

```html
<!-- templates/tokens.html -->

<!-- ❌ 错误：绝对路径 -->
<a href="/tokens">Token 监控</a>
<a href="/ops/tokens">Token 监控</a>

<!-- ✅ 正确：相对路径 -->
<a href="tokens">Token 监控</a>
<a href="./service">服务状态</a>
<a href="../health">健康检查</a>
```

**原理**：

```
浏览器访问：https://example.com/ops/tokens
当前 URL 基础：/ops/

相对路径解析：
- "tokens"      → /ops/tokens
- "./service"   → /ops/service
- "../health"   → /health
```

**JavaScript 同理**：

```javascript
// ✅ 方案 A：相对路径（推荐）
const API_BASE = '';
fetch(`${API_BASE}/api/token/stats`);  // → /ops/api/token/stats

// ✅ 方案 B：从服务端注入（灵活）
const API_BASE = '{{ request.scope.root_path }}';
fetch(`${API_BASE}/api/token/stats`);

// ❌ 错误：硬编码
fetch(`/ops/api/token/stats`);  // 改路径时要改代码
```

### Nginx 配置

```nginx
location /ops/ {
    # 关键：末尾 / 会剥离 /ops 前缀
    proxy_pass http://127.0.0.1:19100/;
    
    # 标准 header
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # 可选：传递前缀给后端
    proxy_set_header X-Forwarded-Prefix /ops;
}
```

**关键点**：`proxy_pass` 末尾的 `/` 会**剥离** `location` 匹配的前缀。

- 浏览器请求：`/ops/tokens`
- Nginx 转发：`/tokens`（剥离了 `/ops`）
- FastAPI 路由：`/tokens` ✅ 匹配成功

**结果**：✅ 200 OK，所有链接正常工作。

**踩坑时间**：~10 分钟（找到正确方案）

---

## 完整方案对比

| 方案 | 复杂度 | 扩展性 | 推荐场景 |
|------|--------|--------|----------|
| **相对路径** | ⭐ | ⭐⭐⭐ | 内部工具、运维面板 |
| `root_path` + `url_for()` | ⭐⭐⭐ | ⭐⭐ | 公开 API、多租户 SaaS |
| Nginx 重定向 | ⭐⭐ | ⭐ | **不推荐** |
| Subdomain | ⭐⭐ | ⭐⭐⭐ | 大型系统、多产品 |

**结论**：内部工具/运维面板，**无脑用相对路径**，最简单。

---

## 改路径时的修改点

从 `/ops/` 改到 `/panel/`：

| 文件 | 修改内容 |
|------|----------|
| Nginx | `location /ops/` → `location /panel/` |
| Nginx | `X-Forwarded-Prefix /ops` → `X-Forwarded-Prefix /panel` |
| 模板 | **无需修改**（相对路径自动适配） |
| JS | **无需修改**（相对路径自动适配） |
| FastAPI | **无需修改**（路由不变） |

**这就是相对路径的魅力**：改路径时，只需改 Nginx 配置。

---

## 测试清单

部署后验证：

```bash
# 1. 测试所有 /ops/ 链接（应该 200 或 401）
for path in /ops/ /ops/tokens /ops/service; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "https://example.com$path")
    echo "$path -> $code"
done

# 2. 测试简写链接（应该 404，没有重定向）
for path in /tokens /service /health; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "https://example.com$path")
    echo "$path -> $code (应该 404)"
done

# 3. 测试页面内链接（检查 href 属性）
curl -s "https://example.com/ops/tokens" | grep -oE 'href="[^"]*"'
# 输出应该是：href="tokens" href="./service" ...（相对路径）

# 4. 测试 API 端点
curl -s "https://example.com/ops/api/token/stats" | jq .
```

---

## 框架特定注意事项

### FastAPI

- `root_path` 只影响 `url_for()` 生成的 URL，不影响实际路由
- 如果用相对路径，**不要设置** `root_path`
- 如果需要用 `url_for()`，确保 Nginx 传递 `X-Forwarded-Prefix` 并配置 `root_path`

### Flask

```python
# 使用 APPLICATION_ROOT 或相对路径
app.config['APPLICATION_ROOT'] = '/ops'  # 影响 session cookie 路径
```

### Express

```javascript
// 使用 app.set('base path') 或相对路径
app.use('/ops', router);  // 路由注册时指定前缀
```

### React/Vue 前端

```javascript
// vite.config.js 或 webpack.config.js
export default {
  base: '/ops/',  // 构建时注入基础路径
}
```

---

## 总结

### 核心要点

1. **Nginx `proxy_pass` 末尾的 `/` 会剥离 `location` 前缀**
2. **相对路径自动适配当前 URL，改路径时无需改代码**
3. **`root_path` 只影响生成的 URL，不影响路由匹配**
4. **内部工具无脑用相对路径，最简单**

### 踩坑时间线

| 阶段 | 方案 | 时间 | 结果 |
|------|------|------|------|
| 1 | `root_path` + `url_for()` | ~2h | ❌ 404 |
| 2 | Nginx 重定向 | ~30min | ⚠️ 能用但脏 |
| 3 | 相对路径 | ~10min | ✅ 200 OK |

### 最终配置

**Nginx**：
```nginx
location /ops/ {
    proxy_pass http://127.0.0.1:19100/;  # 末尾 / 关键！
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Prefix /ops;  # 可选
}
```

**FastAPI**：
```python
app = FastAPI(title="Ops Panel")  # 无 root_path
```

**模板**：
```html
<a href="tokens">Token 监控</a>  <!-- 相对路径 -->
<script>
const API_BASE = '';  // 相对路径
fetch(`${API_BASE}/api/token/stats`);
</script>
```

---

## 相关文档

- [Nginx proxy_pass 文档](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass)
- [FastAPI Behind a Proxy](https://fastapi.tiangolo.com/advanced/behind-a-proxy/)
- [ASGI Root Path](https://asgi.readthedocs.io/en/latest/specs/www.html#root-path)
- [X-Forwarded-Prefix 标准](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-Prefix)

---

**完**

*如果这篇文章帮到了你，欢迎分享给同样在踩坑的朋友。* 🦐

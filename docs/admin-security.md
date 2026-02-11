# `/keystatic` 管理端安全方案

`/keystatic` 是后台编辑入口，不应被公开索引或匿名访问。

## 建议策略（按优先级）

1. **至少启用一种访问控制**
   - Basic Auth（最简单）
   - IP allowlist（办公网/固定出口）
   - SSO / 反向代理鉴权（企业场景）
2. **禁止搜索引擎索引**
   - 返回 `X-Robots-Tag: noindex, nofollow, noarchive`
   - 可选再配 `robots.txt` 拒绝 `/keystatic`
3. **限制管理端请求频率**（可选）
4. **只在 HTTPS 下开放**

## Nginx 配置片段（推荐，静态站点 + Keystatic Node 服务反代）

```nginx
# 可放在 server {} 内

# 1) Keystatic UI
location ^~ /keystatic/ {
    # 基础认证（推荐）
    auth_basic "Restricted Admin";
    auth_basic_user_file /etc/nginx/.htpasswd_keystatic;

    # 可选：IP 白名单（二选一或叠加）
    # allow 1.2.3.4;
    # allow 10.0.0.0/8;
    # deny all;

    add_header X-Robots-Tag "noindex, nofollow, noarchive" always;

    proxy_pass http://127.0.0.1:4321/keystatic/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

# 2) Keystatic API（OAuth + 内容写入接口）
location ^~ /api/keystatic/ {
    auth_basic "Restricted Admin";
    auth_basic_user_file /etc/nginx/.htpasswd_keystatic;

    add_header X-Robots-Tag "noindex, nofollow, noarchive" always;

    proxy_pass http://127.0.0.1:4321/api/keystatic/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

## robots.txt（可选）

```txt
User-agent: *
Disallow: /keystatic
Disallow: /api/keystatic
```

## 安全注意事项

- 若启用 GitHub mode，请确保 GitHub App 回调地址与线上域名一致。
- `KEYSTATIC_SECRET` 必须是强随机、长度 ≥32 字符，并定期轮换。
- 不要把 `KEYSTATIC_GITHUB_CLIENT_SECRET` 写入 git。
- 若走 Basic Auth，请配合 fail2ban / rate limit，降低暴力尝试风险。

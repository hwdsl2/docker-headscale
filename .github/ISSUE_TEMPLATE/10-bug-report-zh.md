---
name: 错误报告
about: 请使用这个模板来提交 bug
title: ''
labels: ''
assignees: ''

---
**任务列表**

- [ ] 我已阅读[自述文件](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh.md)或相关章节
- [ ] 我搜索了已有的 [Issues](https://github.com/hwdsl2/docker-headscale/issues?q=is%3Aissue)
- [ ] 这个问题是关于 Headscale Docker 镜像/配置，而不只是 Headscale 或 Tailscale 客户端本身

<!---
如果你确认问题属于上游项目本身，请考虑在相应上游项目提交 issue：[Headscale](https://github.com/juanfont/headscale)。
--->

**问题描述**
使用清楚简明的语言描述这个问题。

**重现步骤**
重现该问题的步骤：

1. ...
2. ...

**期待的正确结果**
简要描述你期望发生的结果。

**服务器环境**
- Docker 主机操作系统: [例如 Ubuntu 24.04]
- 服务提供商（如果适用）: [例如 AWS, GCP, 家用服务器]
- CPU 架构: [例如 amd64, arm64]
- 镜像/标签: [例如 `hwdsl2/headscale-server:latest`]
- 启动方式: [docker run / docker compose / 其它]
- `HS_SERVER_URL` 值格式: [只写域名格式；需要时移除私有值]
- TLS / 反向代理配置: [Caddy / nginx / 其它 / 无]

**配置**
发布前请删除 secrets、密钥和私有 URL。

- 修改过的 env 文件或变量: [vpn.env / `-e` / compose `environment`]
- Docker run 或 compose 修改：
- `docker exec headscale hs_manage --help` 输出或相关 `hs_manage` 命令输出：

**客户端信息**
- 设备: [例如 iPhone 15, Windows laptop]
- 操作系统: [例如 iOS 17, Windows 11]
- Tailscale 客户端应用/版本：
- 节点注册或预授权密钥行为：

**日志**
请添加相关日志，并删除敏感信息。

```bash
docker logs headscale
```

如果使用 Docker Compose，也可以包含：

```bash
docker compose logs headscale
```

**其它信息**
添加关于该问题的其它信息。

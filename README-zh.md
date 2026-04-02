[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 在 Docker 上运行 Headscale 服务器

[![Build Status](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml)

一个用于运行 [Headscale](https://github.com/juanfont/headscale) 服务器的 Docker 镜像。Headscale 是 Tailscale 协调服务器的自托管开源实现。使用官方 Tailscale 客户端应用连接所有设备，由你自己的服务器掌控一切。

- 首次启动时自动生成服务器配置和预授权密钥
- 通过辅助脚本（`hs_manage`）管理用户、节点和预授权密钥
- 支持 MagicDNS，实现网络内主机名无缝解析
- 使用 Docker 卷实现数据持久化
- 多架构支持：`linux/amd64`、`linux/arm64`

**另提供：** [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh.md) 和 [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh.md) 的 Docker 镜像。

## 快速开始

### 前提条件

强烈建议使用具有域名和 TLS 证书的可公开访问的服务器。请参阅 [TLS 与反向代理](#tls-与反向代理) 了解配置选项。

### 使用 Docker

创建 `vpn.env` 文件。`HS_SERVER_URL` 是 Tailscale 客户端用于连接到你的服务器的 HTTPS URL。有关所有选项，请参阅[环境变量](#环境变量)。

```
HS_SERVER_URL=https://hs.example.com
```

运行容器：

```bash
docker run \
  --name headscale \
  --restart=always \
  -p 127.0.0.1:8080:8080/tcp \
  -p 127.0.0.1:9090:9090/tcp \
  -v headscale-data:/var/lib/headscale \
  -v ./vpn.env:/vpn.env:ro \
  -d hwdsl2/headscale-server
```

> **注：** 使用上述命令时，端口 `8080` 仅绑定到本地主机。需要在宿主机上运行一个处理 TLS 并将流量转发到 `127.0.0.1:8080` 的反向代理，Tailscale 客户端才能连接。请参阅 [TLS 与反向代理](#tls-与反向代理)。如需直接对外发布端口，请将 `127.0.0.1:8080:8080` 替换为 `8080:8080`。

首次启动时，容器将：
1. 根据环境变量生成服务器配置
2. 创建初始用户（默认：`admin`）
3. 将**可重复使用的预授权密钥**输出到容器日志

从日志中获取初始预授权密钥：

```bash
docker logs headscale
```

使用官方 [Tailscale 客户端](https://tailscale.com/download)连接设备：

```bash
tailscale up --login-server https://hs.example.com --authkey <日志中的密钥>
```

### 使用 Docker Compose

```bash
cp vpn.env.example vpn.env
nano vpn.env        # 至少设置 HS_SERVER_URL
docker compose up -d
docker compose logs headscale
```

示例 `docker-compose.yml`（已包含在内）：

```yaml
services:
  headscale:
    image: hwdsl2/headscale-server
    container_name: headscale
    restart: always
    ports:
      - "8080:8080/tcp"
    volumes:
      - headscale-data:/var/lib/headscale
      - ./vpn.env:/vpn.env:ro

volumes:
  headscale-data:
```

另外，你也可以在不使用 Docker 的情况下[安装 Headscale](https://github.com/hwdsl2/headscale-install/blob/main/README-zh.md)。要了解更多有关如何使用本镜像的信息，请继续阅读以下部分。

## 下载

从 [Docker Hub 镜像仓库](https://hub.docker.com/r/hwdsl2/headscale-server/)获取镜像：

```bash
docker pull hwdsl2/headscale-server
```

或从 [Quay.io](https://quay.io/repository/hwdsl2/headscale-server) 下载：

```bash
docker pull quay.io/hwdsl2/headscale-server
docker image tag quay.io/hwdsl2/headscale-server hwdsl2/headscale-server
```

支持平台：`linux/amd64` 和 `linux/arm64`。

## 环境变量

所有变量均为可选项。`HS_SERVER_URL` 强烈建议在生产环境中设置。

| 变量 | 默认值 | 说明 |
|---|---|---|
| `HS_SERVER_URL` | 自动检测 | Tailscale 客户端连接的 URL（例如 `https://hs.example.com`）。必须使用 HTTPS 以确保客户端完整功能。 |
| `HS_LISTEN_PORT` | `8080` | 服务器监听的 TCP 端口。 |
| `HS_METRICS_PORT` | `9090` | Prometheus 指标端口。设置为空以禁用。 |
| `HS_BASE_DOMAIN` | `headscale.internal` | MagicDNS 主机名的基础域名（例如 `myhost.headscale.internal`）。不得与 `HS_SERVER_URL` 中的主机名相同或为其父域名（例如若 `HS_SERVER_URL=https://hs.example.com`，则不要使用 `example.com`）。 |
| `HS_USERNAME` | `admin` | 初始设置时创建的第一个用户名称。 |
| `HS_DNS_SRV1` | `1.1.1.1` | 通过 MagicDNS 推送给客户端的主 DNS 服务器，支持 IPv4 或 IPv6。 |
| `HS_DNS_SRV2` | `1.0.0.1` | 通过 MagicDNS 推送给客户端的备用 DNS 服务器。 |
| `HS_LOG_LEVEL` | `info` | 日志级别：`panic`、`fatal`、`error`、`warn`、`info`、`debug`、`trace`。 |

每次容器启动时会重新生成配置文件。修改设置时，更新 `vpn.env` 并重启容器即可。env 文件以绑定挂载方式挂载到容器中，每次重启时自动读取更改，无需重新创建容器。

## 客户端配置

有关连接客户端的说明，请参阅 Headscale 文档：

- [Android](https://headscale.net/stable/usage/connect/android/)
- [Apple（iOS / macOS）](https://headscale.net/stable/usage/connect/apple/)
- [Windows](https://headscale.net/stable/usage/connect/windows/)

## TLS 与反向代理

Tailscale 客户端在使用 HTTPS 时效果最佳。推荐的配置是在 Headscale 前运行一个负责处理 TLS 终止的反向代理，然后将 `HS_SERVER_URL` 设置为你的 HTTPS URL。

在反向代理中使用以下地址之一来连接 Headscale 容器：

- **`headscale:8080`** — 如果反向代理作为容器运行在与 Headscale **相同的 Docker 网络**中（例如，在同一个 `docker-compose.yml` 中定义）。Docker 会自动解析容器名称。
- **`127.0.0.1:8080`** — 如果反向代理运行在**宿主机上**，且端口 `8080` 已发布（默认 `docker-compose.yml` 会发布该端口）。

> **注意：** 请勿使用通过 `docker inspect` 获取的容器内部 IP 地址。该地址在每次重新创建容器时都会改变。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 镜像](https://hub.docker.com/_/caddy)）的示例**（通过 Let's Encrypt 自动申请 TLS，反向代理在相同的 Docker 网络中）：

`Caddyfile`：
```
hs.example.com {
  reverse_proxy headscale:8080
}
```

**使用 nginx 的示例**（反向代理在宿主机上）：

```nginx
server {
  listen 443 ssl;
  server_name hs.example.com;

  ssl_certificate     /path/to/cert.pem;
  ssl_certificate_key /path/to/key.pem;

  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 3600s;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
```

在 `vpn.env` 中设置 `HS_SERVER_URL=https://hs.example.com` 并重启容器。

**防火墙中需要开放的端口：**

| 端口 | 协议 | 用途 |
|---|---|---|
| `8080` | TCP | Headscale 协调服务器（或反向代理端口） |
| `443` | TCP | HTTPS（使用反向代理时） |
| `9090` | TCP | Prometheus 指标（可选，默认仅供内部使用） |

## 管理服务器

使用 `hs_manage` 辅助脚本从宿主机管理用户和节点，无需进入容器。

**按节点密钥注册节点：**

```bash
docker exec headscale hs_manage --registernode <key> --user admin
```

**添加用户：**

```bash
docker exec headscale hs_manage --adduser alice
```

**删除用户：**

```bash
docker exec -it headscale hs_manage --deleteuser alice
# 或跳过确认提示：
docker exec headscale hs_manage --deleteuser alice --yes
```

**为用户创建预授权密钥：**

```bash
docker exec headscale hs_manage --createkey --user alice
```

**列出用户：**

```bash
docker exec headscale hs_manage --listusers
```

**列出所有已注册节点：**

```bash
docker exec headscale hs_manage --listnodes
```

**列出特定用户的节点：**

```bash
docker exec headscale hs_manage --listnodes --user alice
```

**按 ID 删除节点：**

```bash
docker exec -it headscale hs_manage --deletenode 3
# 或跳过确认提示：
docker exec headscale hs_manage --deletenode 3 --yes
```

**列出所有预授权密钥：**

```bash
docker exec headscale hs_manage --listkeys
```

**显示帮助：**

```bash
docker exec headscale hs_manage --help
```

也可使用 `docker exec headscale headscale <命令>` 直接运行 Headscale 命令。运行 `docker exec headscale headscale -h` 或参阅 [Headscale 文档](https://headscale.net/) 查看可用命令。

## 更新 Docker 镜像

要更新 Docker 镜像和容器，首先[下载](#下载)最新版本：

```bash
docker pull hwdsl2/headscale-server
```

如果 Docker 镜像已是最新版本，将显示：

```
Status: Image is up to date for hwdsl2/headscale-server:latest
```

否则将下载最新版本。按照[快速开始](#快速开始)中的说明删除并重新创建容器。数据保存在 `headscale-data` 卷中。

## 授权协议

**注：** 预构建镜像中的软件组件（如 Headscale）遵循各自版权持有者所选择的相应许可证。对于任何预构建镜像的使用，镜像用户有责任确保其使用符合镜像中所包含的所有软件的相关许可证。

Copyright (C) 2026 Lin Song   
本作品依据 [MIT 许可证](https://opensource.org/licenses/MIT)授权。

**Headscale** 的版权归 Juan Font 所有（2020 年），遵循 [BSD 3-Clause 许可证](https://github.com/juanfont/headscale/blob/main/LICENSE)。

Tailscale® 是 Tailscale Inc. 的注册商标。本项目与 Tailscale Inc. 无关联，亦未获其背书。
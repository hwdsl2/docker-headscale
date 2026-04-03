[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 在 Docker 上運行 Headscale 伺服器

[![Build Status](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

一個用於運行 [Headscale](https://github.com/juanfont/headscale) 伺服器的 Docker 映像檔。Headscale 是 Tailscale 協調伺服器的自託管開源實作。使用官方 Tailscale 客戶端應用程式連線所有裝置，由你自己的伺服器掌控一切。

- 首次啟動時自動產生伺服器設定和預授權金鑰
- 透過輔助腳本（`hs_manage`）管理使用者、節點和預授權金鑰
- 支援 MagicDNS，實現網路內主機名稱無縫解析
- 使用 Docker 卷實現資料持久化
- 多架構支援：`linux/amd64`、`linux/arm64`

**另提供：** [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh-Hant.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh-Hant.md) 與 [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh-Hant.md) 的 Docker 映像。

## 快速開始

### 前置條件

強烈建議使用具有網域名稱和 TLS 憑證的可公開存取伺服器。請參閱 [TLS 與反向代理](#tls-與反向代理) 了解設定選項。

### 使用 Docker

建立 `vpn.env` 檔案。`HS_SERVER_URL` 是 Tailscale 客戶端用於連線至你的伺服器的 HTTPS URL。有關所有選項，請參閱[環境變數](#環境變數)。

```
HS_SERVER_URL=https://hs.example.com
```

執行容器：

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

> **注：** 使用上述命令時，連接埠 `8080` 僅綁定至本地主機。需要在宿主機上運行一個處理 TLS 並將流量轉發至 `127.0.0.1:8080` 的反向代理，Tailscale 客戶端才能連線。請參閱 [TLS 與反向代理](#tls-與反向代理)。如需直接對外公開連接埠，請將 `127.0.0.1:8080:8080` 替換為 `8080:8080`。

首次啟動時，容器將：
1. 根據環境變數產生伺服器設定
2. 建立初始使用者（預設：`admin`）
3. 將**可重複使用的預授權金鑰**輸出至容器日誌

從日誌中取得初始預授權金鑰：

```bash
docker logs headscale
```

使用官方 [Tailscale 客戶端](https://tailscale.com/download)連線裝置：

```bash
tailscale up --login-server https://hs.example.com --authkey <日誌中的金鑰>
```

### 使用 Docker Compose

```bash
cp vpn.env.example vpn.env
nano vpn.env        # 至少設定 HS_SERVER_URL
docker compose up -d
docker compose logs headscale
```

範例 `docker-compose.yml`（已包含在內）：

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

另外，你也可以在不使用 Docker 的情況下[安裝 Headscale](https://github.com/hwdsl2/headscale-install/blob/main/README-zh-Hant.md)。若要了解更多關於如何使用本映像檔的資訊，請繼續閱讀以下部分。

## 下載

從 [Docker Hub 映像檔倉庫](https://hub.docker.com/r/hwdsl2/headscale-server/)取得映像檔：

```bash
docker pull hwdsl2/headscale-server
```

或從 [Quay.io](https://quay.io/repository/hwdsl2/headscale-server) 下載：

```bash
docker pull quay.io/hwdsl2/headscale-server
docker image tag quay.io/hwdsl2/headscale-server hwdsl2/headscale-server
```

支援平台：`linux/amd64` 和 `linux/arm64`。

## 環境變數

所有變數均為選用。`HS_SERVER_URL` 強烈建議在正式環境中設定。

| 變數 | 預設值 | 說明 |
|---|---|---|
| `HS_SERVER_URL` | 自動偵測 | Tailscale 客戶端連線的 URL（例如 `https://hs.example.com`）。必須使用 HTTPS 以確保客戶端完整功能。 |
| `HS_LISTEN_PORT` | `8080` | 伺服器監聽的 TCP 連接埠。 |
| `HS_METRICS_PORT` | `9090` | Prometheus 指標連接埠。設定為空以停用。 |
| `HS_BASE_DOMAIN` | `headscale.internal` | MagicDNS 主機名稱的基礎網域（例如 `myhost.headscale.internal`）。不得與 `HS_SERVER_URL` 中的主機名稱相同或為其父網域（例如若 `HS_SERVER_URL=https://hs.example.com`，則不要使用 `example.com`）。 |
| `HS_USERNAME` | `admin` | 初始設定時建立的第一個使用者名稱。 |
| `HS_DNS_SRV1` | `1.1.1.1` | 透過 MagicDNS 推送給客戶端的主要 DNS 伺服器，支援 IPv4 或 IPv6。 |
| `HS_DNS_SRV2` | `1.0.0.1` | 透過 MagicDNS 推送給客戶端的次要 DNS 伺服器。 |
| `HS_LOG_LEVEL` | `info` | 日誌詳細程度：`panic`、`fatal`、`error`、`warn`、`info`、`debug`、`trace`。 |

每次容器啟動時會重新產生設定檔。修改設定時，更新 `vpn.env` 並重新啟動容器即可。env 檔案以綁定掛載方式掛載至容器中，每次重新啟動時自動讀取變更，無需重新建立容器。

## 客戶端設定

有關連線客戶端的說明，請參閱 Headscale 文件：

- [Android](https://headscale.net/stable/usage/connect/android/)
- [Apple（iOS / macOS）](https://headscale.net/stable/usage/connect/apple/)
- [Windows](https://headscale.net/stable/usage/connect/windows/)

## TLS 與反向代理

Tailscale 客戶端在使用 HTTPS 時效果最佳。建議的設定是在 Headscale 前運行一個負責處理 TLS 終止的反向代理，然後將 `HS_SERVER_URL` 設定為你的 HTTPS URL。

在反向代理中使用以下其中一個位址來連線 Headscale 容器：

- **`headscale:8080`** — 如果反向代理作為容器運行在與 Headscale **相同的 Docker 網路**中（例如，在同一個 `docker-compose.yml` 中定義）。Docker 會自動解析容器名稱。
- **`127.0.0.1:8080`** — 如果反向代理運行在**宿主機上**，且連接埠 `8080` 已發布（預設 `docker-compose.yml` 會發布該連接埠）。

> **注意：** 請勿使用透過 `docker inspect` 取得的容器內部 IP 位址。該位址在每次重新建立容器時都會改變。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 映像檔](https://hub.docker.com/_/caddy)）的範例**（透過 Let's Encrypt 自動申請 TLS，反向代理在相同的 Docker 網路中）：

`Caddyfile`：
```
hs.example.com {
  reverse_proxy headscale:8080
}
```

**使用 nginx 的範例**（反向代理在宿主機上）：

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

在 `vpn.env` 中設定 `HS_SERVER_URL=https://hs.example.com` 並重新啟動容器。

**防火牆中需要開放的連接埠：**

| 連接埠 | 協定 | 用途 |
|---|---|---|
| `8080` | TCP | Headscale 協調伺服器（或反向代理連接埠） |
| `443` | TCP | HTTPS（使用反向代理時） |
| `9090` | TCP | Prometheus 指標（選用，預設僅供內部使用） |

## 管理伺服器

使用 `hs_manage` 輔助腳本從宿主機管理使用者和節點，無需進入容器。

**依節點金鑰註冊節點：**

```bash
docker exec headscale hs_manage --registernode <key> --user admin
```

**新增使用者：**

```bash
docker exec headscale hs_manage --adduser alice
```

**刪除使用者：**

```bash
docker exec -it headscale hs_manage --deleteuser alice
# 或略過確認提示：
docker exec headscale hs_manage --deleteuser alice --yes
```

**為使用者建立預授權金鑰：**

```bash
docker exec headscale hs_manage --createkey --user alice
```

**列出使用者：**

```bash
docker exec headscale hs_manage --listusers
```

**列出所有已註冊節點：**

```bash
docker exec headscale hs_manage --listnodes
```

**列出特定使用者的節點：**

```bash
docker exec headscale hs_manage --listnodes --user alice
```

**依 ID 刪除節點：**

```bash
docker exec -it headscale hs_manage --deletenode 3
# 或略過確認提示：
docker exec headscale hs_manage --deletenode 3 --yes
```

**列出所有預授權金鑰：**

```bash
docker exec headscale hs_manage --listkeys
```

**顯示說明：**

```bash
docker exec headscale hs_manage --help
```

也可使用 `docker exec headscale headscale <命令>` 直接執行 Headscale 命令。執行 `docker exec headscale headscale -h` 或參閱 [Headscale 文件](https://headscale.net/) 查看可用命令。

## 更新 Docker 映像檔

要更新 Docker 映像檔和容器，請先[下載](#下載)最新版本：

```bash
docker pull hwdsl2/headscale-server
```

如果 Docker 映像檔已是最新版本，將顯示：

```
Status: Image is up to date for hwdsl2/headscale-server:latest
```

否則將下載最新版本。依照[快速開始](#快速開始)中的說明刪除並重新建立容器。資料保存在 `headscale-data` 卷中。

## 授權條款

**注：** 預建映像檔中的軟體元件（如 Headscale）遵循各自版權持有者所選擇的相應授權條款。對於任何預建映像檔的使用，映像檔使用者有責任確保其使用符合映像檔中所有軟體的相關授權條款。

Copyright (C) 2026 Lin Song   
本作品依據 [MIT 授權條款](https://opensource.org/licenses/MIT)授權。

**Headscale** 的版權歸 Juan Font 所有（2020 年），遵循 [BSD 3-Clause 授權條款](https://github.com/juanfont/headscale/blob/main/LICENSE)。

Tailscale® 是 Tailscale Inc. 的注冊商標。本專案與 Tailscale Inc. 無關聯，亦未獲其背書。
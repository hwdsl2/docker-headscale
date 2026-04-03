[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Headscale Server on Docker

[![Build Status](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-headscale/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

A Docker image to run a [Headscale](https://github.com/juanfont/headscale) server — a self-hosted, open-source implementation of the Tailscale coordination server. Connect all your devices using the official Tailscale client apps, with your own server in control.

- Automatically generates server configuration and a pre-auth key on first start
- Manage users, nodes and pre-auth keys via a helper script (`hs_manage`)
- MagicDNS support for seamless hostname resolution across your network
- Persistent data via a Docker volume
- Multi-arch: `linux/amd64`, `linux/arm64`

**Also available:** Docker images for [WireGuard](https://github.com/hwdsl2/docker-wireguard), [OpenVPN](https://github.com/hwdsl2/docker-openvpn), and [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server).

## Quick start

### Prerequisite

A publicly reachable server with a domain name and TLS certificate is strongly recommended. See [TLS and reverse proxy](#tls-and-reverse-proxy) for setup options.

### Using Docker

Create a `vpn.env` file. `HS_SERVER_URL` is the HTTPS URL that Tailscale clients use to connect to your server. See [Environment variables](#environment-variables) for all options.

```
HS_SERVER_URL=https://hs.example.com
```

Run the container:

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

> **Note:** With the above command, port `8080` is bound to localhost only. A reverse proxy on the host that handles TLS and forwards to `127.0.0.1:8080` is required for Tailscale clients to connect. See [TLS and reverse proxy](#tls-and-reverse-proxy). To expose the port directly instead, replace `127.0.0.1:8080:8080` with `8080:8080`.

On first start, the container will:
1. Generate the server configuration from your environment variables
2. Create the initial user (default: `admin`)
3. Print a **reusable pre-auth key** to the container logs

Retrieve the initial pre-auth key from the logs:

```bash
docker logs headscale
```

Connect a device using the official [Tailscale client](https://tailscale.com/download):

```bash
tailscale up --login-server https://hs.example.com --authkey <key-from-logs>
```

### Using Docker Compose

```bash
cp vpn.env.example vpn.env
nano vpn.env        # Set HS_SERVER_URL at minimum
docker compose up -d
docker compose logs headscale
```

Example `docker-compose.yml` (already included):

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

Alternatively, you may [set up Headscale without Docker](https://github.com/hwdsl2/headscale-install). To learn more about how to use this image, read the sections below.

## Download

Get the trusted build from the [Docker Hub registry](https://hub.docker.com/r/hwdsl2/headscale-server/):

```bash
docker pull hwdsl2/headscale-server
```

Alternatively, you may download from [Quay.io](https://quay.io/repository/hwdsl2/headscale-server):

```bash
docker pull quay.io/hwdsl2/headscale-server
docker image tag quay.io/hwdsl2/headscale-server hwdsl2/headscale-server
```

Supported platforms: `linux/amd64` and `linux/arm64`.

## Environment variables

All variables are optional. `HS_SERVER_URL` is strongly recommended for production use.

| Variable | Default | Description |
|---|---|---|
| `HS_SERVER_URL` | auto-detected | URL that Tailscale clients connect to (e.g. `https://hs.example.com`). Must be HTTPS for full client functionality. |
| `HS_LISTEN_PORT` | `8080` | TCP port the server listens on. |
| `HS_METRICS_PORT` | `9090` | Prometheus metrics port. Set to empty to disable. |
| `HS_BASE_DOMAIN` | `headscale.internal` | Base domain for MagicDNS hostnames (e.g. `myhost.headscale.internal`). Must not equal or be a parent domain of the hostname in `HS_SERVER_URL` (e.g. if `HS_SERVER_URL=https://hs.example.com`, do not use `example.com`). |
| `HS_USERNAME` | `admin` | Name of the first user created on initial setup. |
| `HS_DNS_SRV1` | `1.1.1.1` | Primary DNS server pushed to clients via MagicDNS. Accepts IPv4 or IPv6. |
| `HS_DNS_SRV2` | `1.0.0.1` | Secondary DNS server pushed to clients via MagicDNS. |
| `HS_LOG_LEVEL` | `info` | Log verbosity: `panic`, `fatal`, `error`, `warn`, `info`, `debug`, `trace`. |

The configuration file is regenerated on each container start. To change a setting, update `vpn.env` and restart the container. The env file is bind-mounted into the container, so changes are picked up on every restart without recreating the container.

## Client configuration

Refer to the Headscale documentation for instructions on connecting clients:

- [Android](https://headscale.net/stable/usage/connect/android/)
- [Apple (iOS / macOS)](https://headscale.net/stable/usage/connect/apple/)
- [Windows](https://headscale.net/stable/usage/connect/windows/)

## TLS and reverse proxy

Tailscale clients work best with HTTPS. The recommended setup is to run a reverse proxy in front of Headscale that handles TLS termination, then set `HS_SERVER_URL` to your HTTPS URL.

Use one of the following addresses to reach the Headscale container from your reverse proxy:

- **`headscale:8080`** — if your reverse proxy runs as a container in the **same Docker network** as Headscale (e.g. defined in the same `docker-compose.yml`). Docker resolves the container name automatically.
- **`127.0.0.1:8080`** — if your reverse proxy runs **on the host** and port `8080` is published (the default `docker-compose.yml` publishes it).

> **Note:** Do not use the container's internal IP address obtained from `docker inspect`. That IP address changes every time the container is recreated.

**Example with [Caddy](https://caddyserver.com/docs/) ([Docker image](https://hub.docker.com/_/caddy))** (automatic TLS via Let's Encrypt, reverse proxy in the same Docker network):

`Caddyfile`:
```
hs.example.com {
  reverse_proxy headscale:8080
}
```

**Example with nginx** (reverse proxy on the host):

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

Set `HS_SERVER_URL=https://hs.example.com` in your `vpn.env` and restart the container.

**Ports to open in your firewall:**

| Port | Protocol | Purpose |
|---|---|---|
| `8080` | TCP | Headscale coordination server (or your reverse proxy port) |
| `443` | TCP | HTTPS (if using a reverse proxy) |
| `9090` | TCP | Prometheus metrics (optional, internal use only by default) |

## Managing the server

Use the `hs_manage` helper to manage users and nodes from the host without entering the container.

**Register a node by its node key:**

```bash
docker exec headscale hs_manage --registernode <key> --user admin
```

**Add a user:**

```bash
docker exec headscale hs_manage --adduser alice
```

**Delete a user:**

```bash
docker exec -it headscale hs_manage --deleteuser alice
# Or skip the confirmation prompt:
docker exec headscale hs_manage --deleteuser alice --yes
```

**Create a pre-auth key for a user:**

```bash
docker exec headscale hs_manage --createkey --user alice
```

**List users:**

```bash
docker exec headscale hs_manage --listusers
```

**List all registered nodes:**

```bash
docker exec headscale hs_manage --listnodes
```

**List nodes for a specific user:**

```bash
docker exec headscale hs_manage --listnodes --user alice
```

**Delete a node by ID:**

```bash
docker exec -it headscale hs_manage --deletenode 3
# Or skip the confirmation prompt:
docker exec headscale hs_manage --deletenode 3 --yes
```

**List all pre-auth keys:**

```bash
docker exec headscale hs_manage --listkeys
```

**Show help:**

```bash
docker exec headscale hs_manage --help
```

You can also run Headscale commands directly using `docker exec headscale headscale <command>`. Run `docker exec headscale headscale -h` or refer to the [Headscale documentation](https://headscale.net/) for available commands.

## Update Docker image

To update the Docker image and container, first [download](#download) the latest version:

```bash
docker pull hwdsl2/headscale-server
```

If the Docker image is already up to date, you should see:

```
Status: Image is up to date for hwdsl2/headscale-server:latest
```

Otherwise, it will download the latest version. Remove and re-create the container using instructions from [Quick start](#quick-start). Your data is preserved in the `headscale-data` volume.

## License

**Note:** The software components inside the pre-built image (such as Headscale) are under the respective licenses chosen by their respective copyright holders. As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**Headscale** is Copyright (c) 2020, Juan Font, and is distributed under the [BSD 3-Clause License](https://github.com/juanfont/headscale/blob/main/LICENSE).

Tailscale® is a registered trademark of Tailscale Inc. This project is not affiliated with or endorsed by Tailscale Inc.
---
name: Bug report
about: Tell us about a problem you are experiencing
title: ''
labels: ''
assignees: ''

---
**Checklist**

- [ ] I read the [README](https://github.com/hwdsl2/docker-headscale/blob/main/README.md) or the relevant section
- [ ] I searched existing [Issues](https://github.com/hwdsl2/docker-headscale/issues?q=is%3Aissue)
- [ ] This issue is about the Headscale Docker image/config, not only Headscale or a Tailscale client itself

<!---
If you found a reproducible bug in the upstream project itself, consider opening an issue upstream: [Headscale](https://github.com/juanfont/headscale).
--->

**Describe the issue**
A clear and concise description of the problem.

**To Reproduce**
Steps to reproduce the behavior:

1. ...
2. ...

**Expected behavior**
A clear and concise description of what you expected to happen.

**Server environment**
- Docker host OS: [e.g. Ubuntu 24.04]
- Hosting provider (if applicable): [e.g. AWS, GCP, home server]
- CPU architecture: [e.g. amd64, arm64]
- Image/tag: [e.g. `hwdsl2/headscale-server:latest`]
- Start method: [docker run / docker compose / other]
- `HS_SERVER_URL` value format: [domain only; remove private values if needed]
- TLS / reverse proxy setup: [Caddy / nginx / other / none]

**Configuration**
Remove secrets, keys and private URLs before posting.

- Env file or variables changed: [vpn.env / `-e` / compose `environment`]
- Docker run or compose changes:
- `docker exec headscale hs_manage --help` output or related `hs_manage` command output:

**Client information**
- Device: [e.g. iPhone 15, Windows laptop]
- OS: [e.g. iOS 17, Windows 11]
- Tailscale client app/version:
- Node registration or pre-auth key behavior:

**Logs**
Add relevant logs with secrets removed.

```bash
docker logs headscale
```

If using Docker Compose, you can also include:

```bash
docker compose logs headscale
```

**Additional context**
Add any other context about the problem here.

# Contributing

Thanks for helping improve this project. This repository maintains the Docker image for Headscale; bare-metal install script changes belong in [headscale-install](https://github.com/hwdsl2/headscale-install).

## Before You Start

- Search existing issues and pull requests.
- Keep changes focused and easy to review.
- For upstream Headscale or Tailscale client behavior, check the upstream project first.
- Do not include private keys, pre-auth keys, node keys, env secrets, database dumps, or logs with secrets.

## Pull Requests

- Update `README.md`, env examples, or compose examples when behavior changes.
- Include the Docker host OS, architecture, image tag, and start method tested.
- Note reverse proxy, TLS, and `HS_SERVER_URL` details when relevant.

## Testing

Test the smallest relevant path before opening a PR, for example:

- Build or run the image when Dockerfile/runtime behavior changes.
- Exercise user/pre-auth-key/device management paths when helper behavior changes.
- Verify container logs and Headscale startup when runtime scripts change.
- Run ShellCheck when editing shell scripts.

# Changelog

Notable changes to the Docker Headscale server are documented here.

## 2026-11-01

### Security

- Updated Headscale to 0.29.7, including the security fixes from 0.29.6.
- Update Tailscale clients to v1.104.4 or newer for client-side security
  fixes, especially when using Tailscale SSH. Updating this image does not
  update client software.

### Changed

- Metrics are served only on the configured metrics listener. Single-address
  routes inside the tailnet node address ranges are no longer served.
- Re-registering an expired tagged node requires a valid pre-auth key.
  Another user's key or login on a tagged machine creates a separate device.
- Oversized client metadata is rejected or trimmed under stricter limits.

See the upstream [0.29.6 release notes](https://github.com/juanfont/headscale/releases/tag/v0.29.6)
and [0.29.7 release notes](https://github.com/juanfont/headscale/releases/tag/v0.29.7).

## 2026-07-09

### Added

- Added anonymous aggregate deployment/upgrade counts. Opt out with
  `HS_DISABLE_USAGE_COUNTS=1`.

## 2026-06-19

### Changed

- Updated generated configuration for Headscale 0.29.1. Node registration
  through `hs_manage --registernode` now uses the auth ID shown by
  `tailscale up`.

## Earlier notable changes

- Added AMD64 and ARM64 images with persistent Headscale state and
  environment-based configuration.
- Added user, node, and pre-auth-key management. User deletion requires
  removing the user's nodes first.
- Configuration is generated at startup from the environment file. Back up
  persistent state before changing Headscale versions; an older image alone
  does not guarantee database rollback.

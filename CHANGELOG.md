# Changelog

Notable changes to the Docker Headscale server are documented here.

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

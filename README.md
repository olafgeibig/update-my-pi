# update-my-pi

**System update script for Raspberry Pi — Debian 12 Bookworm, ARM64**

Unified update script that covers all package managers and tools on the system. Inspired by [update-my-mac](https://github.com/olafgeibig/update-my-mac).

## Motivation

Multiple package sources (apt, npm, uv, Docker, Cargo) make system updates a patchwork. This script consolidates everything into one command.

## Features

- **Single command** — all updates at once
- **Modular** — update individual components selectively
- **Detailed logging** — transparent, timestamped logs
- **Graceful degradation** — missing tools are skipped, never aborts
- **Installable** — `--install` makes it globally available

## Components

| Module | Command | Source |
|--------|---------|--------|
| **apt** | `sudo apt update && apt upgrade` | Debian package manager |
| **npm** | `npm update --location=global` | Global Node packages |
| **uv** | `uv self update` + `uv tool upgrade --all` | Python tools (uv) |
| **Docker** | `docker system prune` | Unused containers/images |
| **Cargo** | `rustup update` | Rust toolchain (if installed) |

## Usage

```bash
# Quick update (default: apt, npm, uv, Docker)
./update-my-pi.sh

# Full update (+ Cargo, cache cleanup)
./update-my-pi.sh --full

# Individual modules
./update-my-pi.sh --apt           # apt only
./update-my-pi.sh --npm           # npm only
./update-my-pi.sh --uv            # uv only
./update-my-pi.sh --docker        # Docker prune only
./update-my-pi.sh --cargo         # Cargo (rustup) only
./update-my-pi.sh --cleanup       # Cache cleanup only

# Install globally
sudo ./update-my-pi.sh --install
# Afterwards: update-my-pi

# Help
./update-my-pi.sh --help
```

## Installation

```bash
sudo ./update-my-pi.sh --install
```

After installation, `update-my-pi` is available globally.

## Logging

- **Location:** `~/.local/share/update-my-pi/`
- **Format:** `update-YYYYMMDD_HHMMSS.log`
- **Content:** Timestamped logs of all commands with exit codes

## Requirements

- **Debian 12 (Bookworm)** or compatible
- **sudo** for apt updates
- **optional:** rustup (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)

## License

Apache-2.0

# macOS Developer Setup

One-liner to set up a fresh Mac for development.

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Zanoshky/macbook-pro-setup/refs/heads/master/setup-mac.sh)
```

### Dry Run (preview without installing)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Zanoshky/macbook-pro-setup/refs/heads/master/setup-mac.sh) --dry-run
```

### No Color

```bash
NO_COLOR=1 bash <(curl -fsSL https://raw.githubusercontent.com/Zanoshky/macbook-pro-setup/refs/heads/master/setup-mac.sh)
```

## What It Installs

| Category | Tools                                                                              |
| -------- | ---------------------------------------------------------------------------------- |
| Shell    | Oh My Zsh, zsh-autosuggestions, z, Oh My Posh, MesloLGS Nerd Font                  |
| CLI      | bash, maven, make, gnupg                                                           |
| Runtime  | SDKMAN + Java, nvm + Node.js LTS                                                   |
| Apps     | Warp, VS Code, Brave, Firefox, Postman, JetBrains Toolbox, Docker, MongoDB Compass |
| Database | MongoDB Community Edition                                                          |
| Security | ed25519 SSH key, SSH commit signing, GPG key, macOS Keychain integration           |

## What It Configures

- Git: user, SSH signing, init.defaultBranch main, global .gitignore
- SSH: ed25519 key, ssh-agent, keychain persistence
- macOS: hidden files, fast key repeat, Dock auto-hide, screenshots to ~/Desktop/Screenshots
- Fonts: MesloLGS Nerd Font auto-configured in Warp, VS Code, and Terminal.app
- Folders: ~/work, ~/private
- Rosetta 2 on Apple Silicon

## Cloning

```bash
git clone git@github.com:Zanoshky/macbook-pro-setup.git
```

## Re-running

The script is idempotent — safe to run again. It skips anything already installed and only applies what's missing.

## Logs

Every run writes to `/tmp/setup-mac-<timestamp>.log`. Check it if something fails.

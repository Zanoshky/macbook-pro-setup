#!/bin/bash
# =============================================================
# macOS Developer Setup Script
# =============================================================
# Run with: chmod +x setup-mac.sh && ./setup-mac.sh
#
# Flags:
#   --dry-run     Preview what would be installed without doing anything
#   NO_COLOR=1    Disable colored output (https://no-color.org/)
# =============================================================

DRY_RUN=false
ERRORS=()
SUCCESSES=0
STEP=0
START_TIME=$(date +%s)

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

# ---------------------------
# Ctrl+C trap — print summary even if cancelled
# ---------------------------
cleanup() {
  END_TIME=$(date +%s)
  ELAPSED=$(( END_TIME - START_TIME ))
  MINS=$(( ELAPSED / 60 ))
  SECS=$(( ELAPSED % 60 ))
  TOTAL=$(( SUCCESSES + ${#ERRORS[@]} ))

  echo ""
  echo ""
  echo -e "  ${BOLD}=============================================${RESET}"
  echo -e "  ${RED}  [✗]  Setup interrupted (Ctrl+C)${RESET}"
  echo -e "  ${BOLD}=============================================${RESET}"
  echo ""
  echo -e "  ${DIM}completed: $SUCCESSES/$TOTAL${RESET}"
  echo -e "  ${DIM}elapsed:   ${MINS}m ${SECS}s${RESET}"
  echo -e "  ${DIM}log:       $LOG_FILE${RESET}"
  echo ""
  exit 130
}
trap cleanup INT

# ---------------------------
# Color setup
# ---------------------------
if [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
  RED=""
  GREEN=""
  BOLD=""
  DIM=""
  RESET=""
else
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  BOLD="\033[1m"
  DIM="\033[2m"
  RESET="\033[0m"
fi

LOG_FILE="/tmp/setup-mac-$(date +%Y%m%d-%H%M%S).log"

ok()      { echo -e "       ${GREEN}[ok]${RESET} $1"; SUCCESSES=$((SUCCESSES + 1)); }
fail()    { echo -e "       ${RED}[✗]${RESET}  $1"; ERRORS+=("$1"); }
info()    { echo -e "       ${DIM}...${RESET}  $1"; }

section() {
  STEP=$((STEP + 1))
  echo ""
  printf -v padded "%-40s" "$1"
  echo -e "  ${BOLD}[$STEP]  $padded${RESET}"
  echo -e "  ${DIM}---------------------------------------------${RESET}"
}

# Run a command, log output, catch failures without exiting
run() {
  if $DRY_RUN; then
    info "[dry-run] $*"
    return 0
  fi
  if "$@" >> "$LOG_FILE" 2>&1; then
    return 0
  else
    fail "$1 failed (see $LOG_FILE)"
    return 1
  fi
}

# =============================================================
# Header
# =============================================================
echo ""
echo -e "  ${BOLD}=============================================${RESET}"
echo -e "  ${BOLD}  macOS Developer Setup${RESET}"
echo -e "  ${BOLD}=============================================${RESET}"
echo ""

if $DRY_RUN; then
  echo -e "  ${DIM}mode: dry-run (nothing will be installed)${RESET}"
fi

echo -e "  ${DIM}log:  $LOG_FILE${RESET}"
echo ""

# =============================================================
# Preflight: Network check
# =============================================================
info "Checking internet connectivity..."
if curl -s --max-time 5 https://github.com > /dev/null 2>&1; then
  ok "internet connection"
else
  fail "No internet connection — this script needs to download packages"
  echo ""
  exit 1
fi
echo ""
SETUP_NAME=""
SETUP_EMAIL=""

if ! $DRY_RUN; then
  # Try to pull existing values from git config
  SETUP_NAME=$(git config --global user.name 2>/dev/null || true)
  SETUP_EMAIL=$(git config --global user.email 2>/dev/null || true)

  if [ -z "$SETUP_NAME" ]; then
    read -rp "  Your full name: " SETUP_NAME
  else
    echo -e "  ${DIM}name:  $SETUP_NAME (from git config)${RESET}"
  fi

  if [ -z "$SETUP_EMAIL" ]; then
    read -rp "  Your email:     " SETUP_EMAIL
  else
    echo -e "  ${DIM}email: $SETUP_EMAIL (from git config)${RESET}"
  fi

  echo ""

  if [ -z "$SETUP_NAME" ] || [ -z "$SETUP_EMAIL" ]; then
    fail "Name and email are required for SSH key + git config"
    echo ""
    exit 1
  fi
else
  SETUP_NAME="[dry-run]"
  SETUP_EMAIL="[dry-run]"
fi

# =============================================================
# Rosetta 2 (Apple Silicon only)
# =============================================================
if [[ $(uname -m) == "arm64" ]]; then
  section "Rosetta 2"

  if /usr/bin/pgrep -q oahd 2>/dev/null; then
    ok "already installed"
  else
    info "Installing Rosetta 2 (needed by some tools on Apple Silicon)..."
    if ! $DRY_RUN; then
      softwareupdate --install-rosetta --agree-to-license >> "$LOG_FILE" 2>&1 \
        && ok "installed" || fail "Rosetta 2 install failed"
    else
      info "[dry-run] softwareupdate --install-rosetta"
    fi
  fi
fi

# =============================================================
# Xcode Command Line Tools
# =============================================================
section "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  ok "already installed"
else
  info "Installing Xcode Command Line Tools..."
  run xcode-select --install
  info "Waiting for install to finish..."
  until xcode-select -p &>/dev/null; do sleep 5; done
  ok "installed"
fi

# =============================================================
# Homebrew
# =============================================================
section "Homebrew"

if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  if ! $DRY_RUN; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    info "[dry-run] Homebrew installer"
  fi

  if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  ok "already installed"
fi

run brew update

# =============================================================
# CLI tools
# =============================================================
section "CLI Tools (bash, maven, make)"

BREW_PACKAGES=(bash maven make)

for pkg in "${BREW_PACKAGES[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    ok "$pkg"
  else
    info "Installing $pkg..."
    run brew install "$pkg" && ok "$pkg" || true
  fi
done

# Add new bash to allowed shells if not already there
if ! grep -q "/opt/homebrew/bin/bash" /etc/shells 2>/dev/null && \
   ! grep -q "/usr/local/bin/bash" /etc/shells 2>/dev/null; then
  info "Adding new bash to allowed shells (requires sudo)..."
  if ! $DRY_RUN; then
    BASH_PATH="$(brew --prefix)/bin/bash"
    echo "$BASH_PATH" | sudo tee -a /etc/shells
  fi
fi

# =============================================================
# SSH Key (ed25519)
# =============================================================
section "SSH Key (ed25519)"

SSH_KEY="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY" ]; then
  ok "key exists at $SSH_KEY"
else
  if ! $DRY_RUN; then
    mkdir -p "$HOME/.ssh"
    echo ""
    info "You'll be asked for a passphrase — this protects your key."
    info "You can leave it empty for no passphrase, but a passphrase is recommended."
    echo ""
    ssh-keygen -t ed25519 -C "$SETUP_EMAIL" -f "$SSH_KEY"
    ok "key generated"
  else
    info "[dry-run] ssh-keygen -t ed25519 -C $SETUP_EMAIL"
  fi
fi

if [ -f "$SSH_KEY" ] && ! $DRY_RUN; then
  eval "$(ssh-agent -s)" >> "$LOG_FILE" 2>&1
  ssh-add --apple-use-keychain "$SSH_KEY" >> "$LOG_FILE" 2>&1
  ok "added to ssh-agent + macOS keychain"
fi

SSH_CONFIG="$HOME/.ssh/config"
if [ -f "$SSH_KEY" ] && ! $DRY_RUN; then
  mkdir -p "$HOME/.ssh"
  if [ ! -f "$SSH_CONFIG" ] || ! grep -q "AddKeysToAgent" "$SSH_CONFIG"; then
    {
      echo ""
      echo "Host *"
      echo "  AddKeysToAgent yes"
      echo "  UseKeychain yes"
      echo "  IdentityFile $SSH_KEY"
    } >> "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    ok "~/.ssh/config configured"
  else
    ok "~/.ssh/config already set"
  fi
fi

# =============================================================
# Git config (SSH commit signing)
# =============================================================
section "Git Commit Signing (SSH)"

if ! $DRY_RUN; then
  CURRENT_FORMAT=$(git config --global gpg.format 2>/dev/null || true)

  if [ "$CURRENT_FORMAT" = "ssh" ]; then
    ok "already configured"
  else
    git config --global user.name "$SETUP_NAME"
    git config --global user.email "$SETUP_EMAIL"
    git config --global gpg.format ssh
    git config --global commit.gpgsign true
    git config --global tag.gpgsign true
    git config --global init.defaultBranch main

    if [ -f "$SSH_KEY.pub" ]; then
      git config --global user.signingkey "$SSH_KEY.pub"
      ok "signing with $SSH_KEY.pub"
      ok "init.defaultBranch = main"
    else
      fail "No SSH public key found, set user.signingkey manually"
    fi
  fi

  ALLOWED_SIGNERS="$HOME/.ssh/allowed_signers"
  if [ -f "$SSH_KEY.pub" ]; then
    if [ ! -f "$ALLOWED_SIGNERS" ] || ! grep -q "$SETUP_EMAIL" "$ALLOWED_SIGNERS"; then
      echo "$SETUP_EMAIL $(cat "$SSH_KEY.pub")" >> "$ALLOWED_SIGNERS"
      git config --global gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"
      ok "allowed_signers configured"
    else
      ok "allowed_signers already set"
    fi
  fi
else
  info "[dry-run] git config --global user.name \"$SETUP_NAME\""
  info "[dry-run] git config --global user.email \"$SETUP_EMAIL\""
  info "[dry-run] git config --global gpg.format ssh"
  info "[dry-run] git config --global commit.gpgsign true"
fi

# =============================================================
# GPG Key (for GitHub/GitLab verified emails)
# =============================================================
section "GPG Key"

if ! command -v gpg &>/dev/null; then
  info "Installing gnupg..."
  run brew install gnupg && ok "gnupg installed" || true
fi

if command -v gpg &>/dev/null || $DRY_RUN; then
  # Check if a GPG key already exists for this email
  EXISTING_GPG=$(gpg --list-secret-keys --keyid-format long "$SETUP_EMAIL" 2>/dev/null || true)

  if [ -n "$EXISTING_GPG" ]; then
    ok "GPG key already exists for $SETUP_EMAIL"
  else
    if ! $DRY_RUN; then
      info "Generating GPG key for $SETUP_EMAIL..."

      # Generate key non-interactively
      gpg --batch --gen-key <<GPGEOF
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Subkey-Type: ecdh
Subkey-Curve: cv25519
Name-Real: $SETUP_NAME
Name-Email: $SETUP_EMAIL
Expire-Date: 0
%commit
GPGEOF

      if [ $? -eq 0 ]; then
        ok "GPG key generated"
      else
        fail "GPG key generation failed"
      fi
    else
      info "[dry-run] gpg --batch --gen-key (ed25519)"
    fi
  fi

  # Export and display the public key
  if ! $DRY_RUN; then
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format long "$SETUP_EMAIL" 2>/dev/null \
      | grep -m1 "sec" | sed 's/.*\/\([A-F0-9]*\).*/\1/')

    if [ -n "$GPG_KEY_ID" ]; then
      echo ""
      info "GPG public key (add to GitHub/GitLab):"
      echo ""
      gpg --armor --export "$GPG_KEY_ID" | while IFS= read -r line; do
        echo -e "       ${DIM}$line${RESET}"
      done
      echo ""

      # Copy to clipboard
      if command -v pbcopy &>/dev/null; then
        gpg --armor --export "$GPG_KEY_ID" | pbcopy
        ok "GPG public key copied to clipboard"
      fi

      ok "key ID: $GPG_KEY_ID"
      info "SSH signing is still the default for git commits"
      info "Upload this GPG key to GitHub if your org requires it"
    fi
  fi
fi

# Global .gitignore
GLOBAL_GITIGNORE="$HOME/.gitignore_global"
if ! $DRY_RUN; then
  if [ ! -f "$GLOBAL_GITIGNORE" ]; then
    cat > "$GLOBAL_GITIGNORE" << 'EOF'
# macOS
.DS_Store
.AppleDouble
.LSOverride
._*

# IDEs
.idea/
.vscode/
*.swp
*.swo
*~

# Dependencies
node_modules/

# Environment
.env
.env.local

# Build
*.class
target/
dist/
build/
EOF
    git config --global core.excludesfile "$GLOBAL_GITIGNORE"
    ok "global .gitignore created"
  else
    ok "global .gitignore already exists"
  fi
else
  info "[dry-run] create ~/.gitignore_global"
fi

if [ -f "$SSH_KEY.pub" ] && ! $DRY_RUN; then
  echo ""
  info "Your public key (add to GitHub/GitLab):"
  echo ""
  echo -e "       ${DIM}$(cat "$SSH_KEY.pub")${RESET}"
  echo ""
  if command -v pbcopy &>/dev/null; then
    cat "$SSH_KEY.pub" | pbcopy
    ok "copied to clipboard"
  fi
fi

# =============================================================
# GUI Applications
# =============================================================
section "Applications"

CASK_APPS=(
  warp
  visual-studio-code
  brave-browser
  firefox
  postman
  jetbrains-toolbox
  docker
  mongodb-compass
)

for app in "${CASK_APPS[@]}"; do
  if brew list --cask "$app" &>/dev/null; then
    ok "$app"
  else
    info "Installing $app..."
    run brew install --cask "$app" && ok "$app" || true
  fi
done

# =============================================================
# MongoDB Community Edition
# =============================================================
section "MongoDB Community Edition"

if brew list mongodb-community &>/dev/null; then
  ok "already installed"
else
  run brew tap mongodb/brew
  run brew install mongodb-community && ok "installed" || true
fi

# =============================================================
# Oh My Zsh + Plugins + Oh My Posh
# =============================================================
section "Shell (Oh My Zsh, Plugins, Oh My Posh)"

# Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
  ok "Oh My Zsh"
else
  info "Installing Oh My Zsh..."
  if ! $DRY_RUN; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh"
  fi
fi

# Plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  ok "zsh-autosuggestions"
else
  info "Installing zsh-autosuggestions..."
  run git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
    && ok "zsh-autosuggestions" || true
fi

if ! $DRY_RUN; then
  # Ensure .zshrc exists (Oh My Zsh may not have created it yet)
  touch "$HOME/.zshrc"

  if grep -q "^plugins=" "$HOME/.zshrc"; then
    sed -i '' 's/^plugins=(.*/plugins=(z zsh-autosuggestions)/' "$HOME/.zshrc"
  else
    echo 'plugins=(z zsh-autosuggestions)' >> "$HOME/.zshrc"
  fi
  ok "plugins=(z zsh-autosuggestions)"
fi

# Oh My Posh
if command -v oh-my-posh &>/dev/null; then
  ok "Oh My Posh"
else
  info "Installing Oh My Posh..."
  run brew install jandedobbeleer/oh-my-posh/oh-my-posh && ok "Oh My Posh" || true
fi

if ! $DRY_RUN; then
  touch "$HOME/.zshrc"
  if ! grep -q "oh-my-posh" "$HOME/.zshrc"; then
    {
      echo ''
      echo '# Oh My Posh prompt'
      echo 'eval "$(oh-my-posh init zsh)"'
    } >> "$HOME/.zshrc"
    ok "Oh My Posh init added to .zshrc"
  else
    ok "Oh My Posh already in .zshrc"
  fi
fi

# Nerd Font (required for Oh My Posh themes to render correctly)
if brew list --cask font-meslo-lg-nerd-font &>/dev/null; then
  ok "MesloLGS Nerd Font"
else
  info "Installing MesloLGS Nerd Font (needed for Oh My Posh icons)..."
  run brew tap homebrew/cask-fonts 2>/dev/null || true
  run brew install --cask font-meslo-lg-nerd-font && ok "MesloLGS Nerd Font" || true
fi

# =============================================================
# SDKMAN
# =============================================================
section "SDKMAN"

if [ -d "$HOME/.sdkman" ]; then
  ok "already installed"
else
  info "Installing SDKMAN..."
  if ! $DRY_RUN; then
    curl -s "https://get.sdkman.io" | bash
    ok "installed"
  fi
fi

# Source SDKMAN and install latest Java
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ] && ! $DRY_RUN; then
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  ok "SDKMAN sourced"

  if command -v sdk &>/dev/null; then
    if sdk list java 2>/dev/null | grep -q "installed"; then
      ok "Java already installed via SDKMAN"
    else
      info "Installing latest Java via SDKMAN..."
      sdk install java >> "$LOG_FILE" 2>&1 && ok "Java installed" || fail "Java install failed (see $LOG_FILE)"
    fi
  fi
elif $DRY_RUN; then
  info "[dry-run] source ~/.sdkman/bin/sdkman-init.sh"
  info "[dry-run] sdk install java"
fi

# =============================================================
# nvm + Node.js LTS
# =============================================================
section "nvm + Node.js"

export NVM_DIR="$HOME/.nvm"

if [ -d "$NVM_DIR" ]; then
  ok "nvm already installed"
else
  info "Installing nvm..."
  if ! $DRY_RUN; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash >> "$LOG_FILE" 2>&1 \
      && ok "nvm installed" || fail "nvm install failed (see $LOG_FILE)"
  else
    info "[dry-run] curl nvm install script"
  fi
fi

# Source nvm and install Node LTS
if [ -s "$NVM_DIR/nvm.sh" ] && ! $DRY_RUN; then
  source "$NVM_DIR/nvm.sh"

  if nvm ls --no-colors 2>/dev/null | grep -q "lts"; then
    ok "Node.js LTS already installed"
  else
    info "Installing Node.js LTS..."
    nvm install --lts >> "$LOG_FILE" 2>&1 && ok "Node.js LTS installed" || fail "Node.js LTS install failed"
  fi

  nvm alias default lts/* >> "$LOG_FILE" 2>&1
  ok "default alias set to LTS"
elif $DRY_RUN; then
  info "[dry-run] nvm install --lts"
fi

# Add nvm to .zshrc if not already there
if ! $DRY_RUN; then
  touch "$HOME/.zshrc"
  if ! grep -q "NVM_DIR" "$HOME/.zshrc"; then
    {
      echo ''
      echo '# nvm'
      echo 'export NVM_DIR="$HOME/.nvm"'
      echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
      echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
    } >> "$HOME/.zshrc"
    ok "nvm added to .zshrc"
  else
    ok "nvm already in .zshrc"
  fi
fi

# =============================================================
# brew-cask-upgrade (brew cu)
# =============================================================
section "brew-cask-upgrade (brew cu)"

if brew tap | grep -q "buo/cask-upgrade"; then
  ok "already tapped"
else
  run brew tap buo/cask-upgrade && ok "tapped" || true
fi

# =============================================================
# Update everything
# =============================================================
section "Update Everything"

run brew upgrade || true
run brew cu --all -y || true
ok "updates done"

# =============================================================
# Workspace Folders
# =============================================================
section "Workspace Folders"

for dir in "$HOME/work" "$HOME/private"; do
  if [ -d "$dir" ]; then
    ok "$dir"
  else
    if ! $DRY_RUN; then
      mkdir -p "$dir"
      ok "$dir created"
    else
      info "[dry-run] mkdir -p $dir"
    fi
  fi
done

# =============================================================
# macOS Developer Defaults
# =============================================================
section "macOS Defaults"

if ! $DRY_RUN; then
  # Show hidden files in Finder
  defaults write com.apple.finder AppleShowAllFiles -bool true

  # Show all file extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  # Show path bar in Finder
  defaults write com.apple.finder ShowPathbar -bool true

  # Show status bar in Finder
  defaults write com.apple.finder ShowStatusBar -bool true

  # Faster key repeat
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15

  # Disable press-and-hold for keys (enable key repeat)
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  # Avoid creating .DS_Store files on network or USB volumes
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  # Dock: auto-hide, smaller icons, remove recents
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock tilesize -int 42
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock minimize-to-application -bool true

  # Remove all default apps from Dock (clean slate)
  defaults write com.apple.dock persistent-apps -array

  # Screenshots: save to ~/Desktop/Screenshots, PNG format
  mkdir -p "$HOME/Desktop/Screenshots"
  defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
  defaults write com.apple.screencapture type -string "png"
  defaults write com.apple.screencapture disable-shadow -bool true

  # Restart Finder and Dock to apply changes
  killall Finder 2>/dev/null || true
  killall Dock 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true

  ok "Finder: show hidden files, extensions, path bar, status bar"
  ok "Keyboard: fast repeat, no press-and-hold"
  ok "No .DS_Store on network/USB volumes"
  ok "Dock: auto-hide, small icons, no recents, cleared apps"
  ok "Screenshots: ~/Desktop/Screenshots, PNG, no shadow"
else
  info "[dry-run] defaults write (Finder, keyboard, .DS_Store, Dock, screenshots)"
fi

# =============================================================
# Cleanup & Health Check
# =============================================================
section "Cleanup and Health Check"

info "Running brew cleanup..."
run brew cleanup || true
ok "brew cleanup"

info "Running brew doctor..."
if ! $DRY_RUN; then
  if brew doctor >> "$LOG_FILE" 2>&1; then
    ok "brew doctor — no issues"
  else
    info "brew doctor found warnings (see $LOG_FILE)"
  fi
else
  info "[dry-run] brew doctor"
fi

# =============================================================
# Summary
# =============================================================
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))
TOTAL=$(( SUCCESSES + ${#ERRORS[@]} ))

echo ""
echo -e "  ${BOLD}=============================================${RESET}"
if [ ${#ERRORS[@]} -eq 0 ]; then
  echo -e "  ${GREEN}  [ok] Setup complete ($SUCCESSES/$TOTAL)${RESET}"
else
  echo -e "  ${RED}  [✗]  Setup finished: $SUCCESSES/$TOTAL succeeded, ${#ERRORS[@]} failed${RESET}"
fi
echo -e "  ${BOLD}=============================================${RESET}"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "  Failures:"
  for err in "${ERRORS[@]}"; do
    echo -e "       ${RED}[✗]${RESET}  $err"
  done
fi

echo ""
echo -e "  ${DIM}elapsed: ${MINS}m ${SECS}s${RESET}"
echo -e "  ${DIM}log:     $LOG_FILE${RESET}"
echo ""
echo "  Next steps:"
echo "    1. Restart your terminal"
echo "    2. Set terminal font to 'MesloLGS Nerd Font' for Oh My Posh icons"
echo "    3. Add SSH key to GitHub: Settings > SSH and GPG keys"
echo "       (add as both Authentication and Signing key)"
echo "    4. Add GPG key to GitHub: Settings > SSH and GPG keys > New GPG key"
echo "    5. Open Docker Desktop once to finish setup"
echo "    6. brew services start mongodb-community"
echo "    7. Pick an Oh My Posh theme: https://ohmyposh.dev/docs/themes"
echo ""

# macbook-pro-setup

## Homebrew

https://brew.sh

```
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

## (Keep in Dock)

## iterm2

```
$ brew cask install iterm2
```

- Open iTerm2
- Press: CMD + I
- Tab: Colors
- Select: Colors Presents -> Import
- Select Monokai Soda
  (Credit: https://iterm2colorschemes.com/)

## spectacle (preferences -> enable on startup)

```
$ brew cask install spectacle
```

## sublime-text

```
$ brew cask install sublime-text
```

## chrome

```
$ brew cask install google-chrome
```

## docker

```
$ brew cask install docker
$ sudo mkdir /srv/docker
$ sudo chown /srv/docker $USER
# add /srv/docker to docker->preferneces->file sharing
```

## slack

```
$ brew cask install slack
```

## Java 8

```
$ brew tap caskroom/versions
$ brew cask install java8
```

## Maven

```
$ brew install maven
```

## JetBrains Toolbox

```
$ brew cask install jetbrains-toolbox
```

## Node

```
$ brew install npm
```

## Git

```
$ brew install git

git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global alias.co checkout
git config --global apply.whitespace nowarn
```

## Postgres (install only)

```
$ brew install postgresql
```

## Vim - Enable Syntax

```
echo "syntax on" > ~/.vimrc
```

## dotfiles couresy of AWS Randall Hunt

```
$ git clone https://github.com/sligokid/dotfiles
```

## OhMyZsh

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### OhMyZsh Custom Plugins

```
brew install z

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions\n

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

### Custom OhMyZsh RC File

```
. /usr/local/etc/profile.d/z.sh

ZSH_THEME="blinks2"

plugins=(git-prompt git zsh-autosuggestions zsh-syntax-highlighting git-flow extract copyfile)

alias cod="git checkout develop"
alias cos="git checkout staging"
alias com="git checkout master"
alias nb="git checkout -b feature/MYBE-"
alias subl="/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl"
alias startShop="npm run build && serve -s build -p 3000"

export PATH=/usr/local/mysql/bin:$PATH
```

### Custom OhMyZsh Theme

Create an file in

```
~/.oh-my-zsh/themes/blinks2.zsh-theme
```

```
# https://github.com/blinks zsh theme

function _prompt_char() {
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    echo "%{%F{blue}%}±%{%f%k%b%}"
  else
    echo ' '
  fi
}

# This theme works with both the "dark" and "light" variants of the
# Solarized color schema.  Set the SOLARIZED_THEME variable to one of
# these two values to choose.  If you don't specify, we'll assume you're
# using the "dark" variant.

case ${SOLARIZED_THEME:-dark} in
    light) bkg=white;;
    *)     bkg=black;;
esac

# Default values for the appearance of the prompt.
# ZSH_THEME_GIT_PROMPT_PREFIX="("
# ZSH_THEME_GIT_PROMPT_SUFFIX=")"
# ZSH_THEME_GIT_PROMPT_CLEAN=""

ZSH_THEME_GIT_PROMPT_SEPARATOR="|"
ZSH_THEME_GIT_PROMPT_BRANCH="%{$fg_bold[magenta]%}"
ZSH_THEME_GIT_PROMPT_STAGED="%{$fg[red]%}%{●%G%}"
ZSH_THEME_GIT_PROMPT_CONFLICTS="%{$fg[red]%}%{✖%G%}"
ZSH_THEME_GIT_PROMPT_CHANGED="%{$fg[red]%}%{✚%G%}"
ZSH_THEME_GIT_PROMPT_BEHIND="%{↓%G%}"
ZSH_THEME_GIT_PROMPT_AHEAD="%{↑%G%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{…%G%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg_bold[green]%}%{✔%G%}"

ZSH_THEME_GIT_PROMPT_PREFIX=" (%{%B%F{blue}%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{%f%k%b%K{${bkg}}%B%F{green}%})"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{%F{red}%}*%{%f%k%b%}"


PROMPT='%{%f%k%b%}
%{%K{${bkg}}%B%F{green}%}%n%{%B%F{blue}%}@%{%B%F{cyan}%}%m%{%B%F{green}%} %{%b%F{yellow}%K{${bkg}}%}%~%{%B%F{green}%}$(git_super_status)%E%{%f%k%b%}
%{%K{${bkg}}%}$(_prompt_char)%{%K{${bkg}}%} %#%{%f%k%b%} '

RPROMPT='!%{%B%F{cyan}%}%!%{%f%k%b%}'
```

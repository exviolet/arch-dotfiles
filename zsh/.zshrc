# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting zsh-autosuggestions zoxide fzf)



source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"
# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run alias.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias ls="exa --icons"
alias la="exa --long --all --group --icons"
alias lst="exa -lT --icons"

# To customize prompt, run p10k configure or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[[ ! -f ~/.config/zsh/p10k-themes/current.zsh ]] || source ~/.config/zsh/p10k-themes/current.zsh
# export ANDROID_HOME=$HOME/Android/Sdk
# export PATH=$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools
# export PATH="$PATH:$HOME/development/flutter/bin"
# export CHROME_EXECUTABLE=/var/lib/flatpak/app/com.google.Chrome/x86_64/stable/b1d1439b2ab93dcf30d06c0308f48b148bb6d9c1fe6371b8a8aa143912f0b505/files/bin/chrome


# Load Angular CLI autocompletion.
# source <(ng completion script)

# Lazy-load nvm — загружается только при первом вызове nvm/node/npm/npx
export NVM_DIR="$HOME/.nvm"
lazy_load_nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { lazy_load_nvm; nvm "$@"; }
node() { lazy_load_nvm; node "$@"; }
npm()  { lazy_load_nvm; npm "$@"; }
npx()  { lazy_load_nvm; npx "$@"; }

# bun completions
# [ -s "/home/ex1te/.bun/_bun" ] && source "/home/ex1te/.bun/_bun"

# bun
# export BUN_INSTALL="$HOME/.bun"
# export PATH="$BUN_INSTALL/bin:$PATH"

# Added by LM Studio CLI (lms)
# export PATH="$PATH:/home/ex1te/.lmstudio/bin"
# End of LM Studio CLI section

export PATH=$PATH:/home/ex1te/.spicetify

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# zoxide
eval "$(zoxide init zsh)"
# Полная замена cd на "умный" переход
alias cd='z'          # теперь "cd foo" = "z foo"
alias cdi='zi'        # интерактивный выбор директорий

# Оставляем доступ к настоящему cd (на всякий)
alias \cd='builtin cd'

# Удобные хоткеи:
# Ctrl+G — открыть интерактивный выбор каталога (zi)
bindkey -s '^G' 'zi\n'
# Ctrl+H — назад (эквивалент "z -")
bindkey -s '^H' 'z -\n'

# Опционально: сделать вывод zoxide-списка по Alt+d (как твой `d`)
# Показать топ путей (10 строк) с номерами
function zlist() { zoxide query -l | nl -ba | head -n 10; }
bindkey -s '^[d' 'zlist\n'  # Alt+d

# zeditor
alias zed='zeditor'

#bun
alias b='bun'

#clear
alias cl='clear'

#claude
alias clde='claude'

#codex
alias cdx='codex'

#hermes
alias h='hermes'

#yazi 
bindkey -s '^Y' 'yazi\n'
export PATH="$PATH:/home/ex1te/.local/bin"

# OpenClaw Completion (cached for fast startup)
# Regenerate cache: openclaw completion --shell zsh > ~/.cache/zsh/openclaw_completion.zsh
if [[ ! -f ~/.cache/zsh/openclaw_completion.zsh ]] || \
   [[ "$(command -v openclaw)" -nt ~/.cache/zsh/openclaw_completion.zsh ]]; then
  mkdir -p ~/.cache/zsh
  openclaw completion --shell zsh > ~/.cache/zsh/openclaw_completion.zsh 2>/dev/null
fi
source ~/.cache/zsh/openclaw_completion.zsh 2>/dev/null

export _JAVA_AWT_WM_NONREPARENTING=1

#php-composer
export PATH="$PATH:$HOME/.config/composer/vendor/bin"

#csvlens
alias tsv='csvlens -t'

#git
alias gdst='git diff --stat'

#tmux 
alias tn='tmux new -s'
alias ta='tmux attach -t'
alias tl='tmux ls'

unset SSH_ASKPASS


port() {
  # Сначала находим PID процесса, слушающего порт
  local pid=$(sudo ss -tulnp | grep ":$1 " | awk -F'pid=' '{print $2}' | cut -d',' -f1 | head -n 1)
  
  # Выводим стандартный ss
  sudo ss -tulnp | grep ":$1 "
  
  # Если PID найден, выводим подробности о команде
  if [ -n "$pid" ]; then
    echo -e "\n\033[1;32mДетали процесса:\033[0m"
    ps -fp $pid | sed -n '2p'
  fi
}


export PATH="$(npm config get prefix)/bin:$PATH"


# Функция для запроса имени и переименования окна
tmux_rename_bind() {
  if [[ -n "$TMUX" ]]; then
    local new_name=""
    # Запрос ввода у пользователя с подсказкой "New window name: "
    vared -p "New window name: " new_name
    # Если имя введено, переименовываем окно
    [[ -n "$new_name" ]] && tmux rename-window "$new_name"
  fi
  # Перерисовываем строку ввода, чтобы очистить prompt
  zle reset-prompt
}

# Регистрируем функцию как Zsh Line Editor (ZLE) виджет
zle -N tmux_rename_bind

bindkey '^Wr' tmux_rename_bind

# Сброс раскладки на Английский (US) при открытии Zsh в Niri WM
if [[ $- == *i* ]] && [ -n "$NIRI_SOCKET" ] && command -v niri &> /dev/null; then
    niri msg action switch-layout 0 &> /dev/null
fi

export PATH=/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export ARTIFACTORY_ENTERPRISE_USERNAME="shaonl"
export ARTIFACTORY_ENTERPRISE_APIKEY=""
export AE_USER_NAME="shaonl"
export AE_API_KEY=""
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

export PATH="$HOME/ghp-workshop-bin:$PATH"
export PATH="$HOME/.pyenv/versions/3.12.12/bin/python3:$PATH"

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/opt/homebrew/share/zsh-syntax-highlighting/highlighters

. "$HOME/.local/bin/env"

eval "$(starship init zsh)"

# bun completions
[ -s "/Users/nikki.shao/.bun/_bun" ] && source "/Users/nikki.shao/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# OpenAI and Anthropic environment variables
# export OPENAI_API_KEY=
export OPENAI_URL="https://api.studio.genai.cba"
export OPENAI_API_BASE="https://api.studio.genai.cba"
# export ANTHROPIC_AUTH_TOKEN=
# export ANTHROPIC_MODEL="@bedrock-eus1/us.anthropic.claude-sonnet-4-6"
export UV_DEFAULT_INDEX=https://artifactory.internal.cba/artifactory/api/pypi/pypi.org/simple
export UV_INDEX_DEA_OBS_PASSWORD=""

# aliases
alias k=kubectl
alias git-cb='git pull -p && git branch -vv | grep "gone]" | awk '"'"'{print $1}'"'"' | xargs git branch -D'
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"

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
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

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
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Apply the prompt dynamically

# Aliases
alias c="clear"
alias cat="batcat"
alias espidf=". $HOME/esp/esp-idf/export.sh"
alias weather="curl -s wttr.in/Aalborg"
alias python3.10="$HOME/python310/bin/python3.10"

# Initialize zoxide for zsh
eval "$(zoxide init --cmd cd zsh)"

# Git auto-update function
function update {
    TIMESTAMP=$(date +"%Y-%d/%m %H:%M:%S")
    COMMIT_MESSAGE="Auto commit at $TIMESTAMP"
    CURRENT_DIR="$PWD"
    
    cd "/home/rasmus/Desktop/Aalborg Universitet"
    git add .
    git commit -m "$COMMIT_MESSAGE"
    OUTPUT=$(git push 2>&1)
    
    if [[ "$OUTPUT" == *"Everything up-to-date"* ]]; then
        echo "Nothing was pushed"
    else
        echo "Pushed with commit message: $COMMIT_MESSAGE"
    fi
    
    cd "$CURRENT_DIR"
}


function maze() {
    local ORIGINAL_DIR
    ORIGINAL_DIR=$(pwd)

    # Trap Ctrl+C to restore dir
    trap 'cd "$ORIGINAL_DIR"; echo -e "\nRestored to $ORIGINAL_DIR"; return' INT

    cd /home/rasmus/maze_script/Moving_maze || return
    python3 main.py

    cd "$ORIGINAL_DIR"
    trap - INT  # Clear trap
}

function aoc() {
	local day="$1"
	local year="$2"

	local day_suffixes=( "1st" "2nd" "3rd" "4th" "5th" "6th" "7th" "8th" "9th" "10th" \
                       "11th" "12th" "13th" "14th" "15th" "16th" "17th" "18th" "19th" \
                       "20th" "21st" "22nd" "23rd" "24th" "25th" )

	if (( day < 1 || day > 25 )); then
    		echo "Invalid day: $day"
    		return 1
  	fi

	cd "/home/rasmus/Documents/GitHub/Advent_of_code/$year"
	local dir_name="${day_suffixes[$day]}_December"

	mkdir -p "$dir_name"
	cd "$dir_name/"

	local session_cookie=$(<~/aoc_cookie.txt)

	curl --cookie "session=$session_cookie" \
     	"https://adventofcode.com/$year/day/$day/input" \
     	> data.txt

	touch main.py
	touch test_data.txt

	echo "def get_data(test=False):\n\tif not test:\n\t\twith open(\"data.txt\", \"r\") as file:\n\t\t\tdata = file.read()\n\telse:\n\t\twith open(\"test_data.txt\", \"r\") as file:\n\t\t\tdata = file.read()\n\treturn data\n\n\nif __name__ == '__main__':\n\tdata = get_data()" > main.py
}


[ -z "$TMUX" ] && (tmux attach || tmux new)

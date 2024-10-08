# default shortcut as Ctrl-o
(( ! ${+ZSH_OLLAMA_COMMANDS_HOTKEY} )) && typeset -g ZSH_OLLAMA_COMMANDS_HOTKEY='^o'
# default ollama model as llama3
(( ! ${+ZSH_OLLAMA_MODEL} )) && typeset -g ZSH_OLLAMA_MODEL='codegemma:code'
# default response number as 5
(( ! ${+ZSH_OLLAMA_COMMANDS} )) && typeset -g ZSH_OLLAMA_COMMANDS='5'
# default ollama server host
(( ! ${+ZSH_OLLAMA_URL} )) && typeset -g ZSH_OLLAMA_URL='http://localhost:11434'

validate_required() {
  # check required tools are installed
  if (( ! $+commands[jq] )) then
      echo "🚨: zsh-ollama-command failed as jq NOT found!"
      echo "Please install it with 'brew install jq'"
      return 1;
  fi
  if (( ! $+commands[fzf] )) then
      echo "🚨: zsh-ollama-command failed as fzf NOT found!"
      echo "Please install it with 'brew install fzf'"
      return 1;
  fi
  if (( ! $+commands[curl] )) then
      echo "🚨: zsh-ollama-command failed as curl NOT found!"
      echo "Please install it with 'brew install curl'"
      return 1;
  fi
  if ! (( $(pgrep -f ollama | wc -l ) > 0 )); then
    echo "🚨: zsh-ollama-command failed as OLLAMA server NOT running!"
    echo "Please start it with 'brew services start ollama'"
    return 1;
  fi
  if ! curl -s "${ZSH_OLLAMA_URL}/api/tags" | grep -q $ZSH_OLLAMA_MODEL; then
    echo "🚨: zsh-ollama-command failed as model ${ZSH_OLLAMA_MODEL} server NOT found!"
    echo "Please start it with 'ollama pull ${ZSH_OLLAMA_MODEL}' or adjust ZSH_OLLAMA_MODEL"
    return 1;
  fi
}

check_status() {
  tput cuu 1 # cleanup waiting message
  if [ $? -ne 0 ]; then
    echo "༼ つ ◕_◕ ༽つ Sorry! Please try again..."
    exit 1
  fi
}

fzf_ollama_commands() {
  setopt extendedglob
  validate_required
  if [ $? -eq 1 ]; then
    return 1
  fi

  ZSH_OLLAMA_COMMANDS_USER_QUERY=$BUFFER

  zle end-of-line
  zle reset-prompt

  # Logging
  ZSH_OLLAMA_TIMESTAMPS=$(date +"%Y-%m-%d_%H:%M:%S")
  touch ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt
  echo "**Date and Timestamp:** ${ZSH_OLLAMA_TIMESTAMPS}" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  print -u1 "👻 Please wait..."

  ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT="You are tasked with generating macOS zsh terminal commands based on a user query. Your output should be in a specific JSON format containing an array of command suggestions. Follow these guidelines carefully: 1. The user query you will be responding to is: <user_query> $ZSH_OLLAMA_COMMANDS_USER_QUERY </user_query> 2. Generate relevant zsh terminal commands that address the user's query. Each command should be a complete, executable statement. 3. If a task requires multiple commands, combine them into a single string entry, separated by semicolons or && operators as appropriate. 4. Provide at least 2 and up to $ZSH_OLLAMA_COMMANDS relevant command entries in your response. Do not exceed this number. 5. Format your response as a JSON array of strings. Adhere to these formatting rules: - Escape double quotes within command strings using a triple backslash (\\\") - Do not include any additional text or descriptions outside the JSON array - Ensure there are no empty string entries - Each command or set of commands should b`e a separate string entry in the array 6. Your response must be valid JSON that can be parsed by jq. Do not include any text before or after the JSON array. Here's an example of the expected output format: ["command1","command2","command3", "command4"] Remember, your entire response should only contain the JSON array of commands, nothing else. Ensure that your response addresses the user query effectively and can be directly used in a macOS zsh terminal."

  ZSH_OLLAMA_COMMANDS_REQUEST_BODY='{
    "model": "'$ZSH_OLLAMA_MODEL'",
    "messages": [
      {
        "role": "user",
        "content":  "'$ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT'"
      }
    ],
    "stream": false,
    "options": {
      "temperature": 1.0
    },
    "format": "json"
  }'

  # Debugging
  echo "[$(date +"%Y%m%d_%H%M%S")] ZSH_OLLAMA_COMMANDS_REQUEST_BODY %s\n" "$ZSH_OLLAMA_COMMANDS_REQUEST_BODY" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  ZSH_OLLAMA_COMMANDS_RESPONSE=$(curl --silent "${ZSH_OLLAMA_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$ZSH_OLLAMA_COMMANDS_REQUEST_BODY")
  local ret=$?

  echo "[$(date +"%Y%m%d_%H%M%S")] ZSH_OLLAMA_COMMANDS_RESPONSE %s\n" "$ZSH_OLLAMA_COMMANDS_RESPONSE" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  echo "REQUEST: ${ZSH_OLLAMA_COMMANDS_REQUEST_BODY}" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt
  echo #
  echo "RESPONSE: ${ZSH_OLLAMA_COMMANDS_RESPONSE}" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt
  
  # Eval Time
  ZSH_OLLAMA_EVAL=$(echo $ZSH_OLLAMA_COMMANDS_RESPONSE | tr -d '\n\r' | tr -d '\0' | jq '.eval_duration')
  echo "$ZSH_OLLAMA_EVAL" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  # trim response content newline
  ZSH_OLLAMA_COMMANDS_SUGGESTION=$(echo $ZSH_OLLAMA_COMMANDS_RESPONSE | tr -d '\n\r' | tr -d '\0' | jq '.')
  check_status

  echo "[$(date +"%Y%m%d_%H%M%S")] ZSH_OLLAMA_COMMANDS_SUGGESTION %s\n" "$ZSH_OLLAMA_COMMANDS_SUGGESTION" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  # collect suggestion commands from response content
  ZSH_OLLAMA_COMMANDS_SUGGESTION=$(echo "$ZSH_OLLAMA_COMMANDS_SUGGESTION" | tr -d '\0' | jq -r '.message.content')
  check_status

  echo "[$(date +"%Y%m%d_%H%M%S")] ZSH_OLLAMA_COMMANDS_SUGGESTION %s\n" "$ZSH_OLLAMA_COMMANDS_SUGGESTION" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  # attempts to extract suggestions from ZSH_OLLAMA_COMMANDS_SUGGESTION using jq.
  # If jq fails or returns no output, displays an error message and exits.
  # Otherwise, pipes the output to fzf for interactive selection
  ZSH_OLLAMA_COMMANDS_SELECTED=$(echo $ZSH_OLLAMA_COMMANDS_SUGGESTION | tr -d '\0' | jq -r '.[]')
  check_status

  echo "[$(date +"%Y%m%d_%H%M%S")] ZSH_OLLAMA_COMMANDS_SELECTED %s\n" "$ZSH_OLLAMA_COMMANDS_SELECTED" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  tput cuu 1 # cleanup waiting message

  ZSH_OLLAMA_COMMANDS_SELECTED=$(echo $ZSH_OLLAMA_COMMANDS_SUGGESTION | jq -r '.[]' | fzf --ansi --height=~40 --cycle --layout=reverse --border --header-first --header 'Select your command')
  BUFFER=$ZSH_OLLAMA_COMMANDS_SELECTED

  echo "[$(date +"%Y%m%d_%H%M%S")] ZSH_OLLAMA_COMMANDS_SELECTED %s\n" "$ZSH_OLLAMA_COMMANDS_SELECTED" >> ~/.oh-my-zsh/custom/plugins/zsh-ollama-command/logs/log_${ZSH_OLLAMA_TIMESTAMPS}.txt

  zle end-of-line
  zle reset-prompt
  return $ret
}

validate_required

autoload fzf_ollama_commands
zle -N fzf_ollama_commands

bindkey $ZSH_OLLAMA_COMMANDS_HOTKEY fzf_ollama_commands

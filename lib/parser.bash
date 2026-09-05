# shellcheck shell=bash

# This file intentionally performs no eval and launches no subprocesses. It is
# called on every edit, so classification stays local and fast.

declare -ga CHROMA_TOKEN_START=()
declare -ga CHROMA_TOKEN_END=()
declare -ga CHROMA_TOKEN_KIND=()
declare -ga CHROMA_TOKEN_VALUE=()
declare -ga CHROMA_SPAN_START=()
declare -ga CHROMA_SPAN_END=()
declare -ga CHROMA_SPAN_CATEGORY=()

chromarchy::is_operator_char() {
  [[ $1 == ';' || $1 == '&' || $1 == '|' || $1 == '(' || $1 == ')' ||
     $1 == '{' || $1 == '}' || $1 == '<' || $1 == '>' || $1 == $'\n' ]]
}

chromarchy::push_token() {
  CHROMA_TOKEN_START+=("$1")
  CHROMA_TOKEN_END+=("$2")
  CHROMA_TOKEN_KIND+=("$3")
  CHROMA_TOKEN_VALUE+=("$4")
}

chromarchy::tokenize() {
  local text=$1 len=${#1} i=0 start ch next op quote value
  CHROMA_TOKEN_START=()
  CHROMA_TOKEN_END=()
  CHROMA_TOKEN_KIND=()
  CHROMA_TOKEN_VALUE=()

  while ((i < len)); do
    ch=${text:i:1}
    if [[ $ch == [[:space:]] && $ch != $'\n' ]]; then
      ((i++))
      continue
    fi

    if [[ $ch == '#' ]]; then
      chromarchy::push_token "$i" "$len" comment "${text:i}"
      break
    fi

    if chromarchy::is_operator_char "$ch"; then
      start=$i
      next=${text:i+1:1}
      op=$ch
      case $ch$next in
        '&&'|'||'|'|&'|';&'|';;'|'>>'|'<<'|'>&'|'<&'|'<>'|'>|'|'&>')
          op+=$next
          ((i++))
          ;;
      esac
      if [[ $op == ';;' && ${text:i+1:1} == '&' ]]; then
        op+='&'
        ((i++))
      elif [[ $op == '<<' && ${text:i+1:1} == '<' ]]; then
        op+='<'
        ((i++))
      elif [[ $op == '&>' && ${text:i+1:1} == '>' ]]; then
        op+='>'
        ((i++))
      fi
      ((i++))
      chromarchy::push_token "$start" "$i" op "$op"
      continue
    fi

    start=$i
    quote=
    value=
    while ((i < len)); do
      ch=${text:i:1}
      if [[ $quote == "'" ]]; then
        if [[ $ch == "'" ]]; then
          quote=
        else
          value+=$ch
        fi
        ((i++))
        continue
      elif [[ $quote == '"' ]]; then
        if [[ $ch == '"' ]]; then
          quote=
          ((i++))
        elif [[ $ch == $'\\' ]] && ((i + 1 < len)); then
          value+=${text:i+1:1}
          ((i+=2))
        else
          value+=$ch
          ((i++))
        fi
        continue
      fi

      if [[ $ch == [[:space:]] ]]; then
        break
      elif chromarchy::is_operator_char "$ch"; then
        break
      elif [[ $ch == "'" || $ch == '"' ]]; then
        quote=$ch
        ((i++))
      elif [[ $ch == $'\\' ]] && ((i + 1 < len)); then
        value+=${text:i+1:1}
        ((i+=2))
      else
        value+=$ch
        ((i++))
      fi
    done
    chromarchy::push_token "$start" "$i" word "$value"
  done
}

chromarchy::is_boundary() {
  case $1 in
    ';'|'&&'|'||'|'|'|'|&'|'&'|'('|')'|'{'|'}'|';;'|';&'|';;&'|$'\n') return 0 ;;
    *) return 1 ;;
  esac
}

chromarchy::is_redirection() {
  [[ $1 == *'>'* || $1 == *'<'* ]]
}

chromarchy::is_assignment() {
  [[ $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]
}

chromarchy::add_span_token() {
  local token_index=$1 category=$2 i
  [[ $token_index =~ ^[0-9]+$ && -n $category ]] || return 0

  # One semantic style per token. Later, more specific decisions win.
  for i in "${!CHROMA_SPAN_START[@]}"; do
    if ((CHROMA_SPAN_START[i] == CHROMA_TOKEN_START[token_index] &&
         CHROMA_SPAN_END[i] == CHROMA_TOKEN_END[token_index])); then
      CHROMA_SPAN_CATEGORY[i]=$category
      return 0
    fi
  done
  CHROMA_SPAN_START+=("${CHROMA_TOKEN_START[token_index]}")
  CHROMA_SPAN_END+=("${CHROMA_TOKEN_END[token_index]}")
  CHROMA_SPAN_CATEGORY+=("$category")
}

chromarchy::array_contains() {
  local needle=$1 array_name=$2 item
  local -n values=$array_name
  for item in "${values[@]}"; do
    [[ $item == "$needle" ]] && return 0
  done
  return 1
}

chromarchy::find_first_action() {
  local pos
  _chromarchy_action_pos=-1
  for ((pos=$1; pos<${#_chromarchy_words_val[@]}; pos++)); do
    [[ ${_chromarchy_words_val[pos]} == -- ]] && continue
    [[ ${_chromarchy_words_val[pos]} == -* ]] && continue
    chromarchy::is_assignment "${_chromarchy_words_val[pos]}" && continue
    _chromarchy_action_pos=$pos
    return 0
  done
  return 1
}

chromarchy::find_word() {
  local needle=$1 pos
  _chromarchy_found_pos=-1
  for ((pos=$2; pos<${#_chromarchy_words_val[@]}; pos++)); do
    if [[ ${_chromarchy_words_val[pos],,} == "$needle" ]]; then
      _chromarchy_found_pos=$pos
      return 0
    fi
  done
  return 1
}

chromarchy::classify_executable() {
  local pos=$1 command_value=${_chromarchy_words_val[$1]} base category='' action='' arg=''
  local action_pos=-1
  base=${command_value##*/}
  base=${base,,}

  if chromarchy::array_contains "$base" CHROMA_EXTRA_DANGER_COMMANDS; then
    category=danger
  elif chromarchy::array_contains "$base" CHROMA_EXTRA_REMOVE_COMMANDS; then
    category=remove
  elif chromarchy::array_contains "$base" CHROMA_EXTRA_INSTALL_COMMANDS; then
    category=install
  else
    case $base in
      pacman|yay|paru|pikaur|trizen)
        category=inspect
        local p
        for ((p=pos+1; p<${#_chromarchy_words_val[@]}; p++)); do
          arg=${_chromarchy_words_val[p]}
          case $arg in
            --remove|--remove-nosave|-R*) category=remove; action_pos=$p ;;
            --sync|--upgrade|-S*|-U*) [[ $category == remove ]] || { category=install; action_pos=$p; } ;;
          esac
        done
        ;;
      omarchy-pkg-add|omarchy-install*) category=install ;;
      omarchy-pkg-remove|omarchy-remove*) category=remove ;;
      apt|apt-get|dnf|yum|zypper|apk|xbps-install|nix|nix-env|guix|brew)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          install|add|update|upgrade|full-upgrade|dist-upgrade|reinstall|switch|profile) category=install ;;
          remove|purge|autoremove|uninstall|erase|delete) category=remove ;;
          *) category=inspect ;;
        esac
        ;;
      flatpak|snap)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          install|update|refresh|repair) category=install ;;
          uninstall|remove) category=remove ;;
          *) category=inspect ;;
        esac
        ;;
      npm|pnpm|yarn|bun|pip|pip3|pipx|uv|gem|composer|cargo)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        if [[ $base == uv && $action == pip ]]; then
          local uv_pip_pos=$action_pos
          chromarchy::find_first_action "$((action_pos+1))" || true
          action_pos=$_chromarchy_action_pos
          ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
          chromarchy::add_span_token "${_chromarchy_words_idx[uv_pip_pos]}" install
        fi
        case $action in
          i|install|add|update|upgrade|sync) category=install ;;
          uninstall|remove|rm|un|prune) category=remove ;;
          build|test|check|run|fmt|clippy|publish|pack) category=build ;;
          *) category=build ;;
        esac
        ;;
      go)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          install|get) category=install ;;
          clean) category=remove ;;
          *) category=build ;;
        esac
        ;;
      python|python3|python[0-9].*)
        # Recognize the common `python -m pip install ...` spelling.
        if chromarchy::find_word pip "$((pos+1))"; then
          local pip_pos=$_chromarchy_found_pos
          chromarchy::find_first_action "$((pip_pos+1))" || true
          action_pos=$_chromarchy_action_pos
          ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
          case $action in
            install) category=install ;;
            uninstall) category=remove ;;
            *) category=build ;;
          esac
          chromarchy::add_span_token "${_chromarchy_words_idx[pip_pos]}" "$category"
        else
          category=build
        fi
        ;;
      rm|rmdir|shred|wipefs|dd|fdisk|cfdisk|sfdisk|parted|gdisk|sgdisk|cryptsetup|kill|pkill|killall|reboot|poweroff|halt|shutdown)
        category=danger
        ;;
      mkfs|mkfs.*|mkswap) category=danger ;;
      unlink|trash-empty) category=remove ;;
      sudo|doas|pkexec) category=privilege ;;
      systemctl|loginctl|journalctl|mount|umount|swapon|swapoff|chmod|chown|chgrp|sysctl)
        category=system
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          stop|disable|mask|kill) category=remove ;;
        esac
        ;;
      git|gh|lazygit|jj|hg|svn)
        category=vcs
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          clean) category=danger ;;
          reset)
            chromarchy::find_word --hard "$((pos+1))" && category=danger
            ;;
          delete) category=remove ;;
        esac
        if chromarchy::find_word delete "$((pos+1))"; then
          category=remove
          action_pos=$_chromarchy_found_pos
        fi
        ;;
      curl|wget|aria2c|http|https|ssh|mosh|scp|sftp|rsync|ping|traceroute|tracepath|dig|host|nslookup|nc|ncat|socat)
        category=network
        ;;
      docker|podman|kubectl|helm|distrobox|incus|lxc)
        category=container
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          rm|rmi|remove|delete|prune|down) category=remove ;;
        esac
        if chromarchy::find_word prune "$((pos+1))" || chromarchy::find_word delete "$((pos+1))"; then
          category=remove
          action_pos=$_chromarchy_found_pos
        fi
        ;;
      make|gmake|cmake|ninja|meson|just|task|gradle|gradlew|mvn|ant|gcc|g++|clang|clang++|rustc|deno|node|npx)
        category=build
        ;;
      cd|pushd|popd|dirs|pwd|ls|eza|exa|tree|zoxide|z)
        category=navigate
        ;;
      cat|bat|batcat|less|more|head|tail|file|stat|du|df|free|lsblk|lspci|lsusb|uname|hostnamectl|ps|top|btop|htop|fastfetch|neofetch)
        category=inspect
        ;;
      rg|grep|egrep|fgrep|find|fd|locate|fzf|which|whereis|whatis|apropos)
        category=search
        if [[ $base == find ]] && chromarchy::find_word -delete "$((pos+1))"; then
          category=danger
          action_pos=$_chromarchy_found_pos
        fi
        ;;
      nvim|vim|vi|nano|emacs|code|codium|zed|helix|hx|micro)
        category=editor
        ;;
      omarchy)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          install|update|upgrade) category=install ;;
          remove|uninstall) category=remove ;;
          *) category=system ;;
        esac
        ;;
    esac
  fi

  [[ -n $category ]] || return 0
  chromarchy::add_span_token "${_chromarchy_words_idx[pos]}" "$category"
  ((action_pos >= 0)) && chromarchy::add_span_token "${_chromarchy_words_idx[action_pos]}" "$category"
}

chromarchy::unwrap_command() {
  local pos=$1 count=${#_chromarchy_words_val[@]} base arg
  _chromarchy_unwrapped_pos=$pos

  while ((pos < count)); do
    base=${_chromarchy_words_val[pos]##*/}
    base=${base,,}
    case $base in
      sudo|doas|pkexec)
        chromarchy::add_span_token "${_chromarchy_words_idx[pos]}" privilege
        ((pos++))
        while ((pos < count)); do
          arg=${_chromarchy_words_val[pos]}
          case $arg in
            --) ((pos++)); break ;;
            -u|-g|-h|-p|-C|-T|-R|-D|--user|--group|--host|--prompt|--close-from|--command-timeout|--chroot|--chdir)
              ((pos+=2)) ;;
            --user=*|--group=*|--host=*|--prompt=*|--close-from=*|--command-timeout=*|--chroot=*|--chdir=*|-*)
              ((pos++)) ;;
            *) break ;;
          esac
        done
        while ((pos < count)) && chromarchy::is_assignment "${_chromarchy_words_val[pos]}"; do ((pos++)); done
        ;;
      env)
        ((pos++))
        while ((pos < count)); do
          arg=${_chromarchy_words_val[pos]}
          if [[ $arg == -- ]]; then ((pos++)); break
          elif [[ $arg == -* ]] || chromarchy::is_assignment "$arg"; then ((pos++))
          else break
          fi
        done
        ;;
      command|builtin|exec|nohup|setsid)
        ((pos++))
        while ((pos < count)) && [[ ${_chromarchy_words_val[pos]} == -* ]]; do ((pos++)); done
        ;;
      time|!) ((pos++)) ;;
      timeout)
        ((pos++))
        while ((pos < count)) && [[ ${_chromarchy_words_val[pos]} == -* ]]; do
          case ${_chromarchy_words_val[pos]} in
            -k|--kill-after|-s|--signal) ((pos+=2)) ;;
            *) ((pos++)) ;;
          esac
        done
        ((pos < count)) && ((pos++)) # duration
        ;;
      nice)
        ((pos++))
        if ((pos < count)) && [[ ${_chromarchy_words_val[pos]} == -n ]]; then ((pos+=2)); fi
        while ((pos < count)) && [[ ${_chromarchy_words_val[pos]} == -* ]]; do ((pos++)); done
        ;;
      if|then|elif|else|while|until|do|coproc)
        ((pos++))
        ;;
      *) break ;;
    esac
  done
  _chromarchy_unwrapped_pos=$pos
}

chromarchy::classify_range() {
  local begin=$1 end=$2 i skip_next=0 value
  _chromarchy_words_idx=()
  _chromarchy_words_val=()

  for ((i=begin; i<end; i++)); do
    if [[ ${CHROMA_TOKEN_KIND[i]} == op ]]; then
      chromarchy::is_redirection "${CHROMA_TOKEN_VALUE[i]}" && skip_next=1
      continue
    fi
    [[ ${CHROMA_TOKEN_KIND[i]} == word ]] || continue
    if ((skip_next)); then
      skip_next=0
      continue
    fi
    value=${CHROMA_TOKEN_VALUE[i]}
    # In `2>errors.log`, the leading number is an I/O descriptor, not a
    # command. Adjacency matters: `2 > errors.log` may legitimately run `2`.
    if [[ $value =~ ^[0-9]+$ ]] && ((i + 1 < end)) &&
       [[ ${CHROMA_TOKEN_KIND[i+1]} == op ]] &&
       chromarchy::is_redirection "${CHROMA_TOKEN_VALUE[i+1]}" &&
       ((CHROMA_TOKEN_END[i] == CHROMA_TOKEN_START[i+1])); then
      continue
    fi
    if ((${#_chromarchy_words_idx[@]} == 0)) && chromarchy::is_assignment "$value"; then
      continue
    fi
    _chromarchy_words_idx+=("$i")
    _chromarchy_words_val+=("$value")
  done

  ((${#_chromarchy_words_idx[@]})) || return 0
  chromarchy::unwrap_command 0
  ((_chromarchy_unwrapped_pos < ${#_chromarchy_words_idx[@]})) || return 0
  chromarchy::classify_executable "$_chromarchy_unwrapped_pos"
}

chromarchy::classify_line() {
  local text=$1 i segment_start=0 count
  CHROMA_SPAN_START=()
  CHROMA_SPAN_END=()
  CHROMA_SPAN_CATEGORY=()
  chromarchy::tokenize "$text"
  count=${#CHROMA_TOKEN_KIND[@]}

  for ((i=0; i<count; i++)); do
    if [[ ${CHROMA_TOKEN_KIND[i]} == op ]] && chromarchy::is_boundary "${CHROMA_TOKEN_VALUE[i]}"; then
      chromarchy::classify_range "$segment_start" "$i"
      segment_start=$((i+1))
    elif [[ ${CHROMA_TOKEN_KIND[i]} == comment ]]; then
      chromarchy::classify_range "$segment_start" "$i"
      return 0
    fi
  done
  chromarchy::classify_range "$segment_start" "$count"
}

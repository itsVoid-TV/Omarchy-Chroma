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
      ((++i))
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
          ((++i))
          ;;
      esac
      if [[ $op == ';;' && ${text:i+1:1} == '&' ]]; then
        op+='&'
        ((++i))
      elif [[ $op == '<<' && ${text:i+1:1} == '<' ]]; then
        op+='<'
        ((++i))
      elif [[ $op == '&>' && ${text:i+1:1} == '>' ]]; then
        op+='>'
        ((++i))
      fi
      ((++i))
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
        ((++i))
        continue
      elif [[ $quote == '"' ]]; then
        if [[ $ch == '"' ]]; then
          quote=
          ((++i))
        elif [[ $ch == $'\\' ]] && ((i + 1 < len)); then
          value+=${text:i+1:1}
          ((i+=2))
        else
          value+=$ch
          ((++i))
        fi
        continue
      fi

      if [[ $ch == [[:space:]] ]]; then
        break
      elif chromarchy::is_operator_char "$ch"; then
        break
      elif [[ $ch == "'" || $ch == '"' ]]; then
        quote=$ch
        ((++i))
      elif [[ $ch == $'\\' ]] && ((i + 1 < len)); then
        value+=${text:i+1:1}
        ((i+=2))
      else
        value+=$ch
        ((++i))
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
  local start end
  [[ $token_index =~ ^[0-9]+$ && -n $category ]] || return 0
  start=${CHROMA_TOKEN_START[token_index]}
  end=${CHROMA_TOKEN_END[token_index]}

  # One semantic style per token. Later, more specific decisions win.
  for i in "${!CHROMA_SPAN_START[@]}"; do
    if ((CHROMA_SPAN_START[i] == start && CHROMA_SPAN_END[i] == end)); then
      CHROMA_SPAN_CATEGORY[i]=$category
      return 0
    fi
    # ble.sh's selection layer consumes ranges from left to right. Keep the
    # spans ordered even when a nested command (for example, uv pip) is found
    # before its outer executable is added.
    if ((start < CHROMA_SPAN_START[i])); then
      CHROMA_SPAN_START=("${CHROMA_SPAN_START[@]:0:i}" "$start" "${CHROMA_SPAN_START[@]:i}")
      CHROMA_SPAN_END=("${CHROMA_SPAN_END[@]:0:i}" "$end" "${CHROMA_SPAN_END[@]:i}")
      CHROMA_SPAN_CATEGORY=("${CHROMA_SPAN_CATEGORY[@]:0:i}" "$category" "${CHROMA_SPAN_CATEGORY[@]:i}")
      return 0
    fi
  done
  CHROMA_SPAN_START+=("$start")
  CHROMA_SPAN_END+=("$end")
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
  local pos arg
  _chromarchy_action_pos=-1
  pos=$1
  while ((pos<${#_chromarchy_words_val[@]})); do
    arg=${_chromarchy_words_val[pos]}
    case $arg in
      --) ((++pos)); break ;;
      -C|-c|-o|--config|--config-file|--root|--installroot|--prefix|--cwd|--dir|--directory|--context|--namespace|--kube-context|--kubeconfig|--cluster|--user|--server|--token|--as|--as-group|--host|--url|--connection|--identity|--registry|--cache|--globalconfig|--userconfig)
        ((pos+=2))
        continue
        ;;
      -*) ((++pos)); continue ;;
    esac
    if chromarchy::is_assignment "$arg"; then
      ((++pos))
      continue
    fi
    _chromarchy_action_pos=$pos
    return 0
  done
  if ((pos<${#_chromarchy_words_val[@]})); then
    _chromarchy_action_pos=$pos
    return 0
  fi
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
      apt|apt-get|dnf|yum|zypper|apk|xbps-install|nix-env|guix|brew)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          install|add|update|upgrade|full-upgrade|dist-upgrade|reinstall|switch|profile) category=install ;;
          remove|purge|autoremove|uninstall|erase|delete) category=remove ;;
          *) category=inspect ;;
        esac
        ;;
      nix)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        if [[ $action == profile || $action == store ]]; then
          local nix_group_pos=$action_pos
          chromarchy::find_first_action "$((action_pos+1))" || true
          action_pos=$_chromarchy_action_pos
          ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
          case $action in
            install|upgrade) category=install ;;
            remove|wipe-history|delete) category=remove ;;
            *) category=inspect ;;
          esac
          chromarchy::add_span_token "${_chromarchy_words_idx[nix_group_pos]}" "$category"
        else
          case $action in
            build|develop|flake|run|shell) category=build ;;
            collect-garbage) category=remove ;;
            *) category=inspect ;;
          esac
        fi
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
      pipx)
        chromarchy::find_first_action "$((pos+1))" || true
        action_pos=$_chromarchy_action_pos
        ((action_pos >= 0)) && action=${_chromarchy_words_val[action_pos],,}
        case $action in
          install|inject|upgrade|upgrade-all) category=install ;;
          uninstall|uninject|uninstall-all) category=remove ;;
          run|runpip) category=build ;;
          *) category=inspect ;;
        esac
        ;;
      npm|pnpm|yarn|bun|pip|pip3|uv|gem|composer|cargo)
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
      rm|rmdir|shred|wipefs|blkdiscard|truncate|dd|fdisk|cfdisk|sfdisk|parted|gdisk|sgdisk|cryptsetup|kill|pkill|killall|reboot|poweroff|halt|shutdown)
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
          reboot|poweroff|halt|kexec|suspend|hibernate|hybrid-sleep|suspend-then-hibernate|soft-reboot)
            category=danger
            ;;
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
        if [[ $base == git && $action == push ]]; then
          local git_pos git_arg forced_push=0 deleted_push=0
          for ((git_pos=pos+1; git_pos<${#_chromarchy_words_val[@]}; git_pos++)); do
            git_arg=${_chromarchy_words_val[git_pos],,}
            case $git_arg in
              --force|--force=*|--force-with-lease|--force-with-lease=*|--mirror) forced_push=1 ;;
              --delete) deleted_push=1 ;;
            esac
          done
          if ((forced_push)); then
            category=danger
          elif ((deleted_push)); then
            category=remove
          fi
        elif [[ $base == git && $action == branch ]]; then
          local branch_pos branch_arg
          for ((branch_pos=pos+1; branch_pos<${#_chromarchy_words_val[@]}; branch_pos++)); do
            branch_arg=${_chromarchy_words_val[branch_pos]}
            if [[ $branch_arg == -D || $branch_arg == --force ]]; then
              category=danger
            elif [[ $branch_arg == -d || $branch_arg == --delete ]] && [[ $category != danger ]]; then
              category=remove
            fi
          done
        fi
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
      cat|bat|batcat|less|more|head|tail|file|stat|du|df|free|lsblk|lspci|lsusb|uname|hostnamectl|ps|top|btop|htop|fastfetch|neofetch|type|hash|help|compgen|complete|declare|typeset|set|shopt)
        category=inspect
        case $base in
          type|hash|help)
            chromarchy::find_first_action "$((pos+1))" || true
            action_pos=$_chromarchy_action_pos
            ;;
        esac
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
  if ((action_pos >= 0)); then
    chromarchy::add_span_token "${_chromarchy_words_idx[action_pos]}" "$category"
  fi
  return 0
}

chromarchy::unwrap_command() {
  local pos=$1 count=${#_chromarchy_words_val[@]} base arg
  local command_pos command_query process_target wrapper_query
  _chromarchy_unwrapped_pos=$pos

  while ((pos < count)); do
    base=${_chromarchy_words_val[pos]##*/}
    base=${base,,}
    case $base in
      sudo|doas|pkexec)
        chromarchy::add_span_token "${_chromarchy_words_idx[pos]}" privilege
        wrapper_query=0
        ((++pos))
        while ((pos < count)); do
          arg=${_chromarchy_words_val[pos]}
          if [[ $arg == --help || $arg == --version ||
                $base == sudo && ( $arg == -v || $arg == --validate ||
                                   $arg == -l || $arg == --list ||
                                   $arg == -K || $arg == --remove-timestamp ) ||
                $base == doas && $arg == -C ]]; then
            wrapper_query=1
          fi
          case $arg in
            --) ((++pos)); break ;;
            -u|-g|-h|-p|-C|-T|-R|-D|--user|--group|--host|--prompt|--close-from|--command-timeout|--chroot|--chdir)
              ((pos+=2)) ;;
            --user=*|--group=*|--host=*|--prompt=*|--close-from=*|--command-timeout=*|--chroot=*|--chdir=*|-*)
              ((++pos)) ;;
            *) break ;;
          esac
        done
        while ((pos < count)) && chromarchy::is_assignment "${_chromarchy_words_val[pos]}"; do ((++pos)); done
        ((wrapper_query)) && pos=$count
        ;;
      env)
        ((++pos))
        while ((pos < count)); do
          arg=${_chromarchy_words_val[pos]}
          case $arg in
            --) ((++pos)); break ;;
            -u|-C|-a|--unset|--chdir|--argv0) ((pos+=2)) ;;
            -S|--split-string)
              # The next token is a complete command line interpreted by env.
              # Guessing inside it would create misleading danger highlights.
              pos=$count
              ;;
            --unset=*|--chdir=*|--argv0=*|-u?*|-C?*|-a?*|-*) ((++pos)) ;;
            *)
              if chromarchy::is_assignment "$arg"; then
                ((++pos))
              else
                break
              fi
              ;;
          esac
        done
        ;;
      command)
        command_pos=$pos
        ((++pos))
        command_query=0
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -v|-V) command_query=1; ((++pos)) ;;
            -p) ((++pos)) ;;
            -*) ((++pos)) ;;
            *) break ;;
          esac
        done
        if ((command_query)); then
          chromarchy::add_span_token "${_chromarchy_words_idx[command_pos]}" inspect
          while ((pos < count)); do
            [[ ${_chromarchy_words_val[pos]} == -* ]] ||
              chromarchy::add_span_token "${_chromarchy_words_idx[pos]}" inspect
            ((++pos))
          done
        fi
        ;;
      exec)
        ((++pos))
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -a) ((pos+=2)) ;;
            -a?*|-*) ((++pos)) ;;
            *) break ;;
          esac
        done
        ;;
      builtin|nohup|setsid)
        ((++pos))
        while ((pos < count)) && [[ ${_chromarchy_words_val[pos]} == -* ]]; do
          [[ ${_chromarchy_words_val[pos]} == -- ]] && { ((++pos)); break; }
          ((++pos))
        done
        ;;
      time)
        ((++pos))
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -f|-o|--format|--output) ((pos+=2)) ;;
            -*) ((++pos)) ;;
            *) break ;;
          esac
        done
        ;;
      !) ((++pos)) ;;
      timeout)
        ((++pos))
        while ((pos < count)) && [[ ${_chromarchy_words_val[pos]} == -* ]]; do
          case ${_chromarchy_words_val[pos]} in
            -k|--kill-after|-s|--signal) ((pos+=2)) ;;
            *) ((++pos)) ;;
          esac
        done
        ((pos < count)) && ((++pos)) # duration
        ;;
      nice)
        ((++pos))
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -n|--adjustment) ((pos+=2)) ;;
            -n?*|--adjustment=*|-*) ((++pos)) ;;
            *) break ;;
          esac
        done
        ;;
      stdbuf)
        ((++pos))
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -i|-o|-e|--input|--output|--error) ((pos+=2)) ;;
            -i?*|-o?*|-e?*|--input=*|--output=*|--error=*|-*) ((++pos)) ;;
            *) break ;;
          esac
        done
        ;;
      ionice)
        ((++pos))
        process_target=0
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -p|-P|-u|--pid|--pgid|--uid) process_target=1; ((pos+=2)) ;;
            --pid=*|--pgid=*|--uid=*) process_target=1; ((++pos)) ;;
            -c|-n|--class|--classdata) ((pos+=2)) ;;
            --class=*|--classdata=*|-*) ((++pos)) ;;
            *) break ;;
          esac
        done
        ((process_target)) && pos=$count
        ;;
      taskset)
        ((++pos))
        process_target=0
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -p|--pid) process_target=1; ((++pos)) ;;
            -*) ((++pos)) ;;
            *) break ;;
          esac
        done
        if ((process_target)); then
          pos=$count
        else
          ((pos < count)) && ((++pos)) # CPU mask/list
        fi
        ;;
      chrt)
        ((++pos))
        process_target=0
        while ((pos < count)); do
          case ${_chromarchy_words_val[pos]} in
            --) ((++pos)); break ;;
            -p|--pid|-m|--max) process_target=1; ((++pos)) ;;
            -T|-P|-D|--sched-runtime|--sched-period|--sched-deadline) ((pos+=2)) ;;
            --sched-runtime=*|--sched-period=*|--sched-deadline=*|-*) ((++pos)) ;;
            *) break ;;
          esac
        done
        if ((process_target)); then
          pos=$count
        else
          ((pos < count)) && ((++pos)) # scheduling priority
        fi
        ;;
      if|then|elif|else|while|until|do|coproc)
        ((++pos))
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

chromarchy::explain() {
  local text=$* i token range
  if [[ ! $text ]]; then
    printf 'chroma explain: provide a command line to inspect.\n' >&2
    return 2
  fi

  chromarchy::classify_line "$text"
  if ((${#CHROMA_SPAN_START[@]} == 0)); then
    printf 'No semantic highlights for: %q\n' "$text"
    return 0
  fi

  printf '%-12s %-11s %s\n' CATEGORY RANGE TOKEN
  for i in "${!CHROMA_SPAN_START[@]}"; do
    token=${text:CHROMA_SPAN_START[i]:CHROMA_SPAN_END[i]-CHROMA_SPAN_START[i]}
    range="${CHROMA_SPAN_START[i]}..${CHROMA_SPAN_END[i]}"
    printf '%-12s %-11s %q\n' "${CHROMA_SPAN_CATEGORY[i]}" "$range" "$token"
  done
}

# shellcheck shell=bash

[[ ${CHROMA_LAYER_READY:-0} == 1 ]] && return 0

if ! declare -F 'ble/highlight/layer:{selection}/declare' &>/dev/null; then
  printf 'Omarchy Chroma: incompatible ble.sh build (selection layer API missing).\n' >&2
  return 1
fi

'ble/highlight/layer:{selection}/declare' omarchy_chroma

function ble/highlight/layer:omarchy_chroma/initialize-vars {
  'ble/highlight/layer:{selection}/initialize-vars' omarchy_chroma
}

function ble/highlight/layer:omarchy_chroma/update {
  local text=$1 ret category i
  local sel=() gflags=()

  chromarchy::classify_line "$text"
  for i in "${!CHROMA_SPAN_START[@]}"; do
    category=${CHROMA_SPAN_CATEGORY[i]}
    ble/color/gspec2g "${CHROMA_STYLES[$category]}"
    sel+=("${CHROMA_SPAN_START[i]}" "${CHROMA_SPAN_END[i]}")
    gflags+=("$ret")
  done
  'ble/highlight/layer:{selection}/update' omarchy_chroma "$text"
}

function ble/highlight/layer:omarchy_chroma/getg {
  'ble/highlight/layer:{selection}/getg' omarchy_chroma "$@"
}

_chromarchy_has_layer=0
# shellcheck disable=SC2154 # provided by ble.sh
for _chromarchy_layer in "${_ble_highlight_layer_list[@]}"; do
  [[ $_chromarchy_layer == omarchy_chroma ]] && _chromarchy_has_layer=1
done
if ((_chromarchy_has_layer == 0)); then
  ble/array#insert-after _ble_highlight_layer_list syntax omarchy_chroma
fi
unset _chromarchy_layer _chromarchy_has_layer

CHROMA_LAYER_READY=1

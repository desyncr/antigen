export _ZCACHE_PAYLOAD_PATH="$_ANTIGEN_INSTALL_DIR/.cache/.zcache-payload"
export _ZCACHE_META_PATH="$_ANTIGEN_INSTALL_DIR/.cache/.zcache-meta"
local -a _ZCACHE_BUNDLES

-zcache-process-source () {
  cat $1 \
    | sed $'/\${0/i\\\n__ZCACHE_FILE_PATH=\''$1$'\'\n' \
    | sed -e "s/\${0/\${__ZCACHE_FILE_PATH/" \
    | sed $'/\$0/i\\\n__ZCACHE_FILE_PATH=\''$1$'\'\n' \
    | sed -e "s/\$0/\$__ZCACHE_FILE_PATH/"
}

-zcache-generate-cache () {
  for bundle in $_ZCACHE_BUNDLES; do
    -zcache-antigen-bundle "${=bundle}"
  done

  local _zcache_extensions_paths
  local _zcache_bundles_meta

  echo "#-- START ZCACHE GENERATED FILE" >>! $_ZCACHE_PAYLOAD_PATH;
  echo "#-- GENERATED: $(date)" >>! $_ZCACHE_PAYLOAD_PATH;
  for bundle in $_ZCACHE_BUNDLES; do
    # -antigen-load-list "$url" "$loc" "$make_local_clone"
    eval "$(-antigen-parse-bundle ${=bundle})"
    _zcache_bundles_meta="$url $loc $branch $make_local_clone $btype\n$_zcache_bundles_meta"
    # url=$(-antigen-get-clone-dir "$url")
    -antigen-load-list "$url" "$loc" "$make_local_clone" | while read line; do
      echo "#-- SOURCE: $line" >>! $_ZCACHE_PAYLOAD_PATH
      if [[ -f "$line" ]]; then
          -zcache-process-source "$line" >>! $_ZCACHE_PAYLOAD_PATH
      elif [[ -d "$line" ]]; then
          _zcache_extensions_paths="$line\n$_zcache_extensions_paths"
      fi
      echo ";#-- END SOURCE\n" >>! $_ZCACHE_PAYLOAD_PATH
    done
  done
  echo "fpath=($_zcache_extensions_paths $fpath);" >>! $_ZCACHE_PAYLOAD_PATH
  echo "unset __ZCACHE_FILE_PATH" >>! $_ZCACHE_PAYLOAD_PATH
  echo "export _ANTIGEN_BUNDLE_RECORD=\"${(j:\n:)_ZCACHE_BUNDLES}\"" >>! $_ZCACHE_PAYLOAD_PATH
  echo "export _ZCACHE_CACHE_LOADED=true" >>! $_ZCACHE_PAYLOAD_PATH
  echo "#-- END ZCACHE GENERATED FILE" >>! $_ZCACHE_PAYLOAD_PATH;

  echo "$_zcache_bundles_meta" >>! $_ZCACHE_META_PATH
}

-zcache-antigen-hook () {
  if [[ "$1" == "theme" ]]; then
    antigen-theme "$2" "$3" "$4"
    return
  fi

  if [[ "$1" == "apply" ]]; then
    -zcache-unhook-antigen
    ! -zcache-cache-exists && -zcache-generate-cache
    [[ ! $_ZCACHE_CACHE_LOADED ]] && -zcache-load-cache
  else
    _ZCACHE_BUNDLES+=("$*")
  fi
}

-zcache-unhook-antigen () {
  eval "function $(functions -- -zcache-antigen | sed 's/-zcache-//')"
  eval "function $(functions -- -zcache-antigen-bundles | sed 's/-zcache-//')"
  eval "function $(functions -- -zcache-antigen-bundle | sed 's/-zcache-//')"
  eval "function $(functions -- -zcache-antigen-apply | sed 's/-zcache-//')"
}

-zcache-hook-antigen () {
  # Hook into various functions
  eval "function -zcache-$(functions -- antigen)"
  antigen () { -zcache-antigen-hook "$@"}
  eval "function -zcache-$(functions -- antigen-bundles)"
  antigen-bundles () { while read line; do -zcache-antigen-hook "${=line}"; done}
  eval "function -zcache-$(functions -- antigen-bundle)"
  antigen-bundle () { -zcache-antigen-hook "$@"}
  eval "function -zcache-$(functions -- antigen-apply)"
  antigen-apply () { -zcache-antigen-hook "$@"}
}

-zcache-start () {
  -zcache-hook-antigen
}

-zcache-cache-exists () {
  [[ -f "$_ZCACHE_PAYLOAD_PATH" ]] && return true
}

-zcache-load-cache () {
  source "$_ZCACHE_PAYLOAD_PATH"
  unfunction -- -zcache-generate-cache -zcache-antigen-hook -zcache-unhook-antigen \
  -zcache-hook-antigen -zcache-start -zcache-antigen -zcache-antigen-apply \
  -zcache-antigen-bundle -zcache-antigen-bundles
}

antigen-cache-reset () {
  [[ -f "$_ZCACHE_META_PATH" ]] && rm "$_ZCACHE_META_PATH"
  [[ -f "$_ZCACHE_PAYLOAD_PATH" ]] && rm "$_ZCACHE_PAYLOAD_PATH"
  echo 'Done. Please open a new shell to see the changes.'
}

antigen-init () {
  if [[ -zcache-cache-exists ]]; then
    -zcache-load-cache
  else
    source "$1"
  fi
}

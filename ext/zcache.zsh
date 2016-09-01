local _ZCACHE_PAYLOAD_PATH="$_ANTIGEN_INSTALL_DIR/.cache/.zcache-payload"
local _ZCACHE_META_PATH="$_ANTIGEN_INSTALL_DIR/.cache/.zcache-meta"
local _ZCACHE_CACHE_LOADED=false
local -a _ZCACHE_BUNDLES

-zcache-bundle-file-list () {
    local url="$1"
    local loc="$2"
    local make_local_clone="$3"

    # The full location where the plugin is located.
    local location
    if $make_local_clone; then
        location="$(-antigen-get-clone-dir "$url")/"
    else
        location="$url/"
    fi

    [[ $loc != "/" ]] && location="$location$loc"

    if [[ -f "$location" ]]; then
        echo "$location"

    else

        # Source the plugin script.
        # FIXME: I don't know. Looks very very ugly. Needs a better
        # implementation once tests are ready.
        local script_loc="$(ls "$location" | grep '\.plugin\.zsh$' | head -n1)"

        if [[ -f $location/$script_loc ]]; then
            # If we have a `*.plugin.zsh`, source it.
            echo "$location/$script_loc"

        elif [[ -f $location/init.zsh ]]; then
            echo "$location/init.zsh"

        elif ls "$location" | grep -l '\.zsh$' &> /dev/null; then
            # If there is no `*.plugin.zsh` file, source *all* the `*.zsh`
            # files.
            for script ($location/*.zsh(N)) { echo "$script" }

        elif ls "$location" | grep -l '\.sh$' &> /dev/null; then
            # If there are no `*.zsh` files either, we look for and source any
            # `*.sh` files instead.
            for script ($location/*.sh(N)) { echo "$script" }

        fi
    fi

    echo "$location"
}

-zcache-generate-cache () {
  for bundle in $_ZCACHE_BUNDLES; do
    echo "-zcache-antigen-bundle $bundle"
  done

  for bundle in $_ZCACHE_BUNDLES; do
      -antigen-resolve-bundle-url "$bundle" |
      eval "-zcache-bundle-file-list $bundle" | while read line; do
        echo "> $line"
      done
  done
}

-zcache-antigen-hook () {
  if [[ "$1" == "apply" ]]; then
    -zcache-unhook-antigen
  fi

  # $_ZCACHE_CACHE_LOADED && return
  if [[ "$1" == "apply" ]]; then
    -zcache-generate-cache
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
  antigen-bundles () { while read line; do -zcache-antigen-hook "$line"; done}
  eval "function -zcache-$(functions -- antigen-bundle)"
  antigen-bundle () { -zcache-antigen-hook "$@"}
  eval "function -zcache-$(functions -- antigen-apply)"
  antigen-apply () { -zcache-antigen-hook "$@"}
}

-zcache-start () {
  -zcache-hook-antigen
  if [ -f "$_ZCACHE_PAYLOAD_PATH" ] ; then
    source "$_ZCACHE_PAYLOAD_PATH" # cache exists, load it
    _ANTIGEN_BUNDLE_RECORD=$(cat $_ZCACHE_META_PATH)
    _ZCACHE_CACHE_LOADED=true
  fi
}

antigen-cache-reset () {
  [ -f "$_ZCACHE_META_PATH" ] && rm "$_ZCACHE_META_PATH"
  [ -f "$_ZCACHE_PAYLOAD_PATH" ] && rm "$_ZCACHE_PAYLOAD_PATH"
  echo 'Done. Please open a new shell to see the changes.'
}

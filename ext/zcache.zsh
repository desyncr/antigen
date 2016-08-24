# Can't be changed after initialization
local _ANTIGEN_CACHE_DIR=${_ANTIGEN_CACHE_DIR:-$_ANTIGEN_INSTALL_DIR/.cache/}
local _ANTIGEN_CACHE_ENABLED=${_ANTIGEN_CACHE_ENABLED:-true}
local _ANTIGEN_CACHE_MINIFY_ENABLED=${_ANTIGEN_CACHE_MINIFY_ENABLED:-true}
local _ANTIGEN_CACHE_FIX_SCRIPT_SOURCE=${_ANTIGEN_CACHE_FIX_SCRIPT_SOURCE:-true}
_ZCACHE_PAYLOAD_LOADED=false

# Be sure .cache directory exists
[[ ! -e $_ANTIGEN_CACHE_DIR ]] && mkdir $_ANTIGEN_CACHE_DIR

_ZCACHE_META_PATH="$_ANTIGEN_CACHE_DIR/.zcache-meta"
_ZCACHE_PAYLOAD_PATH="$_ANTIGEN_CACHE_DIR/.zcache-payload"

local _zcache_extensions_paths=""
local _zcache_antigen_bundle_record=""

# TODO Merge this code with -antigen-load function to avoid duplication
-antigen-dump-file-list () {

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

# TODO merge this code with -antigen-bundle to avoid duplication
-antigen-bundle-record () {
    # Bundle spec arguments' default values.
    local url="$ANTIGEN_DEFAULT_REPO_URL"
    local loc=/
    local branch=
    local no_local_clone=false
    local btype=plugin

    # Parse the given arguments. (Will overwrite the above values).
    eval "$(-antigen-parse-args \
            'url?, loc? ; branch:?, no-local-clone?, btype:?' \
            "$@")"

    # Check if url is just the plugin name. Super short syntax.
    if [[ "$url" != */* ]]; then
        loc="plugins/$url"
        url="$ANTIGEN_DEFAULT_REPO_URL"
    fi

    # Resolve the url.
    url="$(-antigen-resolve-bundle-url "$url")"

    # Add the branch information to the url.
    if [[ ! -z $branch ]]; then
        url="$url|$branch"
    fi

    # The `make_local_clone` variable better represents whether there should be
    # a local clone made. For cloning to be avoided, firstly, the `$url` should
    # be an absolute local path and `$branch` should be empty. In addition to
    # these two conditions, either the `--no-local-clone` option should be
    # given, or `$url` should not a git repo.
    local make_local_clone=true
    if [[ $url == /* && -z $branch &&
            ( $no_local_clone == true || ! -d $url/.git ) ]]; then
        make_local_clone=false
    fi

    # Add the theme extension to `loc`, if this is a theme.
    if [[ $btype == theme && $loc != *.zsh-theme ]]; then
        loc="$loc.zsh-theme"
    fi

    echo "$url $loc $btype $make_local_clone"
}

# Caches antigen-bundle/theme etc
-zcache-start-capture () {
    -zcache-intercept-bundle

    zcache__capture__file=$1
    zcache__meta__file=$2

    # remove prior meta file
    [ -f "$zcache__meta__file" ] && rm -f "$zcache__meta__file"

    # remove prior cache file
    [ -f "$zcache__capture__file" ] && rm -f $zcache__capture__file
    zcache__capture__file_created=0

    # save current -antigen-load and shim in a version
    # that logs calls to the catpure file
    eval "function -original$(functions -- -antigen-load)"
    -antigen-load () {

        [ -z "$zcache__capture__file_created" ] && echo " # START ZCACHE GENERATED FILE" >>! $zcache__capture__file;
        zcache__capture__file_created=true

        -antigen-dump-file-list "$1" "$2" "$3" | while read line; do
            if [[ ! $line == "" ]]; then
                if [[ -f "$line" ]]; then
                    echo " # SOURCE: $line" >>! $zcache__capture__file

                    # Fix script sourcing if there is a reference to $0 or ${0}
                    if $_ANTIGEN_CACHE_FIX_SCRIPT_SOURCE; then
                        # TODO suffix __ZCACHE_FILE_PATH variable name with a PRN (from chksum?)
                        # to avoid variable collision
                        cat $line \
                            | sed $'/\${0/i\\\n__ZCACHE_FILE_PATH=\''$line$'\'\n' | sed -e "s/\${0/\${__ZCACHE_FILE_PATH/" \
                            | sed $'/\$0/i\\\n__ZCACHE_FILE_PATH=\''$line$'\'\n' | sed -e "s/\$0/\$__ZCACHE_FILE_PATH/" \
                            >>! $zcache__capture__file

                    else
                        cat $line >>! $zcache__capture__file
                    fi

                    echo ";\n" >>! $zcache__capture__file

                    -original-antigen-load "$@"

                elif [[ -d "$line" ]]; then
                    # load autocompletion
                    fpath=($line $fpath)
                    _zcache_extensions_paths="$line $_zcache_extensions_paths"
                fi
            fi
        done
    }
}

# Stops caching
-zcache-stop-capture () {
    -zcache-deintercept-bundle
    # unset catpure file var and restore intercepted -antigen-load
    unset zcache__capture__file
    eval "function $(functions -- -original-antigen-load | sed 's/-original//')"
}

# Disable antigen-bundle
-zcache-disable-bundle () {
    eval "function -original-$(functions -- antigen-bundle)"
    antigen-bundle () {
        _ANTIGEN_BUNDLE_RECORD="$_ANTIGEN_BUNDLE_RECORD\n$(-antigen-bundle-record $@)"
        _zcache_antigen_bundle_record="$_zcache_antigen_bundle_record\n$(-antigen-bundle-record $@)"
    }
}

# Enable antigen-bundle
-zcache-enable-bundle () {
    eval "function $(functions -- -original-antigen-bundle | sed 's/-original-//')"
}

# Intercepts antigen-bundle in order to have a list of bundled plugins (for antigen-clean)
-zcache-intercept-bundle () {
    eval "function -intercepted-$(functions -- antigen-bundle)"
    _zcache_antigen_bundle_record=""
    antigen-bundle () {
        echo "$@" >>! "$_ZCACHE_META_PATH"
        _zcache_antigen_bundle_record="$_zcache_antigen_bundle_record\n$(-antigen-bundle-record $@)"
        -intercepted-antigen-bundle "$@"
    }
}

# De-intercepts antigen-bundle
-zcache-deintercept-bundle () {
    eval "function $(functions -- -intercepted-antigen-bundle | sed 's/-intercepted-//')"
}

# Intercepts antigen-apply function in order to have a 'done' event
-zcache-intercept-apply () {
    eval "function -intercepted-$(functions -- antigen-apply)"
    antigen-apply () {
        -intercepted-antigen-apply "$@"
        -zcache-enable-bundle
        -zcache-deintercept-apply
        -zcache-done
        _ANTIGEN_BUNDLE_RECORD=$(cat $_ZCACHE_META_PATH)
    }
}

# De-intercept antigen-apply
-zcache-deintercept-apply () {
    eval "function $(functions -- -intercepted-antigen-apply | sed 's/-intercepted-//')"
}

-zcache-intercept-update () {
    eval "function -intercepted-$(functions -- -antigen-update)"
    antigen-update () {
        -zcache-clear
        -intercepted-antigen-update "$@"
        echo 'Done.'
        echo 'Please open a new shell to see the changes.'
    }
}

# Loads cache if available otherwise starts to cache bundle/theme etc
-zcache-start () {
    -zcache-intercept-apply

    if [ -f "$_ZCACHE_PAYLOAD_PATH" ] ; then
        source "$_ZCACHE_PAYLOAD_PATH" # cache exists, load it
        -zcache-disable-bundle          # disable bundle so it won't load bundle twice
        _ZCACHE_PAYLOAD_LOADED=true
        _ANTIGEN_BUNDLE_RECORD=$(cat $_ZCACHE_META_PATH)
    else
        -zcache-start-capture "$_ZCACHE_PAYLOAD_PATH" "$_ZCACHE_META_PATH"
    fi
}

# Minifies and exports fpath to the final cache payload
-zcache-done () {
    echo "fpath=($_zcache_extensions_paths $fpath)" >>! $_ZCACHE_PAYLOAD_PATH
    echo "export _ANTIGEN_BUNDLE_RECORD=\"\$_ANTIGEN_BUNDLE_RECORD$_zcache_antigen_bundle_record\"" >>! $_ZCACHE_PAYLOAD_PATH
    echo  " # END ZCACHE GENERATED FILE" >>! $_ZCACHE_PAYLOAD_PATH

    if $_ANTIGEN_CACHE_MINIFY_ENABLED; then
        sed -i '/^#.*/d' $_ZCACHE_PAYLOAD_PATH
        sed -i '/^$/d' $_ZCACHE_PAYLOAD_PATH
        sed -i '/./!d' $_ZCACHE_PAYLOAD_PATH
    fi

    -zcache-stop-capture
}

# Remove cache payload - efectively flushing out the cache
-zcache-clear () {
    [ -f "$_ZCACHE_PAYLOAD_PATH" ] && rm "$_ZCACHE_PAYLOAD_PATH"
}

# Resets cache and starts capturing
-zcache-restart () {
    -zcache-start-capture "$_ZCACHE_PAYLOAD_PATH"
}

# antigen cache-reset command
antigen-cache-reset () {
  local force=false
  if [[ $1 == --force ]]; then
      force=true
  fi

  if $force || (echo -n '\nClear all cache? [y/N] '; read -q); then
      echo
      -zcache-clear
      echo
      echo 'Done.'
      echo 'Please open a new shell to see the changes.'
  else
      echo
      echo Nothing deleted.
  fi
}

# antigen init /path/to/.antigenrc
antigen-init () {
    # Backward compatibility
    if $_ZCACHE_PAYLOAD_LOADED; then
        return
    fi

    if [ -f "$_ZCACHE_PAYLOAD_PATH" ] ; then
        _ANTIGEN_BUNDLE_RECORD=$(cat $_ZCACHE_META_PATH)
        source "$_ZCACHE_PAYLOAD_PATH" # cache exists, load it
    else
        source "$@"
    fi
}

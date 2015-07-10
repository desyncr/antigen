# Can't be changed after initialization
local _ANTIGEN_CACHE_DIR=${_ANTIGEN_CACHE_DIR:-$_ANTIGEN_INSTALL_DIR/.cache/}
local _ANTIGEN_CACHE_ENABLED=${_ANTIGEN_CACHE_ENABLED:-false}
local _ANTIGEN_CACHE_MINIFY_ENABLED=${_ANTIGEN_CACHE_MINIFY_ENABLED:-true}
local _ANTIGEN_CACHE_FIX_SCRIPT_SOURCE=${_ANTIGEN_CACHE_FIX_SCRIPT_SOURCE:-true}

# Be sure .cache directory exists
[[ ! -e $_ANTIGEN_CACHE_DIR ]] && mkdir $_ANTIGEN_CACHE_DIR

local _zcache_extensions_paths=""
local _zcache_context=""
local _zcache_capturing=false
local _zcache_meta_path=""
local _zcache_payload_path=""
local _zcache_antigen_bundle_record=""
local dots__capture__file_load=""
local dots__capture__file=""

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
            # If we have a `init.zsh`
            # if (( $+functions[pmodload] )); then
                # If pmodload is defined pmodload the module. Remove `modules/`
                # from loc to find module name.
                #pmodload "${loc#modules/}"
            # else
                # Otherwise source it.
                echo "$location/init.zsh"
            # fi

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

function -dots-start-capture () {
    dots__capture__file=$1
    dots__capture__file_load=$2
    _zcache_extensions_paths=""

    # remove prior cache file
    [ -f "$dots__capture__file" ] && rm -f $dots__capture__file

    echo " # START ZCACHE GENERATED FILE" >>! $dots__capture__file

    # save current -antigen-load and shim in a version
    # that logs calls to the catpure file
    eval "function -dots-original$(functions -- -antigen-load)"
    function -antigen-load () {
        -antigen-dump-file-list "$1" "$2" "$3" | while read line; do
            if [[ ! $line == "" ]]; then
                if [[ -f "$line" ]]; then
                    echo " # SOURCE: $line" >>! $dots__capture__file

                    # Fix script sourcing if there is a reference to $0 or ${0}
                    if $_ANTIGEN_CACHE_FIX_SCRIPT_SOURCE; then
                        # TODO suffix __ZCACHE_FILE_PATH variable name with a PRN (from chksum?)
                        # to avoid variable collision
                        cat $line \
                            | sed "/\${0/i__ZCACHE_FILE_PATH='"$line"'" | sed -e "s/\${0/\${__ZCACHE_FILE_PATH/" \
                            | sed "/\$0/i__ZCACHE_FILE_PATH='"$line"'" | sed -e "s/\$0/\$__ZCACHE_FILE_PATH/" \
                            >>! $dots__capture__file

                    else
                        cat $line >>! $dots__capture__file
                    fi

                    echo ";\n" >>! $dots__capture__file

                    -dots-original-antigen-load "$@"

                elif [[ -d "$line" ]]; then
                    # load autocompletion
                    fpath=($line $fpath)
                    _zcache_extensions_paths="$line $_zcache_extensions_paths"
                fi
            fi
        done
    }
}

function -dots-stop-capture () {
    # unset catpure file var and restore intercepted -antigen-load
    unset dots__capture__file
    eval "function $(functions -- -dots-original-antigen-load | sed 's/-dots-original//')"
}

function -dots-disable-bundle () {
    eval "function -bundle-original-$(functions -- antigen-bundle)"
    function antigen-bundle () {}
}

function -dots-enable-bundle () {
    eval "function $(functions -- -bundle-original-antigen-bundle | sed 's/-bundle-original-//')"
}

function -dots-intercept-bundle () {
    eval "function -bundle-intercepted-$(functions -- antigen-bundle)"
    _zcache_antigen_bundle_record=""
    function antigen-bundle () {
        echo "$@" >>! $_zcache_meta_path
        _zcache_antigen_bundle_record="$_zcache_antigen_bundle_record\n$(-antigen-bundle-record $@)"
        -bundle-intercepted-antigen-bundle "$@"
    }
}

function -dots-deintercept-bundle () {
    eval "function $(functions -- -bundle-intercepted-antigen-bundle | sed 's/-bundle-intercepted-//')"
}

function -zcache-start () {
    if ! $_ANTIGEN_CACHE_ENABLED; then
        return
    fi

    # Set up the context
    _zcache_context="$1"
    _zcache_capturing=false
    _zcache_meta_path="$_ANTIGEN_CACHE_DIR/.zcache.$_zcache_context-meta"
    _zcache_payload_path="$_ANTIGEN_CACHE_DIR/.zcache.$_zcache_context-payload"

    if [ -f "$_zcache_payload_path" ] ; then
        source "$_zcache_payload_path" # cache exists, load it
        -dots-disable-bundle          # disable bundle so it won't load bundle twice
    else
        _zcache_capturing=true       # mark capturing
        -dots-start-capture $_zcache_payload_path
        -dots-intercept-bundle
    fi
}

function -zcache-done () {
    if ! $_ANTIGEN_CACHE_ENABLED; then
        return
    fi

    if ! $_zcache_capturing; then
        -dots-enable-bundle
        return
    else
        -dots-deintercept-bundle
    fi

    echo "fpath=($_zcache_extensions_paths $fpath)" >>! $_zcache_payload_path
    echo "export _ANTIGEN_BUNDLE_RECORD=\"\$_ANTIGEN_BUNDLE_RECORD$_zcache_antigen_bundle_record\"" >>! $_zcache_payload_path
    echo  " # END ZCACHE GENERATED FILE" >>! $_zcache_payload_path

    if $_ANTIGEN_CACHE_MINIFY_ENABLED; then
        sed -i '/^#.*/d' $_zcache_payload_path
        sed -i '/^$/d' $_zcache_payload_path
        sed -i '/./!d' $_zcache_payload_path
    fi

    -dots-stop-capture $_zcache_meta_path
}

function -zcache-clear () {
    if [ -d "$_ANTIGEN_CACHE_DIR" ]; then
        # TODO how compatible is this -A flag?
        ls -A "$_ANTIGEN_CACHE_DIR" | while read file; do
            rm "$_ANTIGEN_CACHE_DIR/$file"
        done
    fi
}

function -zcache-rebuild () {
    local bundles=""
    local context=""

    ls -A "$_ANTIGEN_CACHE_DIR" | while read file; do
        if [[ $file == *-meta ]]; then
            context=$(echo $file | sed 's/.zcache.//' | sed 's/-meta//')
            -zcache-start $context
            cat "$_ANTIGEN_CACHE_DIR/$file" | while read line; do
                eval "antigen-bundle $line"
            done
            -zcache-done
        fi
    done
}

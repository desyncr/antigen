# Syntaxes
#   antigen-bundle <url> [<loc>=/]
# Keyword only arguments:
#   branch - The branch of the repo to use for this bundle.
antigen-bundle () {
  if [[ -z "$1" ]]; then
    printf "Antigen: Must provide a bundle url or name.\n" >&2
    return 1
  fi

  typeset -A bundle
  -antigen-parse-args 'bundle' "$@"

  local record="${bundle[url]} ${bundle[loc]} ${bundle[btype]} ${bundle[make_local_clone]}"
  if [[ $_ANTIGEN_WARN_DUPLICATES == true && ! ${_ANTIGEN_BUNDLE_RECORD[(I)$record]} == 0 ]]; then
    printf "Seems %s is already installed!\n" ${bundle[name]}
    return 1
  fi
 
  if ! -antigen-bundle-install ${(kv)bundle}; then
    return 1
  fi

  # Load the plugin.
  if ! -antigen-load ${(kv)bundle}; then
    printf "Antigen: Failed to load %s.\n" ${bundle[btype]}  >&2
    return 1
  fi
  
  # Only add it to the record if it could be installed and loaded.
  _ANTIGEN_BUNDLE_RECORD+=("$record")
}

#
# Usage:
#   -antigen-bundle-install <record>
# Returns:
#   1 if it fails to install bundle
-antigen-bundle-install () {
  typeset -A bundle; bundle=($@)

  # Ensure a clone exists for this repo, if needed.
  # Get the clone's directory as per the given repo url and branch.
  local bundle_path="${bundle[path]}"
  # Clone if it doesn't already exist.
  local start=$(date +'%s')
  if [[ -d "$bundle_path" ]]; then
    return 0
  fi

  printf "Installing %s... " "${bundle[name]}"

  if ! -antigen-ensure-repo "${bundle[url]}"; then
    # Return immediately if there is an error cloning
    printf "Error! Activate logging and try again.\n";
    return 1
  fi

  local took=$(( $(date +'%s') - $start ))
  printf "Done. Took %ds.\n" $took
}

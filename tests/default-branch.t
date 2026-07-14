A plugin repository whose default branch is `main`, not `master`.

  $ MAIN_PLUGIN_DIR=$TESTDIR/main-branch-plugin
  $ mkdir $MAIN_PLUGIN_DIR
  $ alias pgm='git --git-dir "$MAIN_PLUGIN_DIR/.git" --work-tree "$MAIN_PLUGIN_DIR"'
  $ pgm init -q -b main
  $ pgm config user.name test
  $ pgm config user.email test@test.test
  $ echo 'alias hehe-main="echo hehe from main"' > $MAIN_PLUGIN_DIR/aliases.zsh
  $ pgm add .
  $ pgm commit -qm 'Initial commit'

Load the plugin with no explicit branch; antigen clones and checks out
`main` instead of failing on (or assuming) `master`.

  $ antigen bundle $MAIN_PLUGIN_DIR &> /dev/null
  $ hehe-main
  hehe from main

  $ git --git-dir="$(-antigen-get-clone-dir $MAIN_PLUGIN_DIR)/.git" rev-parse --abbrev-ref HEAD
  main

Updating the plugin continues to track `main`, not `master`.

  $ echo 'alias hehe-main="echo hehe from main, updated"' > $MAIN_PLUGIN_DIR/aliases.zsh
  $ pgm commit -qam 'Updated message'
  $ antigen-update $MAIN_PLUGIN_DIR
  Updating */main-branch-plugin@master... Done. Took *s. (glob)

  $ git --git-dir="$(-antigen-get-clone-dir $MAIN_PLUGIN_DIR)/.git" rev-parse --abbrev-ref HEAD
  main

Set up functions and env variables:

  $ ANTIGEN_LOG=/dev/stdout # We wanna see debug output
  $ function git() { echo "git $@" } # Wrap git to avoid the network
  $ REPO_NAME=user/repo
  $ REPO_URL=https://github.com/$REPO_NAME.git

Ensure repo default args missing url:

  $ -antigen-ensure-repo 2>&1
  Antigen: Missing url argument.
  [1]

Clones a repository if it's not cloned already, letting git resolve the
remote's own default branch instead of assuming one:

  $ -antigen-ensure-repo $REPO_URL
  git clone .* -- https://github.com/user/repo.git .*user/repo (re)

Ignore update argument if there is no repo cloned:

  $ -antigen-ensure-repo $REPO_URL true
  git clone .* -- https://github.com/user/repo.git .*user/repo (re)

Effectively update a repository already cloned, tracking whatever branch
its local origin/HEAD reports (here, a non-master default):

  $ mkdir -p $(-antigen-get-clone-dir $REPO_URL) # Fake repository clone
  $ function git() {
  >   if [[ "$*" == *symbolic-ref* ]]; then
  >     echo "refs/remotes/origin/main"
  >   else
  >     echo "git $@"
  >   fi
  > }
  $ -antigen-ensure-repo $REPO_URL true
  git --git-dir=.*/user/repo/.git .* checkout main (re)
  git --git-dir=.*/user/repo/.git .* pull origin main (re)
  git --git-dir=.*/user/repo/.git .* submodule update .* (re)

Falls back to master when the tracked branch can't be resolved from the
existing clone:

  $ function git() {
  >   if [[ "$*" == *symbolic-ref* ]]; then
  >     return 1
  >   else
  >     echo "git $@"
  >   fi
  > }
  $ -antigen-ensure-repo $REPO_URL true
  git --git-dir=.*/user/repo/.git .* checkout master (re)
  git --git-dir=.*/user/repo/.git .* pull origin master (re)
  git --git-dir=.*/user/repo/.git .* submodule update .* (re)

Clone especific branch if required:

  $ function git() { echo "git $@" } # Wrap git to avoid the network
  $ rm -r $ANTIGEN_BUNDLES
  $ -antigen-ensure-repo "$REPO_URL|v5.0"
  git clone .* --branch v5.0 -- https://github.com/user/repo.git .*user/repo-v5.0 (re)

source $HOME/antigen/antigen.zsh

if [[ "$_ANTIGEN_INIT_ENABLED" == "true" ]]; then
  antigen init $HOME/antigen/tests/.antigenrc
else
  source $HOME/antigen/tests/.antigenrc
fi


# Load all the source files
for f in $HOME/.private/*.*sh; do
  if [[ -f $f ]]; then
    source $f;
  fi
done
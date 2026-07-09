
# MOST AWESOMEST THING EVER
goto() {
  DESTINATION=$1
  if [ ${#DESTINATION} -eq 0 ]; then
  echo "$DESTINATION"
    return
  fi

  TARGETS=($(find $GOPATH/src -iname $DESTINATION -type d -maxdepth 3))
  TARGET_COUNT=${#TARGETS[@]}
  if [ $TARGET_COUNT -eq 0 ]; then
    echo $fg[orange] "Sorry! No matching dirs"
    return
  elif [ $TARGET_COUNT -eq 1 ]; then
    echo -n "Switching to ${DESTINATION}..."
    cd "${TARGETS}"
  else
    echo -e "\nWe found more than one location matching you input.\n"
    for c in {1..$TARGET_COUNT}; do
      echo "  $c: ${TARGETS[$c]}";
    done
    echo -en "\nPlease choose a destination: "
    read idnum
    itemnum=$(($idnum))
    echo "Switching to ${TARGETS[$itemnum]}"
    cd "${TARGETS[$itemnum]}"
  fi
}

# goto has no completion spec, so Tab was falling back to default filename
# completion in $PWD — that's why `goto MCPLOCKER<Tab>` was matching
# unrelated files like ~/MCPLOCKER-AINSTEIN.md instead of the actual
# project dir. Restrict candidates to what goto actually searches
# ($GOPATH/src, 3 levels deep), so Tab offers real targets and (via the
# case-insensitive matcher-list already set in .zshrc) the correct case.
_goto() {
  local -a projects
  projects=(${(f)"$(find "$GOPATH/src" -maxdepth 3 -type d -exec basename {} \; 2>/dev/null)"})
  _describe 'project' projects
}
compdef _goto goto

# Go list deps that are not standard for the
golist(){
  PROJ=$1
  if [[ -z $1 ]]; then
    PROJ="./..."
  fi

  go list -f '{{.Deps}}' $PROJ | tr "[" " " | tr "]" " " | xargs go list -f '{{if not .Standard}}{{.ImportPath}}{{end}}'
}


# GoSkel creates a project skeleton for golang projects
function goskel(){
  PROJECT=$1
  if [[ -z $1 ]]; then
    echo "Please provide a project name and re-run."
    return
  fi

  # Create directories
  echo "Creating $PROJECT skeleton"
  echo " --> Adding bin, libs and testing directories"
  mkdir -p $PROJECT/{bin,cmd,libs,testing}
  touch $PROJECT/bin/.gitkeep

  # Add flatfiles
  echo " --> Adding license, todos and readme"
  touch $PROJECT/{TODOS,LICENSE,README.md}

  # Add a gitignore
  echo " --> Adding .gitignore"
  echo "bin/*" > $PROJECT/.gitignore

  # Adding a main.go
  echo " --> Adding main.go"
  echo -e "package main\n\nfunc main() {\n\n}\n" | tee $PROJECT/main.go $PROJECT/cmd/$PROJECT.go > /dev/null
  echo -e "package main\n\nimport (\n\t\"testing\"\n)\n\nfunc TestMain(t *testing.T) {\n\n}\n" | tee $PROJECT/main_test.go $PROJECT/cmd/${PROJECT}_test.go > /dev/null

  # Creating makefile
  echo " --> Adding Makefile"
  echo -e "all: test build\n\ntest:\n\nbuild:\n\tgo build -o bin/$PROJECT cmd/${PROJECT}.go" > $PROJECT/Makefile

  # Adding a README
  echo " --> Setting Readme"
  echo -e "# ${PROJECT}\n---\n\n<DESCRIPTION>\n\n## Usage\n\n## Installation\n\n" | tee $PROJECT/README.md > /dev/null

  # Adding Git Init
  echo " --> Creating Git Repo"
  (cd $PROJECT && git init)

  # Return status
  echo "Created project $PROJECT successfully."

}
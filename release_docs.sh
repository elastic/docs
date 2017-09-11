#!/bin/bash
# Build and release all docs when a new version is added

date

USAGE="Usage: release_docs.sh -r <remote_doc_repo> [-n] [-h]."
DOCS_REMOTE=""
PUSH="true"
DOCS_DIR=$PWD

while getopts "r:nh" opt; do
  case $opt in
    r)
      DOCS_REMOTE="$OPTARG"
      echo "Remote docs repo: $DOCS_REMOTE"
      ;;
    n)
      PUSH="false"
      echo "Building only, will not push to $DOCS_REMOTE."
      ;;
    h)
      echo "$USAGE"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      echo "$USAGE"
      exit 1
      ;;
  esac
done

if [[ $DOCS_REMOTE == "" ]] ; then
  echo "Error: No remote specified. You must specify the remote docs repo with the -r option.
       To build only and skip pushing to the specified remote, use the -n option."
  exit 1
fi

printf "Any local changes in your docs repo will be obliterated. Continue? y/N: "
read CONTINUE
if [[ $CONTINUE == "y" ]] ; then
  echo "Syncing with $DOCS_REMOTE/master"
  git reset --hard $DOCS_REMOTE/master
  echo "Deleting contents of $PWD/html."
  rm -Rf html/*
  echo "Building all docs. This is going to take a while. Need a fresh cup of coffee? Or maybe a glass of wine?"
  if ./build_docs.pl --all ; then
    if [[ $PUSH == "true" ]] ; then
      git add -A
      git commit -m "Forced update"
      printf "Ready to push to $DOCS_REMOTE/master. Continue? y/N: "
      read CONTINUE
      if [[ $CONTINUE == "y" ]] ; then
        git push -f $DOCS_REMOTE master
        if [[ $? == 0 ]] ; then
          echo "Successfully built and pushed the docs!"
          echo "It will take a bit for the changes to propagate to the webservers."
          echo "If they don't show up in a timely fashion, try clearing the webserver cache."
          date
          exit 0
        else
          read PUSH_ERROR
          echo "Error: Unable to push docs to $DOCS_REMOTE."
          echo $PUSH_ERROR
          exit 1
        fi
      else
        echo "Successfully built the docs. Skipping the push to $DOCS_REMOTE and exiting."
        date
        exit 0
      fi
    elif [[ $PUSH == "false" ]] ; then
      echo "Successfully built the docs. Not pushing to remote."
      date
    fi
  else
    read BUILD_ERROR
    echo "Error: Doc build failed."
    echo $BUILD_ERROR
    exit 1
  fi
else
  echo "Okay, exiting without doing anything."
  date
  exit 0
fi


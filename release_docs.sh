#!/bin/sh
# Build and release all docs when a new version is added

date

USAGE="Usage: release_docs.sh [-r <remote_doc_repo>] [-n] [-h]"
DOCS_REMOTE=""
PUSH="true"
DOCS_DIR=$PWD

while getopts "r:nh" opt; do
  case $opt in
    r)
	  DOCS_REMOTE="$OPTARG"
      echo "Will push to remote: $DOCS_REMOTE"
      ;;
    n)
      PUSH="false"
      echo "Building only, will not push to remote."
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

if [ $PUSH == "true" ] && [ $DOCS_REMOTE == "" ]; then
  echo "Error: No remote specified. You must specify a remote repo with the -r option, or specify the -n option to skip pushing to the remote repo."
  exit 1
fi

printf "Any local changes in your docs repo will be overwritten. Continue? y/N: "
read CONTINUE
if [ $CONTINUE == "y" ] ; then
  date
  echo "Syncing with docs/master"
  git reset --hard docs/master
  date
  echo "Deleting contents of $PWD/html."
  rm -Rf html/*
  date
  echo "Building all docs. This is going to take a while...need a fresh cup of coffee? Or maybe a glass of wine?"
  if [ ./build_docs.pl --all ] ; then
    if [ $PUSH == "true" ] ; then
      git commit -a -m "Forced update"
      date
      echo "Pushing docs to the remote repo: $DOCS_REMOTE."
      date
      git push -f $DOCS_REMOTE master
      if [ $? == 0 ] ; then
        date
		echo "Successfully built and pushed the docs!"
		echo "It will take a bit for the changes to propagate to the webservers."
        echo "If they don't show up in a timely fashion, try clearing the webserver cache."
		exit 0
      else
        echo "Error: Unable to push docs to the remote."
		exit 1
      fi
    elif [ PUSH == "false"] ; then
      echo "Successfully built the docs. Not pushing to remote."
    fi
  else
    read BUILD_ERROR
    echo "Error: Doc build failed."
    echo $BUILD_ERROR
    exit 1
  fi
fi

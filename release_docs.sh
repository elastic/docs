#!/bin/sh
# Build and release all docs when a new version is added 

USAGE="Usage: release_docs.sh  <remote_docs_repo> [-h]"

while getopts "h" opt; do
  case $opt in
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

if [ "$1" != "" ] ; then
	DOCS_DIR=$PWD
	DOCS_REMOTE=$1
	echo "Fetching the latest changes from $DOCS_REMOTE master."
	git pull $DOCS_REMOTE master
elif [ "$1" == "" ] ; then
	echo "Error: No docs remote specified."
	echo "You must specify the name of the remote docs repo you want to push to: origin, upstream, docs."
	echo "$USAGE"
    exit 1
fi	
  
printf  "This will delete the contents of the $PWD/html directory. Continue? y/N: "
read CONTINUE
if [ $CONTINUE == "y" ] ; then
	echo "Deleting contents of $PWD/html."
 	rm -Rf html/*
	echo "Building all docs. This is going to take a while...need a fresh cup of coffee?"
	if ./build_docs.pl --all ; then
		echo "Pushing docs to the remote repo: $DOCS_REMOTE."
		git push --force $DOCS_REMOTE HEAD
		if [ $? == 0 ] ; then
			echo "Successfully pushed the docs!"
			echo "It will take a bit for the changes to propagate to the webservers."
			exit 0
		else
			echo "Error: Unable to push docs to the remote."
			exit 1
		fi		
	else
		read BUILD_ERROR
		echo "Error: Doc build failed." 
		echo $BUILD_ERROR
		exit 1
	fi			
else
	echo "Ok, then. I won't do anything."
	exit 1
fi


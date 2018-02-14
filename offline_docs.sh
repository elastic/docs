#!/bin/bash
# Modify generated docs in a particular directory to work offline.

date

USAGE="Usage: offline_docs.sh [-d <dir-name>] [-r <dir-name>] [-z] [-o] [-h]."

echo  
echo "NOTICE:"
echo "The documents produced by this utility are intended for customer use only." 
echo "They may be not be published in any other form or hosted on any publicly"
echo "accessible site other than https://elastic.co. "
echo 

while getopts "d:r:zoh" opt; do
  case $opt in
    d)
      HTML_DIR="$OPTARG"
      ;;
    r)
      RESOURCE_DIR="$OPTARG"
      ;;
    z)
      CREATE_ZIP="y"
      ;;
    o)
      START_SERVER="y"
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

if [[ $HTML_DIR == "" ]] ; then
  echo "No HTML directory specified. Defaulting to 'html'."
  HTML_DIR="html"
fi

if [[ $RESOURCE_DIR == "" ]] ; then
  echo "No resource directory specified. Defaulting to 'resources/offline'."
  RESOURCE_DIR="resources/offline"
fi

echo 
echo WARNING:
printf "This will modify the contents of $HTML_DIR in place. Continue? y/N: "
read CONTINUE
if [[ $CONTINUE == "y" ]] ; then
  echo "Copying offline resources from $RESOURCE_DIR into $HTML_DIR"
  cp -r $RESOURCE_DIR/. $HTML_DIR

  cd $HTML_DIR

  echo "Processing files."
  echo "A LOT of files."
  echo "This is going to take ten minutes or so."

  find . -name '*.html' -exec sed -i '' -e 's/href="https:\/\/www\.elastic\.co\/guide/href="/g' -e  's/privacy-and-cookie-policy"/privacy-and-cookie-policy\.html"/g' -e 's/terms-of-use"/terms-of-use\.html"/g' -e 's/trademarks"/trademarks\.html"/g' -e 's/privacy-policy"/privacy-policy\.html"/g' -e 's/url="\/guide"/url="\/index.html"/g' -e 's/href="\/guide"/href="\/index.html"/g'  {} \;

  find . -name '*.js' -exec sed -i '' -e 's/href="https:\/\/www\.elastic\.co\/guide/href="/g' {} \;

  find . -name '*.css' -exec sed -i '' -e 's/href="https:\/\/www\.elastic\.co\/guide/href="/g' {} \;

  if [[ $CREATE_ZIP == "y" ]] ; then
      echo "Creating zip file elastic-docs.zip"
      zip -r elastic-docs.zip .
  fi

  if [[ $START_SERVER == "y" ]] ; then
    echo "Starting SimpleHTTPServer"
    python -m SimpleHTTPServer
  fi

else
  echo "Okay, exiting without doing anything."
  date
  exit 0
fi

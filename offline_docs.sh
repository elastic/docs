#!/bin/bash
# Modify generated docs in a particular directory to work offline.

date
DOCS_DIR=$(pwd)
HTML_DIR=$DOCS_DIR/html
MANIFEST_DIR="$DOCS_DIR/resources/offline/manifest"

USAGE="Usage: offline_docs.sh [-z <zip-file>] [-o] [-h]."

HELP="Processes the contents of docs/html to enable the Elastic docs to be
hosted and viewed without access to elastic.co. Use the -z option
to generate a zip archive of the processed files. Files are archived to elastic_docs_bundle.zip. Use the -o option to open
the modified docs in SimpleHTTPServer."

EXAMPLE="./offline_docs.sh  -z -o"

while getopts "zoh" opt; do
  case $opt in
    z)
      ZIP="y"
      ;;
    o)
      START_SERVER="y"
      ;;
    h)
      echo "$USAGE"
      echo "$HELP"
      echo "$EXAMPLE"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      echo "$USAGE"
      exit 1
      ;;
  esac
done

if [[ $ZIP == "" ]] ; then
  echo "Skipping zip file generation."
else
  ZIP_FILE="elastic_docs_bundle.zip"
fi

echo
echo WARNING:
printf "This will modify the contents of $HTML_DIR in place. Continue? y/N: "
read CONTINUE
if [[ $CONTINUE == "y" ]] ; then
  echo "Downloading resources."
  echo "Reading resource manifest from $MANIFEST_DIR."

  echo "Fetching assets"
  mkdir -p $HTML_DIR/assets
  cd $HTML_DIR/assets
  rm *.svg
  xargs -n 1 curl -O < $MANIFEST_DIR/assets.txt

  echo "Fetching legal"
  mkdir -p $HTML_DIR/legal
  cd $HTML_DIR/legal
  rm *.html
  xargs -n 1 curl -O < $MANIFEST_DIR/legal.txt
  for f in *; do mv $f `basename $f `.html; done;
  mv brand.html ../.

  echo "Fetching css"
  mkdir -p $HTML_DIR/static/css
  cd $HTML_DIR/static/css
  rm *.css
  xargs -n 1 curl -O < $MANIFEST_DIR/css.txt

  echo "Fetching images"
  mkdir -p $HTML_DIR/static/images
  cd $HTML_DIR/static/images
  rm *.png *.svg
  xargs -n 1 curl -O < $MANIFEST_DIR/images.txt
  mkdir -p $HTML_DIR/static/images/svg
  cd $HTML_DIR/static/images/svg
  rm *.svg
  xargs -n 1 curl -O < $MANIFEST_DIR/images-svg.txt

  echo "Fetching js"
  mkdir -p $HTML_DIR/static/js
  cd $HTML_DIR/static/js
  rm *.js
  xargs -n 1 curl -O < $MANIFEST_DIR/js.txt

  echo "Copying doc bundle readme to $HTML_DIR"
  cp $DOCS_DIR/resources/offline/README.txt $HTML_DIR/.

  echo "Processing files."
  echo "A LOT of files."
  echo "This is going to take ten minutes or so."

  cd $HTML_DIR

  find . -name '*.html' -exec sed -i '' -e 's/href="https:\/\/www\.elastic\.co\/guide/href="/g' -e  's/privacy-statement"/privacy-statement\.html"/g' -e 's/\/terms-of-use"/\/terms-of-use\.html"/g' -e 's/\/trademarks"/\/trademarks\.html"/g' -e 's/url="\/guide"/url="\/index.html"/g' -e 's/href="\/guide"/href="\/index.html"/g' -e 's/assets\/blt.*\//assets\//g' -e 's/\/brand"/\/brand\.html"/g' {} \+

  find . -name 'brand.html' -exec sed -i '' -e  's/<div id="footer-subscribe"/<!--<div id="footer-subscribe"/g' -e  's/<!--subscribe newsletter end-->/--> <!--subscribe newsletter end-->/g' {} \+

  find . -name '*.js' -exec sed -i '' -e 's/href="https:\/\/www\.elastic\.co\/guide/href="/g' {} \+

  find . -name '*.css' -exec sed -i '' -e 's/href="https:\/\/www\.elastic\.co\/guide/href="/g' {} \+

  if [[ $ZIP == "y" ]] ; then
    echo "Archiving processed files to $DOCS_DIR/$ZIP_FILE."
    zip -r $DOCS_DIR/$ZIP_FILE html
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

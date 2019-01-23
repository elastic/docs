#!/bin/bash

# Build the docs with docker!
#
# Step 1 is to build a docker image based on the asciidoctor image.
# Step 2 is to translate the arguments that build_docs.pl supports into
# a list of arguments to be passed to start the docker container and a
# list of arguments to be passed to the build_docs.pl process that is
# started in the docker container.
# Step 3 is to start the docker container. We start it in such a way
# that is *should* remove itself when it is done.

function desymlink() {
  FILE="$1"
  while [ -h "$FILE" ] ; do
    ls=$(ls -ld "$FILE")
    # Drop everything prior to ->
    link=$(expr "$ls" : '.*-> \(.*\)$')
    if expr "$link" : '/.*' > /dev/null; then
      FILE="$link"
    else
      FILE=$(dirname "$FILE")/"$link"
    fi
  done
  echo $FILE
}

function to_absolute_path() {
  FILE=$(desymlink "$1")
  cd "$(dirname "$FILE")"
  echo "$(pwd -P)/$(basename "$FILE")"
}

# Find the root of a git repo for a given directory if
# possible, otherwise returning the directory itself.
function find_git_repo_root() {
  cd $1
  while [ ! -d ".git" ]; do
    if [ "$PWD" = "/" ]; then
      # Not in a git repo
      echo "$1"
      return
    fi
    cd ..
  done
  echo "$PWD"
}

DIR="$(dirname "$(to_absolute_path "$0")")"

DOCKER_RUN_ARGS=()
DOCKER_RUN_ARGS+=('-it')   # NOCOMMIT does this make sense when running in CI?
DOCKER_RUN_ARGS+=('--rm')
DOCKER_RUN_ARGS+=('-v')
DOCKER_RUN_ARGS+=("$DIR:/docs_build:cached")

# rewrite the arguments to be friendly to the docker image
NEW_ARGS=()
RESOURCE_COUNT=0
while [ $# -gt 0 ]; do
  NEW_ARGS+=("$1")
  case "$1" in
  --doc)
    shift
    if [ ! -f "$1" ]; then
      echo "Can't find $1"
      exit 1
    fi
    DOC_FILE="$(to_absolute_path $1)"
    GIT_REPO_ROOT="$(find_git_repo_root "$(dirname "$DOC_FILE")")"
    DOCKER_RUN_ARGS+=('-v')
    DOCKER_RUN_ARGS+=("$GIT_REPO_ROOT:/doc:cached")
    NEW_ARGS+=("/doc${DOC_FILE/$GIT_REPO_ROOT/}")
    ;;
  --out)
    shift
    if [ ! -d "$1" ]; then
      mkdir -p "$1"
      exit 1
    fi
    DOCKER_RUN_ARGS+=('-v')
    DOCKER_RUN_ARGS+=("$(dirname "$(to_absolute_path $1)"):/out:delegated")
    NEW_ARGS+=("/out/$(basename "$1")")
    ;;
  --resource)
    shift
    if [ ! -d "$1" ]; then
      echo "Can't find $1"
      exit 1
    fi
    DOCKER_RUN_ARGS+=('-v')
    DOCKER_RUN_ARGS+=("$(to_absolute_path $1):/resource_$RESOURCE_COUNT:cached")
    NEW_ARGS+=("/resource_$RESOURCE_COUNT")
    RESOURCE_COUNT+=1
    ;;
  --open)
    DOCKER_RUN_ARGS+=('--publish')
    DOCKER_RUN_ARGS+=('8000:8000/tcp')
    ;;
  *)
    ;;
  esac
  shift
done

docker image build -t elastic/docs_build - < "$DIR/Dockerfile"
docker run "${DOCKER_RUN_ARGS[@]}" elastic/docs_build /docs_build/build_docs.pl "${NEW_ARGS[@]}"

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

set -e

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
DOCKER_RUN_ARGS+=('-it')
DOCKER_RUN_ARGS+=('--rm')
DOCKER_RUN_ARGS+=('--user' "$(id -u):$(id -g)")
DOCKER_RUN_ARGS+=('-v' "$DIR:/docs_build:cached")

# Running read-only with a proper tmp directory gives us a little
# performance boost and it is simple enough to do.
DOCKER_RUN_ARGS+=('--read-only')
DOCKER_RUN_ARGS+=('--tmpfs' '/tmp')

# rewrite the arguments to be friendly to the docker image
NEW_ARGS=()
RESOURCE_COUNT=0
while [ $# -gt 0 ]; do
  NEW_ARGS+=("$1")
  case "$1" in
  --all)
    DOCKER_RUN_ARGS+=('-v' "$HOME/.ssh/known_hosts:/root/.ssh/known_hosts:ro")
    # DOCKER_RUN_ARGS+=('--mount')
    # DOCKER_RUN_ARGS+=("type=ssh")
    ;;
  --doc)
    shift
    if [ ! -f "$1" ]; then
      echo "Can't find $1"
      exit 1
    fi
    DOC_FILE="$(to_absolute_path $1)"
    GIT_REPO_ROOT="$(find_git_repo_root "$(dirname "$DOC_FILE")")"
    DOCKER_RUN_ARGS+=('-v' "$GIT_REPO_ROOT:/doc:cached")
    NEW_ARGS+=("/doc${DOC_FILE/$GIT_REPO_ROOT/}")
    ;;
  --open)
    DOCKER_RUN_ARGS+=('--publish' '8000:8000/tcp')
    ;;
  --out)
    shift
    if [ ! -d "$1" ]; then
      mkdir -p "$1"
      exit 1
    fi
    DOCKER_RUN_ARGS+=('-v' "$(dirname "$(to_absolute_path $1)"):/out:delegated")
    NEW_ARGS+=("/out/$(basename "$1")")
    ;;
  --resource)
    shift
    if [ ! -d "$1" ]; then
      echo "Can't find $1"
      exit 1
    fi
    DOCKER_RUN_ARGS+=('-v' "$(to_absolute_path $1):/resource_$RESOURCE_COUNT:cached")
    NEW_ARGS+=("/resource_$RESOURCE_COUNT")
    RESOURCE_COUNT+=1
    ;;
  *)
    ;;
  esac
  shift
done


# Build the docker image from stdin so we don't try to pack up everything in
# this directory. It is huge and we don't need any of it in the image because
# we'll mount it into the image on startup.
docker image build -t elastic/docs_build - < "$DIR/DebDockerfile"
# Run docker with the arguments we made above.
docker run "${DOCKER_RUN_ARGS[@]}" --security-opt seccomp=unconfined elastic/docs_build /docs_build/build_docs.pl ${NEW_ARGS[@]}

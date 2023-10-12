#!/bin/bash

# retry function
# -------------------------------------
# Retry a command for a specified number of times until the command exits successfully.
# Retry wait period backs off exponentially after each retry.
#
# The first argument should be the number of retries.
# Remainder is treated as the command to execute.
# -------------------------------------
retry() {
  local retries=$1
  shift

  local count=0
  until "$@"; do
    exit=$?
    wait=$((2 ** $count))
    count=$(($count + 1))
    if [ $count -lt $retries ]; then
      printf "Retry %s/%s exited %s, retrying in %s seconds...\n" "$count" "$retries" "$exit" "$wait" >&2
      sleep $wait
    else
      printf "Retry %s/%s exited %s, no more retries left.\n" "$count" "$retries" "$exit" >&2
      return $exit
    fi
  done
  return 0
}

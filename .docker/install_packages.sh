#!/bin/sh

MAX_ATTEMPTS=5
WAIT_TIME=10
RETRY_COUNT=0

# Check if any package names were provided
if [ $# -eq 0 ]; then
    echo "Error: install_packages requires at least one package name." >&2
    exit 1
fi

# Loop for retry attempts
while [ $RETRY_COUNT -lt $MAX_ATTEMPTS ]; do
    echo "Attempt $((RETRY_COUNT + 1)) of $MAX_ATTEMPTS: Running install_packages $@"

    # Execute the actual install command
    install_packages "$@"

    # Check the exit status of the previous command
    if [ $? -eq 0 ]; then
        echo "Packages installed successfully."
        exit 0 # Success, exit the function
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_ATTEMPTS ]; then
            echo "Installation failed. Retrying in $WAIT_TIME seconds..."
            sleep $WAIT_TIME
        fi
    fi
done

echo "ERROR: Package installation failed after $MAX_ATTEMPTS attempts." >&2
exit 1

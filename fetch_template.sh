#!/bin/bash

# Fetch the production templates for the guide.
# Run this from the root of the docs repo.
# After running this you have to force a `--all --rebuild` to pick up the
# new template.

curl https://www.elastic.co/guide_template > resources/web/template.html

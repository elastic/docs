#!/bin/bash

# Fetch the production templates for the guide.
# Run this from the root of the docs repo.

curl https://www.elastic.co/guide_template > resources/web/template.html

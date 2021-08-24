# What is this?

This directory contains static files copied from the built-docs repo, so that
locally-built files in the `m1-workaround` branch can be displayed like they
they will on the real site, without using the preview server.

## How to keep these up to date

Whenever there are changes to the styles on the docs site, run the following
commands from the root of the `docs` repo and commit any changes to this branch.

```shell
cd $GIT_HOME/built-docs
git checkout master
git pull
cd $GIT_HOME/docs
git checkout m1-workaround
git pull
cp $GIT_HOME/built-docs/html/static/* workaround-static
git add workaround-static
git commit -m "update static files"
git push
```

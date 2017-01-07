#!/bin/bash -e

git stash
git checkout develop
stack exec badly-drawn-wizards clean
stack exec badly-drawn-wizards build
git fetch origin master
git checkout -b master --track origin/master
rsync -a \
      --filter='P _site/'      \
      --filter='P _cache/'     \
      --filter='P .git/'       \
      --filter='P .gitignore'  \
      --filter='P .stack-work' \
      --delete-excluded        \
      _site/ .
git add -A
git commit -e -m "Publish $(date +%Y-%m-%d)"
git push origin master:master
git checkout develop
git branch -D master
git stash pop

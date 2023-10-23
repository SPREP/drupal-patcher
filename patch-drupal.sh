#!/bin/bash

usage() {
  echo "Usage: $0 -r|--repo REPO-DIRECTORY [-b|--branch MAIN-BRANCH -d|--dir DRUPAL-DIRECTORY -c|--composer COMPOSER-PACKAGES]"
  exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -r|--repo)
    repo="$2"
    shift; shift
    ;;
    -b|--branch)
    branch="$2"
    shift; shift
    ;;
    -d|--dir)
    directory="$2"
    shift; shift
    ;;
    -c|--composer)
    composer="$2"
    shift; shift
    ;;
    *)
    usage
    ;;
  esac
  done

# Validate required arguments
[ -z "$repo" ] && usage

# Initialize variables
repo_dir="$repo"
repo_main_branch="${branch:-latest}"
drupal_dir="${directory:-drupal}"
composer_packages="${composer:-'drupal/core*'}"

current_month=$(date +'%^b')
current_year=$(date +'%y')

repo_feature_branch="security/patch-$current_month$current_year"
commit_message="security patch $current_month $current_year"

cd $repo_dir

# Git operations
git checkout "$repo_main_branch"

if [[ $(git status -s) ]]; then
  git stash save "$repo_feature_branch"
fi

git pull origin "$repo_main_branch"

if git show-ref --verify --quiet "refs/heads/$repo_feature_branch"; then
  git checkout "$repo_feature_branch"
else
  git checkout -b "$repo_feature_branch"
fi

# Docker Compose & Composer commands
# echo "Stopping docker compose"
docker compose stop
# echo "Starting php container"
docker compose up -d php
# echo "Patching drupal"
docker compose exec -T --user wodby php /bin/sh -c "cd /var/www/html/$drupal_dir && composer update $composer_packages -W"
# echo "Stopping php container"
docker compose stop

# Git commit & push
if [[ $(git status | grep 'composer.lock') ]]; then
  git add $drupal_dir/composer.lock
  git commit -m "$commit_message"
fi

push_output=$(git push origin "$repo_feature_branch" 2>&1)
mr_url=$(echo "$push_output" | grep -o 'http[s]://[^ ]*')

# Display and open MR URL
if [[ $mr_url ]]; then
  echo "Merge Request URL: $mr_url"
fi

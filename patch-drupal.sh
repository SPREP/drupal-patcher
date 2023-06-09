#!/bin/bash

usage() {
  echo "Usage: $0 -r|--repo REPO-DIRECTORY [-b|--branch MAIN-BRANCH -d|--dir DRUPAL-DIRECTORY -d|--composer COMPOSER-PACKAGES]"
  exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -r|--repo)
      repo="$2"
      shift
      shift
      ;;
    -b|--branch)
      branch="$2"
      shift
      shift
      ;;
    -d|--dir)
      directory="$2"
      shift
      shift
      ;;
    -c|--composer)
      composer="$2"
      shift
      shift
      ;;
    *) # Unknown option
      usage
      ;;
  esac
done

# Check if required arguments are present
if [ -z "$repo" ] ; then
  usage
fi

repo_dir=$repo
repo_main_branch=${branch:-latest}
drupal_dir=${directory:-drupal}
composer_packages=${composer:-"drupal/core*"}

current_month=$(date +%^b)
current_year=$(date +'%y')

repo_feature_branch="security-patch-$current_month$current_year"
commit_message="security patch $current_month $current_year"

cd $repo_dir
git stash clear
git stash
git checkout .
git checkout $repo_main_branch
git pull origin $repo_main_branch
if [ `git rev-parse --verify $repo_feature_branch 2>/dev/null` ]
  git checkout $repo_feature_branch
then
  git checkout -b $repo_feature_branch
fi
docker compose stop
docker compose up -d php
docker compose exec -T --user wodby php /bin/sh -c "cd /var/www/html/$drupal_dir/ && composer update $composer_packages -W"
docker compose stop
git add $drupal_dir
git commit -m "$commit_message"
echo "Done!"

git push origin $repo_feature_branch
echo "Pushed branch '$repo_feature_branch'" to repo

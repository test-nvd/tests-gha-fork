#!/usr/bin/env bash

# Version 0.0.1

# This script releases an updated modules.

set -euo pipefail
IFS=$'\n\t'

###
## Variables
###

BASE_DIR="$(pwd)"
SCRIPT_UPDATE_CHANGELOG="${BASE_DIR}/extra/scripts/update-changelogs"
ZENTYAL_BASE='jammy'
ZENTYAL_URGENCY='medium'
GIT_USERNAME="github-actions"
GIT_EMAIL="github-actions@github.com"

###
## Functions
###

function usage() {
    echo "Usage: $0 <argument>"
    echo
    echo "Argument: A list of modules to release."
    exit 1
}


function prepare_git() {
    git config user.name "${GIT_USERNAME}"
    git config user.email "${GIT_EMAIL}"
}


function generate_changelog() {
    local module="$1"

    echo "Generating changelog for module: ${module}"

    if [[ ! -d "${module}" ]]; then
        echo "Error: Module directory '${module}' does not exist."
        exit 1
    fi

    cd "${module}"
    ${SCRIPT_UPDATE_CHANGELOG} "${ZENTYAL_BASE}" "${ZENTYAL_URGENCY}" "${GIT_USERNAME}" "${GIT_EMAIL}"

    if ! git status -s | egrep -o '^ M debian/changelog$'; then
        echo "No changes detected in debian/changelog for module: ${module}. Skipping release."
        return 0
    fi
}


function commit_and_tag() {

    echo "Getting ready to commit and tag changes"

    CHANGELOG_HEADER=$(head -n 1 debian/changelog)
    MODULE_VERSION=$(echo "${CHANGELOG_HEADER}" | awk -F'[()]' '{print $2}')
    MODULE_NAME=$(echo "${CHANGELOG_HEADER}" | awk '{print $1}')
    TAG_NAME="v${MODULE_VERSION}-${MODULE_NAME}"

    echo "Committing changelog and creating tag: ${TAG_NAME}"
    git add debian/changelog
    git commit -m "chore(release): update changelog for ${MODULE_NAME} by GH Actions"
    git tag "${TAG_NAME}"
    git push --tags
}


function create_release() {
    echo "Creating GitHub release for module: ${MODULE_NAME} with tag: ${TAG_NAME}"

    # https://cli.github.com/manual/gh_release_create
    gh release create "${TAG_NAME}" --title "Release ${MODULE_NAME} ${TAG_NAME}" --generate-notes
}

###
## Main script
###

if [[ $# -lt 1 ]]; then
    usage
fi

MODULES_TO_RELEASE=${1}

if [[ -z "${MODULES_TO_RELEASE}" ]]; then
    echo "Error: MODULES_TO_RELEASE variable is empty or not set."
    exit 1
fi

prepare_git

while IFS= read -r module; do
    echo "Releasing module: ${module}"
    cd ${BASE_DIR}
    generate_changelog "${module}"
    commit_and_tag
    create_release
done < <(echo "$MODULES_TO_RELEASE" | tr ' ' '\n')

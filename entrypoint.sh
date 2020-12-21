#!/bin/bash
set -e
set -o pipefail

if [[ -n "$TOKEN" ]]; then
    GITHUB_TOKEN=$TOKEN
fi

if [[ -z "$PAGES_BRANCH" ]]; then
    PAGES_BRANCH="gh-pages"
fi

if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="."
fi

if [[ -n "$REPOSITORY" ]]; then
    TARGET_REPOSITORY=$REPOSITORY
else
    if [[ -z "$GITHUB_REPOSITORY" ]]; then
        echo "Set the GITHUB_REPOSITORY env variable."
        exit 1
    fi
    TARGET_REPOSITORY=${GITHUB_REPOSITORY}
fi

if [[ -z "$BUILD_ONLY" ]]; then
    BUILD_ONLY=false
fi

if [[ -z "$BUILD_THEMES" ]]; then
    BUILD_THEMES=true
fi

if [[ -z "$PRESERVE_HISTORY" ]]; then
    PRESERVE_HISTORY=false
fi

if [[ -z "$GITHUB_TOKEN" ]] && [[ "$BUILD_ONLY" == false ]]; then
    echo "Set the GITHUB_TOKEN env variable."
    exit 1
fi

main() {
    echo "Starting deploy..."

    git config --global url."https://".insteadOf git://
    git config --global url."https://github.com/".insteadOf git@github.com:
    if [[ "$BUILD_THEMES" ]]; then
        echo "Fetching themes"
        git submodule update --init --recursive
    fi

    version=$(zola --version)
    remote_repo="https://yehia2amer:${GITHUB_TOKEN}@github.com/${TARGET_REPOSITORY}.git"
    remote_branch="$PAGES_BRANCH"

    echo "Using $version"

    echo "Building in $BUILD_DIR directory"
    cd "$BUILD_DIR"

    echo Building with flags: ${BUILD_FLAGS:+"$BUILD_FLAGS"}
    zola build ${BUILD_FLAGS:+$BUILD_FLAGS}

    if ${BUILD_ONLY}; then
        echo "Build complete. Deployment skipped by request"
        exit 0
    else
        echo "Pushing artifacts to ${TARGET_REPOSITORY}:$remote_branch"

        cd public
        if [[ "$PRESERVE_HISTORY" ]]; then
            git clone -b "${remote_branch}" --depth 1 --no-checkout --separate-git-dir .git "${remote_repo}" "$(mktemp -d)"
        else
            git init
            git checkout -b "${remote_branch}"
        fi
        git config user.name "GitHub Actions"
        git config user.email "github-actions-bot@users.noreply.github.com"
        git add .

        # Only try to commit if there are changes (useful when PRESERVE_HISTORY is true).
        git diff-index --cached --quiet HEAD || \
            git commit -m "Deploy ${TARGET_REPOSITORY} to ${TARGET_REPOSITORY}:$remote_branch"
        if [[ "$PRESERVE_HISTORY" ]]; then
            git push "${remote_repo}"
        else
            git push --force "${remote_repo}" "master:${remote_branch}"
        fi

        echo "Deploy complete"
    fi
}

main "$@"

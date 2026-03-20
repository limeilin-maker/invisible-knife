#!/usr/bin/env bash
set -euo pipefail

# Stages all changes, creates a commit with your message, and pushes to GitHub (or any remote).
# Usage:
#   ./git-push.sh "commit message"
#   ./git-push.sh
# Environment:
#   REMOTE (default: origin)
#
# Notes:
# - If there is nothing to commit, the script exits successfully without creating a commit.
# - By default it pushes the current branch.

REMOTE="${REMOTE:-origin}"

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed or not on PATH." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: this is not a git repository (or git not configured correctly)." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" == "HEAD" ]]; then
  echo "Error: you appear to be in detached HEAD state. Checkout a branch first." >&2
  exit 1
fi

if [[ $# -ge 1 ]]; then
  commit_message="$*"
else
  echo -n "Commit message: "
  read -r commit_message
fi

if [[ -z "${commit_message}" ]]; then
  echo "Error: commit message cannot be empty." >&2
  exit 1
fi

# Stage everything (including deletions).
git add -A

# If nothing is staged, bail out.
if git diff --cached --quiet; then
  echo "Nothing to commit on branch '${current_branch}'." >&2
  exit 0
fi

git commit -m "$commit_message"

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  echo "Error: remote '${REMOTE}' not found. Configure it with: git remote add ${REMOTE} <url>" >&2
  exit 1
fi

echo "Pushing '${current_branch}' to '${REMOTE}'..."
git push -u "$REMOTE" "$current_branch"

echo "Done."


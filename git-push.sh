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
push_output="$(git push -u "$REMOTE" "$current_branch" 2>&1)" || push_status=$?
if [[ "${push_status:-0}" -eq 0 ]]; then
  echo "$push_output"
  echo "Done."
  exit 0
fi

echo "$push_output"

# If the remote has new commits, GitHub rejects the push. Fix by rebasing and retrying.
if [[ "$push_output" == *"non-fast-forward"* || "$push_output" == *"rejected"* ]]; then
  echo "Remote branch has new commits. Rebase local branch and retry..."
  if ! git pull --rebase "$REMOTE" "$current_branch"; then
    echo "Rebase failed (likely merge conflict). Resolve conflicts, then re-run this script." >&2
    exit 1
  fi
  echo "Retrying push..."
  retry_output="$(git push -u "$REMOTE" "$current_branch" 2>&1)" || retry_status=$?
  if [[ "${retry_status:-0}" -ne 0 ]]; then
    echo "$retry_output"
    echo "Retry push failed. Resolve the issue and re-run this script." >&2
    exit "${retry_status:-1}"
  fi
  echo "$retry_output"
  echo "Done."
  exit 0
fi

echo "Push failed. Fix the issue above and re-run this script." >&2
exit "${push_status:-1}"



#!/usr/bin/env bash
# Automated local branch cleanup utility.
# Safe rules (default):
#  - Keep: main, protected prefixes (wip/, experimental/, archive/)
#  - Delete if merged into base OR upstream is gone
#  - If upstream gone but not merged: tag archive/<branch> then delete (unless --no-archive)
#
# Overrides:
#  --force           : Ignore merge / gone checks (still protects main unless --include-protected)
#  --base <branch>   : Specify base branch (default: main)
#  --no-archive      : Do not create archive/ tags
#  --include-protected : Allow deletion of protected prefixes (use with caution)
#  --dry-run         : Show actions only
#  --help            : Show usage
#
# Exit codes: 0 success, 1 unsafe working tree, 2 invalid options

set -euo pipefail

BASE=main
FORCE=false
NO_ARCHIVE=false
INCLUDE_PROTECTED=false
DRY_RUN=false
PROTECT_RE='^(main|wip/|experimental/|archive/)' 

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true ; shift ;;
    --base) BASE="$2"; shift 2 ;;
    --no-archive) NO_ARCHIVE=true; shift ;;
    --include-protected) INCLUDE_PROTECTED=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# Preconditions
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository" >&2; exit 1
fi

current=$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)
if [[ "$current" != "$BASE" ]]; then
  echo "Switch to $BASE before cleanup (current=$current)" >&2; exit 1
fi

if [[ -n $(git status --porcelain) ]]; then
  echo "Working tree not clean; commit or stash first" >&2; exit 1
fi

git fetch --prune >/dev/null 2>&1 || true

deleted=0; skipped=0; tagged=0

branches=$(git branch --format='%(refname:short)')
for b in $branches; do
  [[ "$b" == "$BASE" ]] && continue

  if ! $INCLUDE_PROTECTED && [[ $b =~ $PROTECT_RE ]]; then
    ((skipped++)); continue
  fi

  info=$(git branch -vv | grep "^..$b ") || true
  upstream_gone=false
  if echo "$info" | grep -q '\[gone\]'; then upstream_gone=true; fi

  merged=false
  if git merge-base --is-ancestor "$b" "$BASE" 2>/dev/null; then merged=true; fi

  action="skip"
  tag_head=""

  if $FORCE; then
    action="delete"
  else
    if $merged || $upstream_gone; then
      action="delete"
      if $upstream_gone && ! $merged && ! $NO_ARCHIVE; then
        tag_head=$(git rev-parse "$b")
      fi
    fi
  fi

  if [[ "$action" == "delete" ]]; then
    if [[ -n "$tag_head" ]]; then
      if $DRY_RUN; then
        echo "[dry-run] tag archive/$b -> $tag_head"; 
      else
        git tag -f "archive/$b" "$tag_head" && ((tagged++))
        echo "Tagged archive/$b -> $tag_head"
      fi
    fi
    if $DRY_RUN; then
      echo "[dry-run] delete $b"
    else
      git branch -D "$b" >/dev/null && ((deleted++)) && echo "Deleted $b"
    fi
  else
    ((skipped++))
  fi

done

echo "Summary: deleted=$deleted tagged=$tagged skipped=$skipped base=$BASE force=$FORCE" >&2
if $DRY_RUN; then echo "(Dry run only - no changes)" >&2; fi

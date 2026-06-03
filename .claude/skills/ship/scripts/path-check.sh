#!/usr/bin/env bash
# path-check.sh — Detect cloud-synced filesystem paths that corrupt .git metadata.
# Usage: path-check.sh [path]   (defaults to $(pwd))
# Exit 0: safe path. Exit 1: synced path detected, suggested redirect on stdout.
#
# Why: iCloud/OneDrive/Dropbox sync .git/index.lock mid-write, causing 10-15 min
# zombie checkouts + duplicate-filename artifacts. Canonical source:
# .claude/rules/worktree-discipline.md.

set -euo pipefail

target="${1:-$(pwd)}"

# Normalize: expand ~, resolve symlinks where possible.
# `pwd -P` resolves to the REAL path, so if ~/code/X is a symlink INTO iCloud,
# the iCloud pattern below catches it correctly. But detect the wolf-in-sheep's-
# clothing case (~/code/ itself being a symlink) explicitly — see failure-inventory A5.
abs="$(cd "$target" 2>/dev/null && pwd -P 2>/dev/null || echo "$target")"

# A5: ~/code/ itself a symlink into a synced dir
if [ -L "$HOME/code" ]; then
  code_real="$(readlink "$HOME/code" 2>/dev/null || true)"
  case "$code_real" in
    */Documents/GitHub/*|*/Documents/*|*/OneDrive*|*/Dropbox*|*/iCloud*)
      echo "UNSAFE: ~/code is itself a symlink to $code_real (cloud-synced)"
      echo "REDIRECT: remove the symlink and use a real directory: rm ~/code && mkdir ~/code"
      exit 1
      ;;
  esac
fi

case "$abs" in
  */Documents/GitHub/*|"$HOME/Documents/GitHub/"*)
    slug="$(basename "$abs" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-\|-$//g')"
    echo "UNSAFE: $abs is inside iCloud-synced Documents/GitHub/"
    echo "REDIRECT: git worktree add ~/code/<repo>-$slug <branch>"
    exit 1
    ;;
  */OneDrive*|*/Dropbox*|*/iCloud*)
    echo "UNSAFE: $abs is inside a cloud-synced directory (OneDrive/Dropbox/iCloud)"
    echo "REDIRECT: git worktree add ~/code/$(basename "$abs") <branch>"
    exit 1
    ;;
  /tmp/*|/private/tmp/*)
    echo "UNSAFE: $abs is in /tmp (macOS tmpfs triggers git auto-lock hangs)"
    echo "REDIRECT: git worktree add ~/code/$(basename "$abs") <branch>"
    exit 1
    ;;
  "$HOME/code/"*|/Users/*/code/*)
    exit 0
    ;;
  *)
    # Unknown-but-not-explicitly-unsafe. Proceed with warning on stderr.
    echo "WARN: $abs is not under ~/code/ — verify filesystem is not cloud-synced" >&2
    exit 0
    ;;
esac

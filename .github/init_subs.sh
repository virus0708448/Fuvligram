#!/usr/bin/env bash
set -e
if [ -f .gitmodules ]; then
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | while read -r k p; do
    n=${k#submodule.}; n=${n%.path}
    u=$(git config -f .gitmodules --get "submodule.$n.url" || true)
    if [ -n "$u" ] && [ ! -d "$p/.git" ]; then
      rm -rf "$p"; git clone --depth 1 --recursive "$u" "$p"
    fi
  done
fi

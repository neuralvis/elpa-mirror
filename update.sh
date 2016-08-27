#!/usr/bin/env bash

ELPA_CLONE_URL="git@github.com:dochang/elpa-clone.git"
ELPA_CLONE_PATH="$HOME/elpa-clone"
OUTPUT_PATH=$(pwd)

set -e

function log {
  echo "[$(date '+%d/%m/%y %H:%M:%S')]" "$@" >> "$OUTPUT_PATH/output.log"
}

log "Start updating elpa mirrors"

if [[ ! -d $ELPA_CLONE_PATH ]]; then
  git clone "$ELPA_CLONE_URL" "$ELPA_CLONE_PATH"
fi

function clone {
  log "Updating mirror for $2 ($1)"
  emacs -l "$ELPA_CLONE_PATH/elpa-clone.el" -nw --batch --eval="(elpa-clone \"$1\" \"$OUTPUT_PATH/$2\")" 2>> "$OUTPUT_PATH/output.log"
}

clone "http://orgmode.org/elpa/" "org"
clone "https://elpa.gnu.org/packages/" "gnu"
clone "https://melpa.org/packages/" "melpa"
clone "https://stable.melpa.org/packages/" "stable-melpa"

git add --all
git commit -m "snapshot $(date '+%d/%m/%y %H:%M:%S')"
git push origin master

log "Done updating elpa mirrors"

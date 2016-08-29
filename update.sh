#!/usr/bin/env bash

if [ -z "${1+x}" ]; then
  MIRROR_PATH=$(pwd)
else
  MIRROR_PATH=$1
fi

if [ -z "${2+x}" ]; then
  LOGFILE=$MIRROR_PATH/output.log
else
  LOGFILE=$2
fi

if [ -z "${3+x}" ]; then
  ELPA_CLONE_PATH="$HOME/elpa-clone"
else
  ELPA_CLONE_PATH=$3
fi

ELPA_CLONE_URL="git@github.com:dochang/elpa-clone.git"

set -e

function log {
  echo "[$(date '+%d/%m/%y %H:%M:%S')]" "$@"
}

function clone {
  log "Updating mirror for $2 ($1)"
  emacs -l "$ELPA_CLONE_PATH/elpa-clone.el" -nw --batch --eval="(elpa-clone \"$1\" \"$MIRROR_PATH/$2\")"
}

function update {
  log "Start updating elpa mirrors"
  log "Output to: $MIRROR_PATH"
  log "elpa-clone in: $ELPA_CLONE_PATH"

  cd "$MIRROR_PATH"

  if [[ ! -d $ELPA_CLONE_PATH ]]; then
    git clone "$ELPA_CLONE_URL" "$ELPA_CLONE_PATH"
  fi

  git fetch origin
  git rebase origin/master

  clone "http://orgmode.org/elpa/" "org"
  clone "https://elpa.gnu.org/packages/" "gnu"
  clone "https://melpa.org/packages/" "melpa"
  clone "https://stable.melpa.org/packages/" "stable-melpa"

  git add --all
  git commit -m "snapshot $(date '+%d/%m/%y %H:%M:%S')"
  git push origin master

  log "Done updating elpa mirrors"
}

update >> "$LOGFILE"

This package contains

* defuns for downloading and uploading a change (`gerrit-upload`, `gerrit-download`)
  The command line tool git-review is used for this under the hood.
* open-reviews section in magit
    The (open) gerrit changes for the current project are queried using the rest API.

    section local keymap:
       RET - opens change in browser
* defun for setting assignee of a gerrit change using rest api `gerrit-rest--set-assignee`

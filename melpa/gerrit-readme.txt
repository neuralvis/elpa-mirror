This package contains

* defuns for downloading and uploading a change (`gerrit-upload`, `gerrit-download`)
  The command line tool git-review is used for this under the hood.
* open-reviews section in magit
    The (open) gerrit changes for the current project are queried using the rest API.

    section local keymap:
       RET - opens change in browser
* defun for setting assignee of a gerrit change using rest api `gerrit-rest--set-assignee`

TODOS:
when uploading a new patchset for a change (via `gerrit-upload`) show votes
include votes in  open gerrit review lines
parse commit messages and show jira tickets (ret on jira tickets opens them)
 where should the jira tickets be displayed?
write some testcases
rename gerrit-upload to gerrit-change-upload and gerrit-download to gerrit-change-download.

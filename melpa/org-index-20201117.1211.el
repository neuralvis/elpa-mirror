;;; org-index.el --- A personal adaptive index for org  -*- lexical-binding: t; -*-

;; Copyright (C) 2011-2020 Free Software Foundation, Inc.

;; Author: Marc Ihm <1@2484.de>
;; URL: https://github.com/marcIhm/org-index
;; Package-Version: 20201117.1211
;; Package-Commit: 0863397ba2782e229fa6216beb074dd44eb0c031
;; Version: 7.0.1
;; Package-Requires: ((org "9.3") (dash "2.12") (s "1.12") (emacs "26.3"))

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by

;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;;

;;; Commentary:

;; Purpose:
;;
;;  Fast search for selected org-nodes and things outside.
;;
;;  `org-index' (package and interactive function) helps to create and
;;  update an index-table with keywords; each line either points to a
;;  heading in org, references a folder outside of org or carries an url or
;;  a snippet of text.  When searching the index, the set of matching lines
;;  is updated with every keystroke; results are sorted by usage count and
;;  date, so that frequently or recently used entries appear first in the
;;  list of results.
;;
;;  Please note, that org-index uses org-id throughout and therefore adds
;;  an id-property to all nodes in the index.
;;
;;  In the addition to the index table, org-index introduces the concept of
;;  references: These are decorated numbers (e.g. 'R237' or '--455--');
;;  they are well suited to be used outside of org, e.g. in folder names,
;;  ticket systems or on printed documents.
;;
;;  On first invocation org-index will assist you in creating the index
;;  table.
;;
;;  To start using your index, invoke the subcommand 'add' to create
;;  index entries and 'occur' to find them.
;;
;;  The set of columns within the index-table is fixed (see variable
;;  `oidx--all-columns') but can be arranged in any order you wish; just
;;  edit the index table.  The number of columns shown during occur is
;;  determined by `org-index-occur-columns'.  Using both features allows to
;;  make columns invisible, that you dont care about.
;;
;;
;; Setup:
;;
;;  - org-index can be installed with package.el
;;  - Invoke `org-index'; on first run it will assist in creating your
;;    index table.
;;
;;  - Optionally invoke `M-x org-customize', group 'Org Index', to tune
;;    its settings.
;;
;;
;; Further Information:
;;
;;  - Watch the screencast at http://2484.de/org-index.html.
;;  - See the documentation of `org-index', which can also be read by
;;    invoking `org-index' and typing '?'.
;;

;;; Change Log:

;;   Version 7.0
;;
;;   - A release of much rewriting and removal
;;   - Rewrote the occur command to reduce complexity
;;   - Only one sorting strategy is supported now, removed `org-index-sort-by'
;;   - Removed background sorting
;;   - Disallowed custom columns (starting wit a dot '.')
;;   - Sorting now only relates to index table (not arbitrary regions)
;;   - Removed commands ping, column, find-ref and highlight
;;   - Simplified command node: It now only works from within index
;;   - Command details now works from within index too
;;   - Document columns of index table and their purpose
;;   - Remove ability to search for refererence under cursor
;;   - Prefix arguments no longer allowed
;;   - Removed interface for lisp functions, e.g. org-index-new-line;
;      org-index is now purely interactive
;;
;;   Version 6.3
;;
;;   - Added new command 'd' to show details in occur-buffer (much like edit)
;;   - Fixes to occur
;;   - Code simplifications
;;   - Removed org-index-get-line
;;
;;   Version 6.2
;;
;;   - Require dash and orgmode for package.el
;;   - Key 'h' does the same as '?'
;;   - Rename command 'head' to 'node' (to free key 'h')
;;   - Removed command 'news'
;;   - Fixes
;;
;;   Version 6.1
;;
;;   - Added new command 'l' in occur to visit links
;;   - Modified keys in occur-buffer
;;   - Refactoring
;;   - Fixes
;;
;;   Version 6.0
;;
;;   - Moved the working-set feature into its own package org-working-set
;;
;;   Version 5.12
;;
;;   - Do-not-clock is shown in working-set menu
;;   - Switching from working set circle into menu
;;   - RET in working-set circle ends and clocks in immediately
;;   - Fixes
;;
;;   Version 5.11
;;
;;   - Implemented do-not-clock commands and behaviour in working-set
;;   - Fixes
;;
;;   Version 5.10
;;
;;   - Pressing shift prevents clocking into working set
;;   - Occur shows '(more lines omitted)' if appropriate
;;   - replaced (org-at-table-p) with (org-match-line org-table-line-regexp)
;;     throughout for preformance reasons
;;   - Offer direct clock-in from result-buffer of occur
;;   - Various fixes
;;
;;   Version 5.9
;; 
;;   - Renamed 'focus' to 'working-set', changed commands and help texts accordingly.
;;   - Added special buffer to manage the working-set
;;   - Function org-index-working-set may now be invoked directly
;;   - Simplified working-set circle
;;   - Introduced org-index-occur-columns to limit matches during occur to specified
;;     number of leading columns; this gives better matches
;;   - Removed days option from occur command
;;   - Fixed and Optimized overlay-handling in occur for better performance and
;;     overall stability
;;   - Limited the number of lines to display in occur for better performance,
;;     see 'org-index-occur-max-lines'
;; 

;;; Code:

;;
;;  Please note, that this package uses two prefixes, `org-index' for user
;;  visible symbols and `oidx' (which is shorter) for internal stuff.
;;  And below `oidx' there is a sub-prefix `oidx--o' for all things related to occur.
;;
;;  Code can be folded and browsed with `hs-minor-mode'.
;;

(require 'org)
(require 'org-table)
(require 'org-id)
(require 'org-inlinetask)
(require 'cl-lib)
(require 'widget)
(require 'dash)
(require 's)

;; Variables to hold the configuration of the index table
(defvar oidx--ref-head nil "Head before number in reference (e.g. 'R').")
(defvar oidx--ref-tail nil "Tail after number in reference (e.g. '}' or ')'.")
(defvar oidx--ref-regex nil "Regular expression to match a reference.")
(defvar oidx--ref-format nil "Format, that can print a reference.")
(defvar oidx--point nil "Position at start of headline of index table.")
(defvar oidx--below-hline nil "Position of first cell in first line below hline.")
(defvar oidx--saved-positions nil "Saved positions within current buffer and index buffer; filled by ‘oidx--save-positions’.")
(defvar oidx--columns-map nil "Columns of index-table.")
(defvar oidx--headings nil "Headlines of index-table as a string.")
(defvar oidx--headings-visible nil "Visible part of headlines of index-table as a string.")

;; Variables to hold context and state
(defvar oidx--buffer nil "Buffer, that contains index.")
(defvar oidx--last-fingerprint nil "Fingerprint of last line created.")
(defvar oidx--category-before nil "Category of node before.")
(defvar oidx--within-index-node nil "Non-nil, if we are within node of the index table.")
(defvar oidx--within-occur nil "Non-nil, if we are within the occur-buffer.")
(defvar oidx--recording-screencast nil "Set Non-nil, if screencast is beeing recorded to trigger some minor tweaks.")
(defvar oidx--aligned-and-sorted nil "For this Emacs session: remember if aligned and sorted.")
(defvar oidx--edit-widgets nil "List of widgets used to edit.")
(defvar oidx--edit-where-from-index nil "Position and line used for index in edit buffer.")
(defvar oidx--edit-where-from-occur nil "Position and line used for occur in edit buffer.")
(defvar oidx--edit-where-from-node nil "Buffer and position for node in edit buffer.")
(defvar oidx--skip-verify-id nil "If true, do not verify index id; intended to be let-bound.")
(defvar oidx--message-text nil "Text that was issued as an explanation; helpful for regression tests.")

;; static information for this program package
(defconst oidx--commands '(occur add kill node index ref yank edit details help example sort maintain) "List of commands available.")
(defconst oidx--all-columns '(ref id created last-accessed count keywords category level yank tags) "All valid headings.")
(defconst oidx--edit-buffer-name "*org-index-edit*" "Name of edit buffer.")
(defconst oidx--details-buffer-name "*org-index-details*" "Name of details buffer.")
(defconst oidx--short-help-buffer-name "*org-index commands*" "Name of buffer to display short help.")
(defvar oidx--short-help-text nil "Cache for result of `oidx--get-short-help-text.")
(defvar oidx--shortcut-chars nil "Cache for result of `oidx--get-shortcut-chars.")

;; Version of this package
(defvar org-index-version "7.0.1" "Version of `org-index', format is major.minor.bugfix, where \"major\" are incompatible changes and \"minor\" are new features.")

;; customizable options
(defgroup org-index nil
  "Options concerning the optional index for org."
  :tag "Org Index"
  :group 'org)

(defcustom org-index-id nil
  "Id of the Org-mode node, which contains the index table."
  :type 'string
  :group 'org-index)

(defcustom org-index-occur-columns 4
  "Number of columns to search during occur.
This is mainly used to avoid spurious matches within the id-column.
With the default index columns, this setting will ignore everything
after the tags-column.
Please note, that you may have to adjust this setting, if you reorder
the columns in your index."
  :group 'org-index
  :initialize 'custom-initialize-set
  :set (lambda (var val)
         (when val
           (if (< val 1)
               (error "Need to have at least one column for occur"))
           (if (and oidx--columns-map (> val (length oidx--columns-map)))
               (error (format "Cannot set this higher than the number of columts (=%d)" (length oidx--columns-map))))
           (custom-set-default var val)))
  :type 'integer)

(defcustom org-index-occur-max-lines 16
  "Maximum number of lines to show in occur; zero means height of window.
This can be helpful to speed up occur."
  :group 'org-index
  :initialize 'custom-initialize-set
  :set (lambda (var val)
         (when (< val 0)
           (error "Number of lines must be positive"))
         (custom-set-default var val))
  :type 'integer)

(defcustom org-index-key ""
  "Key (as string) to invoke ‘org-index’, which is the central entry function for ‘org-index’.  When setting with customize: do not type the key-sequence but its description, e.g. `C-c i' as five ordinary characters."
  :group 'org-index
  :initialize 'custom-initialize-set
  :set (lambda (var val)
         (custom-set-default var val)
         (when (and val (not (string= val "")))
           (global-set-key (kbd val) 'org-index)))
  :type 'string)

(defcustom org-index-yank-after-add 'ref
  "Specifies which column should be yanked after adding a new index row.
Valid values are some columns of index table."
  :group 'org-index
  :type '(choice
	  (const ref)
	  (const category)
	  (const keywords)))

(defcustom org-index-copy-heading-to-keywords t
  "When adding a new node to index: Copy heading to keywords-column ?"
  :group 'org-index
  :type '(choice (const :tag "Yes" t)
                 (const :tag "No" nil)))

(defcustom org-index-strip-ref-and-date-from-heading t
  "When adding a node to index: strip leading ref or timestamps ?

This can be useful, if you have the habit of adding refs and
dates to the start of your headings; then, if you change your
heading and want to update your index, you do not need to remove
those pieces."
  :group 'org-index
  :type '(choice (const :tag "Yes" t)
                 (const :tag "No" nil)))

(defcustom org-index-edit-on-add '(category keywords)
  "List of columns to edit when adding a new row."
  :group 'org-index
  :type '(repeat (choice
                  (const category)
                  (const keywords))))

(defcustom org-index-edit-on-yank '(keywords yank)
  "List of columns to edit when adding new text to yank."
  :group 'org-index
  :type '(repeat (choice
                  (const yank)
                  (const category)
                  (const keywords))))

(defcustom org-index-edit-on-ref '(category keywords)
  "List of columns to edit when adding new ref."
  :group 'org-index
  :type '(repeat (choice
                  (const category)
                  (const keywords))))


(defmacro oidx--on (column value &rest body)
  "Execute the forms in BODY with point on index line whose COLUMN is VALUE.
The value returned is the value of the last form in BODY or nil,
if VALUE cannot be found."
  (declare (indent 2) (debug t))
  (let ((pointvar (make-symbol "point"))
        (foundvar (make-symbol "found"))
        (retvar (make-symbol "ret")))
    `(save-current-buffer
       (let ((,pointvar (point))
             ,foundvar
             ,retvar)

         (set-buffer oidx--buffer)

         (setq ,foundvar (oidx--go ,column ,value))
         (when ,foundvar
           (setq ,retvar (progn ,@body)))
         
         (goto-char ,pointvar)
         
         ,retvar))))


(defmacro oidx--plist-put (plist &rest args)
  "Version of `plist-get', that already includes the obligatory setq around.
For arguments PLIST and ARGS see there."
  (let ((list nil))
    (while args
      (push `(setq ,plist (plist-put ,plist ,(pop args) ,(pop args))) list))
    (cons 'progn (nreverse list))))


(defun org-index (arg)
  ;; Do NOT edit the part of this help-text before version number. It will
  ;; be overwritten with Commentary-section from beginning of this file.
  ;; Editing after version number is fine.
  ;;
  ;; For Rake: Insert here
  "Fast search for selected org-nodes and things outside.

`org-index' (package and interactive function) helps to create and
update an index-table with keywords; each line either points to a
heading in org, references a folder outside of org or carries an url or
a snippet of text.  When searching the index, the set of matching lines
is updated with every keystroke; results are sorted by usage count and
date, so that frequently or recently used entries appear first in the
list of results.

Please note, that org-index uses org-id throughout and therefore adds
an id-property to all nodes in the index.

In the addition to the index table, org-index introduces the concept of
references: These are decorated numbers (e.g. 'R237' or '--455--');
they are well suited to be used outside of org, e.g. in folder names,
ticket systems or on printed documents.

On first invocation org-index will assist you in creating the index
table.

To start using your index, invoke the subcommand 'add' to create
index entries and 'occur' to find them.

The set of columns within the index-table is fixed (see variable
`oidx--all-columns') but can be arranged in any order you wish; just
edit the index table.  The number of columns shown during occur is
determined by `org-index-occur-columns'.  Using both features allows to
make columns invisible, that you dont care about.

This is version 7.0.1 of org-index.el.

The function `org-index' is the main interactive function of this
package and its main entry point; it will present you with a list
of subcommands to choose from:

\(Note the one-letter shortcuts, e.g. [o]; used like `\\[org-index] o'.)

  occur: [o] Incrementally show matching lines from index.
    Result is updated after every keystroke.  You may enter a
    list of words seperated by space or comma (`,'), to select
    lines that contain all of the given words.

  add: [a] Add the current node to index.
    So that (e.g.) it can be found through the subcommand
    'occur'.  Update index, if node is already present.

  index: [i] Enter index table and maybe go to a specific reference.
    Use `org-mark-ring-goto' (\\[org-mark-ring-goto]) to go back.

  ref: [r] Create a new index line with a reference.
    This line will not be associated with a node.

  yank: [y] Store a new string, that can be yanked from occur.
    The index line will not be associated with a node.

  edit: [e] Present current line in edit buffer.
    Can be invoked from index, from occur or from a headline.

  details: [d] Show details for current line at bottom of frame.
    Can be invoked from index, from occur or from a headline.

  node: [n] Go to node, by ref or from index line.
    If invoked from within index table, go to associated
    node (if any).
  
  help: Show complete help text of `org-index'.
    I.e. this text.

  kill: Kill (delete) the current node from index.
    Can be invoked from index, from occur or from a headline.

  example: Create an example index, that will not be saved.
    May serve as an example.

  sort: Sort lines of index by last access (if today),
         otherwise count.

  maintain: [m] Index maintainance.
     Offers some choices to check, update or fix your index.

Use `org-customize' to tweak the behaviour of `org-index'.

This includes the global key `org-index-key' to invoke
the most important subcommands with one additional key.

Prefix argument ARG is passed to subcommand add."
  (interactive "P")

  (let (command        ; command to execute
        kill-new-text  ; text that will be appended to kill ring
        message-text)  ; text that will be issued as an explanation

    
    (catch 'new-index

      ;;
      ;; Initialize and parse
      ;;

      ;; creates index table, if necessary
      (oidx--verify-id)

      ;; Get configuration of index table
      (oidx--parse-table t)

      ;; save context before entering index
      (oidx--retrieve-context-on-invoke t)

      ;;
      ;; Find out, what we are supposed to do and prepare
      ;;

      ;; read command from user
      (setq command (oidx--read-command))

      ;; Arrange for beeing able to return
      (when (and (memq command '(occur node index example sort maintain))
                 (not (string= (buffer-name) oidx--o-buffer-name)))
        (org-mark-ring-push))



      ;;
      ;; Actually do, what has been requested
      ;;

      (cond
       
       ((eq command 'help)

        ;; bring up help-buffer for this function
        (describe-function 'org-index))

       
       ((eq command 'add)

        (-setq (message-text . kill-new-text) (oidx--do-add-or-update arg)))


       ((eq command 'kill)
        (setq message-text (oidx--do-kill)))


       ((eq command 'node)

        (setq message-text
              (if (and oidx--within-index-node
                       (org-match-line org-table-line-regexp))
                  (let ((search-id (oidx--get-or-set-field 'id)))
                    (if search-id
			(progn
			  (oidx--update-current-line)
			  (oidx--find-id search-id))
                      "Current line has no id"))
                "Not at index table")))


       ((eq command 'index)

        (setq message-text (oidx--do-index))
        (recenter))


       ((eq command 'occur)

        (set-buffer oidx--buffer)
        (oidx--do-occur))


       ((eq command 'ref)

        (let (args newref)

          (setq args (oidx--collect-values-from-user org-index-edit-on-ref))
          (setq newref (oidx--get-save-maxref))
          (oidx--plist-put args 'ref newref 'category "ref")
          (apply 'oidx--create-new-line args)
          
          (setq kill-new-text newref)
          
          (setq message-text (format "Added new row with ref '%s'" newref))))
       
       
       ((eq command 'yank)
        
        (let (vals yank)
          
          (setq vals (oidx--collect-values-from-user org-index-edit-on-yank))
          (if (setq yank (plist-get vals 'yank))
              (oidx--plist-put vals 'yank (replace-regexp-in-string "|" "\\vert" yank nil 'literal)))
          (oidx--plist-put vals 'category "yank")
          (apply 'oidx--create-new-line vals)
          (setq message-text "Added new row with text to yank")))
       
       
       ((eq command 'edit)
        
        (setq message-text (oidx--do-edit)))
       

       ((eq command 'details)

        (setq message-text (oidx--o-action-details)))
       

       ((eq command 'sort)

	(oidx--enter-index-to-stay)
        (oidx--sort-index)
	(org-table-goto-column 1)
        (setq message-text "Index has been sorted"))

        
       ((eq command 'maintain)

        (setq message-text (oidx--do-maintain)))

       
       ((eq command 'example)

        (if (y-or-n-p "This assistant will help you to create a temporary index with detailed comments.\nDo you want to proceed ? ")
          (oidx--create-index t)))


       ((not command) (setq message-text "No command given"))

       
       (t (error "Unknown subcommand '%s'" command)))


      ;; tell, what we have done and what can be yanked
      (if kill-new-text (setq kill-new-text
                              (substring-no-properties kill-new-text)))
      (if (string= kill-new-text "") (setq kill-new-text nil))
      (let ((m (concat
                message-text
                (if (and message-text kill-new-text)
                    " and r"
                  (if kill-new-text "R" ""))
                (if kill-new-text (format "eady to yank '%s'." kill-new-text) (if message-text "." "")))))
        (unless (string= m "")
          (message m)
	  (setq oidx--message-text m)))
      (if kill-new-text (kill-new kill-new-text)))))



;; Reading user input
(defun oidx--read-command ()
  "Read command from user and return it; with detailed prompt, if a single char is not enough."
  (let (char command detailed-prompt)
    (while (and (not command)
                (not detailed-prompt))
      (if (sit-for echo-keystrokes)
          (message "org-index (type a shortcut char or <space>,h,? for a detailed prompt) -- "))

      (setq char (downcase (key-description (read-key-sequence nil))))
      (if (string= char "c-g") (keyboard-quit))
      (setq detailed-prompt (or (string= char "?") (string= char "spc")))
      
      (setq command (cdr (assoc char (oidx--get-shortcut-chars))))
      (unless (or command
                  detailed-prompt)
        (setq detailed-prompt (yes-or-no-p (format "No subcommand for '%s'; switch to detailed prompt ? " char)))))

    (unless command
      (oidx--display-short-help)
      (unwind-protect
          (setq command
                (intern
                 (downcase
                  (completing-read
                   "Please choose: "
                   (append (mapcar 'symbol-name oidx--commands))))))
        (quit-windows-on oidx--short-help-buffer-name)))
    command))


(defun oidx--display-short-help (&optional prompt choices)
  "Helper function to show help for minibuffer and PROMPT for CHOICES."
  (interactive)

  (with-temp-buffer-window
   oidx--short-help-buffer-name '((display-buffer-at-bottom)) nil
   (setq oidx--short-help-displayed t)
   (princ (or prompt "Short help; shortcut chars in [].\n"))
   (princ (or choices (oidx--get-short-help-text))))
  (with-current-buffer oidx--short-help-buffer-name
    (let ((inhibit-read-only t))
      (setq mode-line-format nil)
      (setq cursor-type nil)
      (fit-window-to-buffer (get-buffer-window))
      (setq window-size-fixed 'height)
      (goto-char (point-min))
      (end-of-line))))


(defun oidx--get-short-help-text ()
  "Extract text for short help message from long help."
  (or oidx--short-help-text
      (with-temp-buffer
        (insert (documentation 'org-index))
        (keep-lines "^  [-a-z]+:" (point-min) (point-max))
        (let ((cnt (count-lines (point-min) (point-max)))
              (len (length oidx--commands)))
          (unless (= cnt len)
            (error "Internal error: count of lines matched %d does not equal number of comments %d; full details in *Messages*:\nThere is a mismatch beween:\n\n%s\nand:\n\n%s\n" cnt len oidx--commands (buffer-substring (point-min) (point-max)) )))
        (align-regexp (point-min) (point-max) "\\(\\s-*\\):")
        (untabify (point-min) (point-max))
        (goto-char (point-min))
        (while (re-search-forward "\\. *$" nil t)
          (replace-match "" nil nil))
        (goto-char (point-min))
        (setq oidx--short-help-text (buffer-string)))))


(defun oidx--get-shortcut-chars ()
  "Collect shortcut chars from short help message."
  (or oidx--shortcut-chars
      (with-temp-buffer
        (insert (oidx--get-short-help-text))
        (goto-char (point-min))
        (while (< (point) (point-max))
          (when (looking-at "^ *\\([-a-z]+\\) *: +\\[\\([a-z,?]+\\)\\] ")
            (let ((chars (-remove-item "," (mapcar 'char-to-string (match-string 2)))))
              (dolist (char chars)
                (push (cons char (intern (match-string 1)))
                      oidx--shortcut-chars))))
          (forward-line 1))
        (unless (> (length oidx--shortcut-chars) 0)
          (error "Internal error, did not find shortcut chars"))
        oidx--shortcut-chars)))


(defun oidx--completing-read (prompt choices &optional default)
  "Completing read, that displays multiline PROMPT in a windows and then asks for CHOICES with DEFAULT."
  (interactive)
  (let ((bname "*org-index explanation for input prompt*")
        explain short-prompt lines result)
    (ignore-errors (quit-windows-on bname))
    (setq lines (split-string prompt "\n"))
    (setq short-prompt (car (last lines)))
    (setq explain (apply 'concat (mapcar (lambda (x) (concat x "\n")) (butlast lines))))
    (unless (string= explain "")
      (setq explain (substring explain 0 (- (length explain) 1))))
    (unwind-protect
        (progn
          (when (not (string= explain ""))
            (with-temp-buffer-window
             bname '((display-buffer-at-bottom)) nil
             (princ explain))
            
            (with-current-buffer bname
              (let ((inhibit-read-only t))
                (setq mode-line-format nil)
                (setq cursor-type nil)
                (fit-window-to-buffer (get-buffer-window))
                (setq window-size-fixed 'height)
                (add-text-properties (point-min) (point-at-eol) '(face org-level-3))
                (goto-char (point-min)))))
          (setq result (org-completing-read short-prompt choices nil t nil nil default)))
      (ignore-errors
        (quit-windows-on bname)
        (kill-buffer bname)))
    result))


(defun oidx--read-search-for-command-index ()
  "Special input routine for command index: ask what to search for."

)



;; Parse index and refs
(defun oidx--ref-from-id (id)
  "Get reference from line ID."
  (oidx--on 'id id (oidx--get-or-set-field 'ref)))


(defun oidx--id-from-ref (ref)
  "Get id from line REF."
  (oidx--on 'ref ref (oidx--get-or-set-field 'id)))


(defun oidx--get-fingerprint ()
  "Get fingerprint of current line."
  (replace-regexp-in-string
   "\\s " ""
   (mapconcat (lambda (x) (oidx--get-or-set-field x)) '(id ref yank keywords created) "")))


(defun oidx--verify-id (&optional silent)
  "Check, that we have a valid id.
Optional argument SILENT prevents invoking interactive assistant."

  (unless oidx--skip-verify-id
    ;; Check id
    (unless org-index-id
      (if silent (throw 'missing-index t))
      (let ((answer (oidx--completing-read "Cannot find index (org-index-id is not set). You may:\n  - read-help    : to learn more about org-index\n  - create-index : invoke an assistant to create an initial index\nPlease choose: " (list "read-help" "create-index") "read-help")))
        (if (string= answer "create-index")
            (oidx--create-index)
          (describe-function 'org-index)
          (throw 'new-index nil))))

    ;; Find node
    (let (marker)
      (setq marker (org-id-find org-index-id 'marker))
      (unless marker
        (if silent (throw 'missing-index t))
        (oidx--create-missing-index "Cannot find the node with id \"%s\" (as specified by variable org-index-id)." org-index-id))
      ;; Try again with new node
      (setq marker (org-id-find org-index-id 'marker))
      (unless marker
        (if silent (throw 'missing-index t))
        (error "Could not create node"))
      (setq oidx--buffer (marker-buffer marker)
            oidx--point (marker-position marker))
      (move-marker marker nil))))


(defun oidx--parse-table (&optional num-lines-to-format)
  "Parse content of index table.
Optional argument NUM-LINES-TO-FORMAT limits formatting effort and duration."
 
  (let (initial-point
        end-of-headings
        start-of-headings
        max-ref-field)

    (unless num-lines-to-format (setq num-lines-to-format 0))

    (with-current-buffer oidx--buffer

      (setq initial-point (point))

      (oidx--go-below-hline)
      (org-reveal)

      (unless oidx--aligned-and-sorted
        ;; align, fontify and sort table once for this emacs session
        (message "Align, fontify and sort index table (once per emacs session)...")
        (oidx--sort-index)
        (goto-char oidx--below-hline)

        (org-table-align)
        (font-lock-fontify-region (point) (org-table-end))

        (setq oidx--aligned-and-sorted t)
        (goto-char oidx--below-hline)

        (message "Done."))

      (beginning-of-line)
      
      ;; get headings to display during occur
      (setq end-of-headings (point))
      (goto-char (org-table-begin))
      (setq start-of-headings (point))
      (setq oidx--headings-visible (substring-no-properties (oidx--copy-visible start-of-headings end-of-headings)))
      (setq oidx--headings (buffer-substring start-of-headings end-of-headings))
      
      ;; go to top of table
      (goto-char (org-table-begin))
      
      ;; parse line of headings
      (oidx--parse-headings)

      ;; read property or go through table to find maximum number
      (goto-char oidx--below-hline)
      (setq max-ref-field (or (org-entry-get oidx--point "max-ref")
                              (oidx--migrate-maxref-to-property)))
      
      (unless oidx--ref-head (oidx--get-decoration-from-ref-field max-ref-field))
      
      ;; go back to initial position
      (goto-char initial-point))))


(defun oidx--retrieve-context-on-invoke (&optional get-category)
  "Collect context information before starting with command.
If GET-CATEGORY is set, retrieve it too."

  ;; get category of current node
  (when get-category
    (setq oidx--category-before
          (save-excursion ; workaround: org-get-category does not give category when at end of buffer
            (beginning-of-line)
            (org-get-category (point) t))))

  ;; Find out, if we are within index table or occur buffer
  (setq oidx--within-index-node (string= (org-id-get) org-index-id))
  (setq oidx--within-occur (string= (buffer-name) oidx--o-buffer-name)))


(defun oidx--get-decoration-from-ref-field (ref-field)
  "Extract decoration from a REF-FIELD."
  (unless (string-match "^\\([^0-9]*\\)\\([0-9]+\\)\\([^0-9]*\\)$" ref-field)
    (oidx--report-index-error
     "Reference in index table ('%s') does not contain a number" ref-field))
  
  ;; These are the decorations used within the first ref of index
  (setq oidx--ref-head (match-string 1 ref-field))
  (setq oidx--ref-tail (match-string 3 ref-field))
  (setq oidx--ref-regex (concat (regexp-quote oidx--ref-head)
                                "\\([0-9]+\\)"
                                (regexp-quote oidx--ref-tail)))
  (setq oidx--ref-format (concat oidx--ref-head "%d" oidx--ref-tail)))


(defun oidx--extract-refnum (ref-field)
  "Extract the number from a complete reference REF-FIELD like 'R102'."
  (unless (string-match oidx--ref-regex ref-field)
    (oidx--report-index-error
     "Reference '%s' is not formatted properly (does not match '%s')" ref-field oidx--ref-regex))
  (string-to-number (match-string 1 ref-field)))


(defun oidx--parse-headings ()
  "Parse headings of index table."

  (let (field         ;; field content
        field-symbol) ;; and as a symbol

    (setq oidx--columns-map nil)

    ;; For each column
    (dotimes (col (length oidx--all-columns))

      (setq field (substring-no-properties (downcase (org-trim (org-table-get-field (+ col 1))))))

      (if (string= field "")
          (error "Heading of column cannot be empty"))
      (if (not (member (intern field) oidx--all-columns))
          (error "Column name '%s' is not a valid heading" field))

      (setq field-symbol (intern field))

      ;; check if heading has already appeared
      (if (assoc field-symbol oidx--columns-map)
          (oidx--report-index-error
           "'%s' appears two times as column heading" (downcase field))
        ;; add it to list at front, reverse later
        (push (cons field-symbol (+ col 1)) oidx--columns-map))))

  (setq oidx--columns-map (reverse oidx--columns-map))

  ;; check if all headings have appeared
  (mapc (lambda (head)
          (unless (cdr (assoc head oidx--columns-map))
            (oidx--report-index-error "No column has heading '%s'" head)))
        oidx--all-columns))


(defun oidx--refresh-parse-table ()
  "Fast refresh of selected results of parsing index table."

  (setq oidx--point (marker-position (org-id-find org-index-id 'marker)))
  (with-current-buffer oidx--buffer
    (save-excursion
      (oidx--go-below-hline))))



;; Edit, add or kill lines
(defun oidx--do-edit ()
  "Perform command or occur-action edit."
  (let (buffer-keymap field-keymap keywords-pos cols-vals maxlen)

    (setq oidx--edit-where-from-occur nil)
    (setq oidx--edit-where-from-node nil)
    
    ;; save context and change to index if invoked from outside
    (cond
     (oidx--within-occur
      (let ((pos (get-text-property (point) 'org-index-lbp)))
        (oidx--o-test-stale pos)
        (setq oidx--edit-where-from-occur (cons (point) (oidx--line-in-canonical-form)))
        (set-buffer oidx--buffer)
        (goto-char pos)))
      
     ((not oidx--within-index-node)
      (let ((id (org-id-get)))
        (setq oidx--edit-where-from-node (cons (current-buffer) (point)))
        (set-buffer oidx--buffer)
        (unless (and id (oidx--go 'id id))
          (setq oidx--edit-where-from-node nil)
          (error "This node is not in index")))))

    ;; remember context and get content of line, that will be edited
    (setq oidx--edit-where-from-index (cons (point) (oidx--line-in-canonical-form)))
    (-setq (cols-vals . maxlen) (oidx--content-of-current-line))

    ;; create keymaps
    (setq buffer-keymap (make-sparse-keymap))
    (set-keymap-parent buffer-keymap widget-keymap)
    (define-key buffer-keymap (kbd "C-c C-c") 'oidx--edit-accept)
    (define-key buffer-keymap (kbd "C-c C-k") 'oidx--edit-abort)
    
    (setq field-keymap (make-sparse-keymap))
    (set-keymap-parent field-keymap widget-field-keymap)
    (define-key field-keymap (kbd "C-c C-c") 'oidx--edit-accept)
    (define-key field-keymap (kbd "C-c C-k") 'oidx--edit-abort)

    ;; prepare buffer
    (ignore-errors (kill-buffer oidx--edit-buffer-name))
    (switch-to-buffer (get-buffer-create oidx--edit-buffer-name))
    ;; create and fill widgets
    (setq oidx--edit-widgets nil)
    (widget-insert "Edit this line from index; type C-c C-c when done, C-c C-k to abort.\n\n")
    (dolist (col-val cols-vals)
      (if (eq (car col-val) 'keywords) (setq keywords-pos (+ (point-at-bol) maxlen 2)))
      (push
       (cons (car col-val)
             (widget-create 'editable-field
                            :format (format  (format "%%%ds: %%%%v" maxlen) (symbol-name (car col-val)))
                            :keymap field-keymap
                            (or (cdr col-val) "")))
       oidx--edit-widgets))

    (widget-setup)
    (goto-char keywords-pos)
    (use-local-map buffer-keymap)
    "Editing a single line of index"))


(defun oidx--content-of-current-line ()
  "Retrieve current content of index line."
  (let ((maxlen 0) cols-vals val)
    (dolist (col (mapcar 'car (reverse oidx--columns-map)))
      (setq maxlen (max maxlen (length (symbol-name col))))
      (setq val (oidx--get-or-set-field col))
      (if (and val (eq col 'yank)) (setq val (replace-regexp-in-string (regexp-quote "\\vert") "|" val nil 'literal)))
      (push (cons col val)
            cols-vals))
    (cons cols-vals maxlen)))


(defun oidx--edit-accept ()
  "Function to accept editing in Edit buffer."
  (interactive)

  (let (val line)
    
    ;; Time might have passed
    (oidx--refresh-parse-table)
    
    (with-current-buffer oidx--buffer
      
      ;; check, if index has changed while editing
      (save-excursion
        (goto-char (car oidx--edit-where-from-index))
        (unless (string= (cdr oidx--edit-where-from-index)
                         (oidx--line-in-canonical-form))
          (switch-to-buffer oidx--edit-buffer-name)
          (error "Index table has changed: Cannot find line, that this buffer is editing")))
      
      ;; write back line to index
      (dolist (col-widget oidx--edit-widgets)
        (setq val (widget-value (cdr col-widget)))
        (if (eq (car col-widget) 'yank) (setq val (replace-regexp-in-string "|" (regexp-quote "\\vert") val)))
        (oidx--get-or-set-field (car col-widget) val))
      
      (setq line (oidx--align-and-fontify-current-line))
      (beginning-of-line))
    
    (cond
     ;; invoked from occur
     (oidx--edit-where-from-occur
      (pop-to-buffer-same-window (or (get-buffer oidx--o-buffer-name)
				     (error "Occur buffer has gone cannot update (index has been updated though)")))
      (goto-char (car oidx--edit-where-from-occur))
      (beginning-of-line)

      ;; update line in occur
      (let ((inhibit-read-only t))
        (delete-region (line-beginning-position) (line-end-position))
        (insert line)
        (put-text-property (line-beginning-position) (line-end-position)
                           'org-index-lbp (car oidx--edit-where-from-index))))
     
     ;; invoked from arbitrary node
     (oidx--edit-where-from-node
      (pop-to-buffer-same-window (car oidx--edit-where-from-node))
      (goto-char (cdr oidx--edit-where-from-node)))
     
     ;; invoked from index
     (t
      (pop-to-buffer-same-window oidx--buffer)
      (goto-char (car oidx--edit-where-from-index))))
    
    ;; clean up
    (kill-buffer oidx--edit-buffer-name)
    (setq oidx--edit-where-from-index nil)
    (setq oidx--edit-widgets nil)
    (beginning-of-line)
    (message "Index line has been edited.")))


(defun oidx--edit-abort ()
  "Function to abort editing in Edit buffer."
  (interactive)
  (kill-buffer oidx--edit-buffer-name)
  (setq oidx--edit-where-from-index nil)
  (setq oidx--edit-widgets nil)
  (beginning-of-line)
  (message "Edit aborted."))


(defun oidx--create-new-line (&rest keys-values)
  "Add a new line to index.
Optional argument KEYS-VALUES specifies content of new line."

  (with-current-buffer oidx--buffer
    (goto-char oidx--point)

    ;; check arguments early, before we create anything
    (let ((kvs keys-values)
          k v)
      (while kvs
        (setq k (car kvs))
        (setq v (cadr kvs))
        (if (or (not (symbolp k))
                (and (symbolp v) (not (eq v t)) (not (eq v nil))))
            (error "Arguments must be alternation of key and value"))
        (unless (oidx--column-num k)
          (error "Unknown column or column not defined in table: '%s'" (symbol-name k)))
        (setq kvs (cddr kvs))))

    (let (yank)
      ;; create new line
      (oidx--create-empty-line)

      ;; fill columns
      (let ((kvs keys-values)
            k v)
        (while kvs
          (setq k (car kvs))
          (setq v (cadr kvs))
          (org-table-goto-column (oidx--column-num k))
          (insert (org-trim (or v "")))
          (setq kvs (cddr kvs))))

      ;; align and fontify line
      (oidx--promote-current-line)
      (oidx--align-and-fontify-current-line)

      ;; remember fingerprint to be able to return
      (setq oidx--last-fingerprint (oidx--get-or-set-field 'fingerprint))
      
      ;; get column to yank
      (setq yank (oidx--get-or-set-field org-index-yank-after-add))

      yank)))


(defun oidx--create-empty-line ()
  "Do the common work for `org-index'."

  ;; insert ref or id as last or first line, depending on sort-column
  (goto-char oidx--below-hline)
  (org-table-insert-row)

  ;; insert some of the standard values
  (org-table-goto-column (oidx--column-num 'created))
  (org-insert-time-stamp nil nil t)
  (org-table-goto-column (oidx--column-num 'count))
  (insert "1"))


(defun oidx--collect-values-for-add-update (id &optional silent category)
  "Collect values for adding or updating line specified by ID, do not ask if SILENT, use CATEGORY, if given."
  
  (let ((args (list 'id id))
        content)
    
    (dolist (col (mapcar 'car oidx--columns-map))
      
      (setq content "")

      (cond
       ((eq col 'keywords)
        (if org-index-copy-heading-to-keywords
            (setq content (nth 4 (org-heading-components))))
        
        ;; Shift ref and timestamp ?
        (if org-index-strip-ref-and-date-from-heading
            (dotimes (_i 2)
              (if (or (string-match (concat "^\\s-*" oidx--ref-regex) content)
                      (string-match (concat "^\\s-*" org-ts-regexp-both) content))
                  (setq content (substring content (match-end 0)))))))
       
       ((eq col 'category)
        (setq content (or category oidx--category-before)))
       
       ((eq col 'level)
        (setq content (number-to-string (org-outline-level))))
       
       ((eq col 'tags)
        (setq content (org-make-tag-string (org-get-tags nil t)))))
      
      (unless (string= content "")
        (oidx--plist-put args col content)))

    (if (not silent)
        (let ((args-edited (oidx--collect-values-from-user org-index-edit-on-add args)))
          (setq args (append args-edited args))))

    args))


(defun oidx--collect-values-for-add-update-remote (id)
  "Wrap `oidx--collect-values-for-add-update' by prior moving to remote node identified by ID."
  
  (let (marker point args)

    (setq marker (org-id-find id t))
    ;; enter buffer and collect information
    (with-current-buffer (marker-buffer marker)
      (setq point (point))
      (goto-char marker)
      (setq args (oidx--collect-values-for-add-update id t (org-get-category (point) t)))
      (goto-char point))

    args))


(defun oidx--collect-values-from-user (cols &optional defaults)
  "Collect values for adding a new line.
Argument COLS gives list of columns to edit.
Optional argument DEFAULTS gives default values."
  
  (let (content args def def-clause)
    (dolist (col cols)
      (setq content "")
      (setq def (plist-get col defaults))
      (setq def-clause (if def (format " (default: '%s')" def) ""))
      (setq content (read-from-minibuffer
                     (format "Enter text for column '%s'%s: " (symbol-name col) def-clause)
                     (plist-get col defaults)))
      
      (unless (string= content "")
        (oidx--plist-put args col content)))
    args))


(defun oidx--write-fields (kvs)
  "Update current line with values from KVS (keys-values)."
  (while kvs
    (oidx--get-or-set-field (car kvs) (org-trim (cadr kvs)))
    (setq kvs (cddr kvs))))


(defun oidx--do-add-or-update (&optional create-ref)
  "For current node or current line in index, add or update in index table.
CREATE-REF creates a reference and passes it to yank."

  (let* (id id-from-index ref args yank ret)

    (unless (string-equal major-mode "org-mode")
      (error "This is not an org-buffer"))
    
    (oidx--save-positions)
    (unless (or oidx--within-index-node
                oidx--within-occur)
      (org-with-limited-levels (org-back-to-heading)))
    
    ;; try to do the same things from within index and from outside
    (if oidx--within-index-node

        (progn
          (unless (org-match-line org-table-line-regexp)
            (error "Within index node but not on table"))

          (setq id (oidx--get-or-set-field 'id))
          (setq ref (oidx--get-or-set-field 'ref))
          (setq args (oidx--collect-values-for-add-update-remote id))
          (oidx--write-fields args)
          (setq yank (oidx--get-or-set-field org-index-yank-after-add))

          (setq ret
                (if ref
                    (cons (format "Updated index line %s" ref) yank)
                  (cons "Updated index line" nil))))

      (setq id (org-id-get-create))
      (oidx--refresh-parse-table)
      (setq id-from-index (oidx--on 'id id id))
      (setq ref (oidx--on 'id id (oidx--get-or-set-field 'ref)))

      (setq args (oidx--collect-values-for-add-update id))

      (when (and create-ref
                 (not ref))
        (setq ref (oidx--get-save-maxref))
        (oidx--plist-put args 'ref ref))

      
      (if id-from-index
          ;; already have an id in index, find it and update fields
          (progn

            (oidx--on
                'id id
              (oidx--write-fields args)
              (setq yank (oidx--get-or-set-field org-index-yank-after-add)))

            (setq ret
                  (if ref
                      (cons (format "Updated index line %s" ref) yank)
                    (cons "Updated index line" nil))))

        ;; no id here, create new line in index
        (if ref (oidx--plist-put args 'ref ref))
        (setq yank (apply 'oidx--create-new-line args))

        (setq ret
              (if ref
                  (cons
                   (format "Added new index line %s" ref)
                   (concat yank " "))
                (cons
                 "Added new index line"
                 nil)))))
    
    (oidx--restore-positions)

    ret))


(defun oidx--do-kill ()
  "Perform command kill from within occur, index or node."

  (let (id ref chars-deleted-index text-deleted-from pos-in-index)

    (oidx--save-positions)
    (unless (or oidx--within-index-node
                oidx--within-occur)
      (org-with-limited-levels (org-back-to-heading)))
    
    ;; Collect information: What should be deleted ?
    (if (or oidx--within-occur
            oidx--within-index-node)

        (progn
          (if oidx--within-index-node
              ;; In index
              (setq pos-in-index (point))
            ;; In occur
            (setq pos-in-index (get-text-property (point) 'org-index-lbp))
            (oidx--o-test-stale pos-in-index)
            (set-buffer oidx--buffer)
            (goto-char pos-in-index))
          ;; In Index (maybe moved there)
          (setq id (oidx--get-or-set-field 'id))
          (setq ref (oidx--get-or-set-field 'ref)))

      ;; At a headline
      (setq id (org-entry-get (point) "ID"))
      (setq ref (oidx--ref-from-id id))
      (setq pos-in-index (oidx--on 'id id (point)))
      (unless pos-in-index (error "This node is not in index")))

    ;; Remark: Current buffer is not certain here, but we have all the information to delete
    
    ;; Delete from node
    (when id
      (let ((m (org-id-find id 'marker)))
        (set-buffer (marker-buffer m))
        (goto-char m)
        (move-marker m nil)
        (unless (string= (org-id-get) id)
          (error "Could not find node with id %s" id)))

      (oidx--delete-any-ref-from-tags)
      (if ref (oidx--delete-ref-from-heading ref))
      (push "node" text-deleted-from))

    ;; Delete from index
    (set-buffer oidx--buffer)
    (unless pos-in-index "Internal error, pos-in-index should be defined here")
    (goto-char pos-in-index)
    (setq chars-deleted-index (length (delete-and-extract-region (line-beginning-position) (line-beginning-position 2))))
    (push "index" text-deleted-from)
    
    ;; Delete from occur only if we started there, accept that it will be stale otherwise
    (if oidx--within-occur
        (let ((inhibit-read-only t))
          (set-buffer oidx--o-buffer-name)
          (delete-region (line-beginning-position) (line-beginning-position 2))
          ;; correct positions
          (while (org-match-line org-table-line-regexp)
            (put-text-property (line-beginning-position) (line-end-position) 'org-index-lbp
                               (- (get-text-property (point) 'org-index-lbp) chars-deleted-index))
            (forward-line))
          (push "occur" text-deleted-from)))

    (oidx--restore-positions)
    (concat "Deleted from: " (mapconcat 'identity (sort text-deleted-from 'string<) ","))))


(defun oidx--do-index ()
  "Perform command index."
            
  (let (char prompt text search-id)

    ;; start with short prompt but give more help on next iteration
    (setq prompt "Please specify where to go in index:  <space>,.) line for this node or occur,  l) last line inserted,  i) start of index table -- ")
  
    ;; read one character
    (while (not (memq char (list ?i ?. ?l ? )))
      (setq char (read-char prompt)))
    (if (eq char ? ) (setq char ?.))

    (setq text
	  (cond
	   ((and (eq char ?.) oidx--within-occur)
	    (let ((pos (or (get-text-property (point) 'org-index-lbp)
			   (error "This line is not from index"))))
	      (oidx--enter-index-to-stay)
	      (goto-char pos))
	    "At matching index line")
	   ((eq char ?.)
	    (setq search-id (or (org-id-get)
				(error "Current node has no id")))
	    (oidx--enter-index-to-stay)
	    (if (oidx--go 'id search-id)
		"At matching index line"
              (format "Did not find index line with id '%s'" search-id)))
	   
	   ((eq char ?l)
	    (oidx--enter-index-to-stay)
	    (if (oidx--go 'fingerprint oidx--last-fingerprint)
		(format "Found latest index line")
              (format "Did not find latest index line")))
	   
	   (t (oidx--enter-index-to-stay)
              "At index table")))

    (org-table-goto-column 1)
    text))



;; Sorting
(defun oidx--get-start-of-today ()
  "Get timestamp for sorting: Today at 0:00."
  (format-time-string
   (org-time-stamp-format t t)
   (apply 'encode-time (append '(0 0 0) (nthcdr 3 (decode-time))))))


(defun oidx--sort-index ()
  "Sort index table."

  (let ((is-modified (buffer-modified-p))
        top
        bottom
        start-of-today)

    (with-current-buffer oidx--buffer
      (unless buffer-read-only
	
	(message "Sorting index table...")
	(undo-boundary)
	
	(let ((message-log-max nil)) ; we have just issued a message, dont need those of sort-subr
	  
          (setq start-of-today (oidx--get-start-of-today))

          ;; get boundaries of table
	  (goto-char oidx--below-hline)
          (forward-line 0)
          (setq top (point))
          (goto-char (org-table-end))
	  
          ;; kill all empty rows at bottom
          (while (progn
                   (forward-line -1)
                   (org-table-goto-column 1)
                   (and
                    (not (oidx--get-or-set-field 'ref))
                    (not (oidx--get-or-set-field 'id))
                    (not (oidx--get-or-set-field 'yank))))
            (org-table-kill-row))
          (forward-line 1)
          (setq bottom (point))
          
          ;; sort lines
          (save-restriction
            (narrow-to-region top bottom)
            (goto-char top)
            (sort-subr t
                       'forward-line
                       'end-of-line
                       (lambda () (oidx--get-sort-key start-of-today))
                       nil
                       'string<)
            (goto-char (point-min))
	    
            ;; restore modification state
            (set-buffer-modified-p is-modified)))))))


(defun oidx--get-sort-key (time-threshold)
  "Get value for sorting.
Argument TIME-THRESHOLD switches between last-accessed and count."
  (let ((last-accessed (oidx--get-or-set-field 'last-accessed)))
    (concat
     ;; use column last accessed only if recent; otherwise use fixed value time-threshold,
     ;; so that recent entries are sorted by last access, but older entries are sorted by count
     (if (string> last-accessed time-threshold) last-accessed time-threshold)
     (format "%08d" (string-to-number (or (oidx--get-or-set-field 'count) ""))))))




;; Reading, modifying and handling single index line
(defun oidx--update-line (pos)
  "Update columns count and last-accessed in line at POS."

  (let (initial count)

    (with-current-buffer oidx--buffer
      (unless buffer-read-only
        (setq initial (point))
	(goto-char pos)
        (setq count (oidx--update-current-line))
        (goto-char initial)))
    count))


(defun oidx--update-current-line ()
  "Update current lines columns count and last-accessed."
  (let ((count-field (oidx--get-or-set-field 'count))
        newcount)

    ;; update count field only if number or empty
    (when (or (not count-field)
              (string-match "^[0-9]+$" count-field))
      (setq newcount (+ 1 (string-to-number (or count-field "0"))))
      (oidx--get-or-set-field 'count
                              (number-to-string newcount)))

    ;; update timestamp
    (org-table-goto-column (oidx--column-num 'last-accessed))
    (org-table-blank-field)
    (org-insert-time-stamp nil t t)

    ;; move line according to new content
    (oidx--promote-current-line)
    (oidx--align-and-fontify-current-line)

    newcount))


(defun oidx--align-and-fontify-current-line ()
  "Align the current line (might be in occur-buffer or index) as it would be aligned within the index; return the line too."
  ;; Do this by creating a small table, which contains the index headings and the current line
  (let (line line-fontified)
    ;; get current content
    (setq line (delete-and-extract-region (line-beginning-position) (line-end-position 1)))
    ;; create minimum table with fixed-width columns to align and fontify new line
    (insert
     (setq
      line-fontified
      (with-temp-buffer
        (org-set-font-lock-defaults)

	;; copy all lines of headings including any width-cookies
        (insert oidx--headings-visible)

	;; Spaces in first line of heading are replaced by tilde (~), so aligning table cannot shrink them;
	;; however, we make sure, that next to a bar (|) there are spaces, because otherwise aligning would
	;; introduce them and change line length in the process
	(mapc (lambda (x)
		(goto-char (point-min))
		(search-forward "|")
		(backward-char)
		(while (search-forward (car x) (line-end-position) t)
		  (replace-match (cdr x) nil t)))
	      '((" " . "~") ("~|~" . " | ") ("|~" . "| ") ("~|" . " |")))

	;; insert line
        (goto-char (point-max))
        (insert line)
        (forward-line 0)

	;; if the first cell of line starts with a hyphen (-) aligning would turn the whole line into a separator line
        (let ((start (point)))
          (while (re-search-forward "^\s +|-" nil t)
            (replace-match "| -"))
          (goto-char start))

	;; align and fontify
        (org-mode)
        (org-table-align)
        (font-lock-fontify-region (point-min) (point-max))

	;; extract aligned line
	(goto-char (point-max))
        (if (eq -1 (skip-chars-backward "\n"))
            (delete-char 1))
        (forward-line 0)
        (buffer-substring (line-beginning-position) (line-end-position 1)))))
    
    line-fontified))


(defun oidx--promote-current-line ()
  "Move current line up in table according to changed sort fields."
  (let (begin end key start-of-today
              (to-skip 0))

    (forward-line 0) ; stay at beginning of line

    (setq start-of-today (oidx--get-start-of-today))
    (setq key (oidx--get-sort-key start-of-today))
    (setq begin (point))
    (setq end (line-beginning-position 2))

    (forward-line -1)
    (while (and (org-match-line org-table-line-regexp)
                (not (org-at-table-hline-p))
                (string< (oidx--get-sort-key start-of-today) key))

      (cl-incf to-skip)
      (forward-line -1))
    (forward-line 1)

    ;; insert line at new position
    (when (> to-skip 0)
      (insert (delete-and-extract-region begin end))
      (forward-line -1))))


(defun oidx--get-or-set-field (key &optional value)
  "Retrieve field KEY from index table or set it to VALUE."
  (let (field)
    (save-excursion
      (if (eq key 'fingerprint)
          (progn
            (if value (error "Internal error, pseudo-column fingerprint cannot be set"))
            (setq field (oidx--get-fingerprint)))
        (setq field (org-trim (org-table-get-field (cdr (assoc key oidx--columns-map)) value))))
      (if (string= field "") (setq field nil))

      (org-no-properties field))))


(defun oidx--column-num (key)
  "Return number of column KEY."
  (if (numberp key)
      key
    (cdr (assoc key oidx--columns-map))))



;; Navigation
(defun oidx--go-below-hline ()
  "Move below hline in index-table."

  (let ((errstring (format "index table within node %s" org-index-id)))

    (goto-char oidx--point)

    ;; go to heading of node
    (while (not (org-at-heading-p)) (forward-line -1))
    (forward-line 1)

    ;; go to first table, but make sure we do not get into another node
    (while (and (not (org-match-line org-table-line-regexp))
                (not (org-at-heading-p))
                (not (eobp)))
      (forward-line))

    ;; check, if there really is a table
    (unless (org-match-line org-table-line-regexp)
      (oidx--create-missing-index "Cannot find %s." errstring))

    ;; go just after hline
    (while (and (not (org-at-table-hline-p))
                (org-match-line org-table-line-regexp))
      (forward-line))
    (forward-line)

    ;; and check
    (unless (org-match-line org-table-line-regexp)
      (oidx--report-index-error "Cannot find a hline within %s" errstring))

    (org-table-goto-column 1)
    (setq oidx--below-hline (point))))


(defun oidx--enter-index-to-stay ()
  "Enter index for commands that leave user there."
  (pop-to-buffer-same-window oidx--buffer)
  (goto-char oidx--below-hline)
  (oidx--unfold-buffer))


(defun oidx--unfold-buffer ()
  "Helper function to unfold buffer."
  (org-show-context 'tree)
  (org-reveal '(16))
  (recenter 1))


(defun oidx--make-guarded-search (ref &optional dont-quote)
  "Make robust search string from REF; DONT-QUOTE it, if requested."
  (concat "\\_<" (if dont-quote ref (regexp-quote ref)) "\\_>"))


(defun oidx--save-positions ()
  "Save current buffer and positions in index- and current buffer; not in occur-buffer."

  (let (cur-buf cur-mrk idx-pnt idx-mrk)
    (setq cur-buf (current-buffer))
    (setq cur-mrk (point-marker))
    (set-buffer oidx--buffer)
    (if (string= (org-id-get) org-index-id)
        (setq idx-pnt (point))
      (setq idx-mrk (point-marker)))
    (set-buffer cur-buf)
    (setq oidx--saved-positions (list cur-buf cur-mrk idx-pnt idx-mrk))))


(defun oidx--restore-positions ()
  "Restore positions as saved by `oidx--save-positions'."

  (cl-multiple-value-bind
      (cur-buf cur-mrk idx-pnt idx-mrk buf)
      oidx--saved-positions
    (setq buf (current-buffer))
    (set-buffer cur-buf)
    (goto-char cur-mrk)
    (set-buffer oidx--buffer)
    (goto-char (or idx-pnt idx-mrk))
    (set-buffer buf))
  (setq oidx--saved-positions nil))


(defun oidx--go (column value)
  "Position cursor on index line where COLUMN equals VALUE.
Return t or nil, leave point on line or at top of table, needs to be in buffer initially."
  (let (found)

    (unless (eq (current-buffer) oidx--buffer)
      (error "This is a bug: Not in index buffer"))

    (unless value
      (error "Cannot search for nil"))
    
    (if (string= value "")
        (error "Cannot search for empty string"))

    (if (<= (length value) 2)
        (warn "Searching for short string '%s' will be slow" value))

    (goto-char oidx--below-hline)
    (forward-line 0)
    (save-restriction
      (narrow-to-region (point) (org-table-end))
      (while (and (not found)
                  (search-forward value nil t))
        (setq found (string= value (oidx--get-or-set-field column)))))
    
    ;; return value
    (if found
        t
      (goto-char oidx--below-hline)
      nil)))


(defun oidx--find-id (id &optional other)
  "Perform command node: Find node with ID and present it.
If OTHER in separate window."
  
  (let (message marker)

    (setq marker (org-id-find id t))

    (if marker
        (progn
          (if other
              (pop-to-buffer (marker-buffer marker))
            (pop-to-buffer-same-window (marker-buffer marker)))
          
          (goto-char marker)
          (org-reveal t)
          (org-show-entry)
          (recenter)
          (unless (string= (org-id-get) id)
            (setq message (format "Could not go to node with id %s (narrowed ?)" id)))
          (setq message "Found headline"))
      (setq message (format "Did not find node with %s" id)))
    message))



;; Some helper functions
(defun oidx--get-save-maxref (&optional no-inc)
  "Get next reference, increment number and store it in index.
Optional argument NO-INC skips automatic increment on maxref."
  (let (ref-field)
    (with-current-buffer oidx--buffer
      (setq ref-field (org-entry-get oidx--point "max-ref"))
      (unless no-inc
        (setq ref-field (format oidx--ref-format (1+ (oidx--extract-refnum ref-field))))
        (org-entry-put oidx--point "max-ref" ref-field)))
    ref-field))


(defun oidx--line-in-canonical-form ()
  "Return current line in its canonical form."
  (org-trim (substring-no-properties (replace-regexp-in-string "\s +" " " (buffer-substring (line-beginning-position) (line-beginning-position 2))))))


(defun oidx--wrap (text)
  "Wrap TEXT at fill column."
  (with-temp-buffer
    (insert text)
    (fill-region (point-min) (point-max) nil t)
    (buffer-string)))



;; Index maintainance
(defun oidx--do-maintain ()
  "Choose among and perform some tasks to maintain index."
  (let (message-text choices choices-short check-what text)
    
    (setq choices (list "statistics : compute statistics about index table\n"
                        "verify     : verify ids by visiting their nodes\n"
                        "duplicates : check index for duplicate refs or ids\n"
                        "max        : compute and check maximum ref\n"
                        "clean      : remove obsolete property org-index-id\n"
                        "update     : update content of index lines having an id\n"))

    (setq choices-short (mapcar (lambda (x) (car (split-string x))) choices))
    (setq text (concat "These checks and fixes are available:\n" (apply 'concat choices) "Please choose: "))
    (setq check-what (intern (oidx--completing-read text choices-short (car choices-short))))

    (message nil)
    (oidx--enter-index-to-stay)
    
    (cond
     ((eq check-what 'verify)
      (setq message-text (oidx--verify-ids)))

     ((eq check-what 'statistics)
      (setq message-text (oidx--do-statistics)))

     ((eq check-what 'duplicates)
      (setq message-text (oidx--find-duplicates)))

     ((eq check-what 'clean)
      (let ((lines 0))
        (org-map-entries
         (lambda ()
           (when (org-entry-get (point) "org-index-ref")
             (cl-incf lines)
             (org-entry-delete (point) "org-index-ref")))
         nil 'agenda)
        (setq message-text (format "Removed property 'org-index-ref' from %d lines" lines))))
     
     ((eq check-what 'update)
      (if (y-or-n-p "Updating your index will overwrite certain columns with content from the associated heading and category.  If unsure, you may try this for a single, already existing line of your index by invoking `add'.  Are you SURE to proceed for ALL INDEX LINES ? ")
          (setq message-text (oidx--update-all-lines))
        (setq message-text "Canceled")))

     ((eq check-what 'max)
      (setq message-text (oidx--check-maximum))))
    message-text))


(defun oidx--find-duplicates ()
  "Find duplicate references or ids in index table."
  (let (ref-duplicates id-duplicates)

    (setq ref-duplicates (oidx--find-duplicates-helper 'ref))
    (setq id-duplicates (oidx--find-duplicates-helper 'id))
    (goto-char oidx--below-hline)
    (if (or ref-duplicates id-duplicates)
        (progn
          (pop-to-buffer-same-window
           (get-buffer-create "*org-index-duplicates*"))
          (erase-buffer)
          (insert "\n")
          (org-mode)
          (if ref-duplicates
              (progn
                (insert "- These references appear more than once in index table:\n")
                (mapc (lambda (x) (insert "  - " x "\n")) ref-duplicates)
                (insert "\n\n"))
            (insert "- No references appear more than once in index table.\n\n"))
          (if id-duplicates
              (progn
                (insert "- These ids appear more than once in index table:\n")
                (mapc (lambda (x) (insert "  - " x "\n")) id-duplicates))
            (insert "- No ids appear more than once in index table."))
          (insert "\n")

          "Some references or ids are duplicate")
      "No duplicate references or ids found")))


(defun oidx--find-duplicates-helper (column)
  "Helper for `oidx--find-duplicates': Go through table and count given COLUMN."
  (let (counts duplicates field found (clines 0) preporter)

    ;; go through table
    (goto-char oidx--below-hline)
    (setq preporter (make-progress-reporter (format "Collecting values for column %s from index-table..." column) 1 (oidx--count-lines-table)))
    (while (org-match-line org-table-line-regexp)

      (cl-incf clines)
      (progress-reporter-update preporter clines)

      ;; get column
      (setq field (oidx--get-or-set-field column))

      ;; and increment
      (setq found (assoc field counts))
      (if found
          (cl-incf (cdr found))
        (push (cons field 1) counts))

      (forward-line))

    (mapc (lambda (x) (if (and (> (cdr x) 1)
                               (car x))
                          (push (car x) duplicates))) counts)

    (progress-reporter-done preporter)
    
    duplicates))


(defun oidx--check-maximum ()
  "Check maximum reference."
  (let (ref-field ref-num (max 0) (max-prop) (clines 0) preporter)

    (goto-char oidx--below-hline)
    (setq preporter (make-progress-reporter "Finding maximum value in index-table..." 1 (oidx--count-lines-table)))
    (setq max-prop (oidx--extract-refnum (org-entry-get oidx--point "max-ref")))

    (while (org-match-line org-table-line-regexp)

      (cl-incf clines)
      (progress-reporter-update preporter clines)

      (setq ref-field (oidx--get-or-set-field 'ref))
      (setq ref-num (if ref-field (oidx--extract-refnum ref-field) 0))

      (setq max (max max ref-num))

      (forward-line))

    (progress-reporter-done preporter)
    
    (goto-char oidx--below-hline)
    
    (cond ((< max-prop max)
           (format "Maximum ref from property max-ref (%d) is smaller than maximum ref from table (%d); you should correct this" max-prop max))
          ((> max-prop max)
           (format  "Maximum ref from property max-ref (%d) is larger than maximum ref from table (%d); you may correct this" max-prop max))
          (t (format "Maximum ref from property max-ref and maximum ref from table are equal (%d); as expected" max-prop)))))


(defun oidx--verify-ids ()
  "Check, that ids really point to a node."
  
  (let ((marker t)
        (clines 0)
        preporter
        id)
    
    (goto-char oidx--below-hline)
    (setq preporter (make-progress-reporter "Verifying each id in index-table..." 1 (oidx--count-lines-table)))
    
    (while (and marker (org-match-line org-table-line-regexp))

      (cl-incf clines)
      (progress-reporter-update preporter clines)
      (when (setq id (oidx--get-or-set-field 'id))
        
        ;; check, if id is valid
        (setq marker (org-id-find id t)))

      (when marker (forward-line)))

    (progress-reporter-done preporter)
    
    (if marker
        (progn
          (goto-char oidx--below-hline)
          "All ids of index are valid")
      (org-table-goto-column 1)
      (format "The id %s of this row cannot be found; please fix (maybe run org-id-update-id-locations) and check again for rest of index" id))))


(defun oidx--count-lines-table ()
  "Count the number of lines in index table, assuming we are already below hline."
  (-
   (line-number-at-pos (org-table-end))
   (line-number-at-pos)))


(defun oidx--do-statistics ()
  "Compute statistics about index table."
  (let ((total-lines 0) (total-refs 0)
        ref ref-field (min most-positive-fixnum) (max 0) message)

    ;; go through table
    (goto-char oidx--below-hline)
    (while (org-match-line org-table-line-regexp)

      ;; get ref
      (setq ref-field (oidx--get-or-set-field 'ref))

      (when ref-field
        (string-match oidx--ref-regex ref-field)
        (setq ref (string-to-number (match-string 1 ref-field)))

        ;; record min and max
        (setq min (min min ref))
        (setq max (max max ref))

        (setq total-refs (1+ total-refs)))

      ;; count
      (setq total-lines (1+ total-lines))

      (forward-line))

    (setq message (format "%d Lines in index table. First reference is %s, last %s; %d of them are used (%d percent)"
                          total-lines
                          (format oidx--ref-format min)
                          (format oidx--ref-format max)
                          total-refs
                          (truncate (* 100 (/ (float total-refs) (1+ (- max min)))))))

    (goto-char oidx--below-hline)
    message))


(defun oidx--migrate-maxref-to-property ()
  "One-time migration: No property; need to go through whole table once to find max."
  (goto-char oidx--below-hline)
  (let ((max-ref-num 0)
        ref-field)

    (message "One-time migration to set index-property maxref...")

    ;; scan whole table
    (while (org-match-line org-table-line-regexp)
      (setq ref-field (oidx--get-or-set-field 'ref))
      (when ref-field
        (unless oidx--ref-head (oidx--get-decoration-from-ref-field ref-field))
        (setq max-ref-num (max max-ref-num (oidx--extract-refnum ref-field))))
      (forward-line))

    (unless (> max-ref-num 0)
      (oidx--report-index-error "No reference found in property max-ref and none in index"))
    (setq ref-field (format oidx--ref-format max-ref-num))
    (goto-char oidx--below-hline)
    ;; store maxref; this also moves the position of the rest of the index table
    (org-entry-put oidx--point "max-ref" ref-field)

    ;; refresh oidx--below-hline as a side-effect
    (oidx--go-below-hline)

    (message "Done.")
    ref-field))


(defun oidx--update-all-lines ()
  "Update all lines of index at once."

  (let ((lines 0)
        id kvs)
    
    (goto-char oidx--below-hline)
    (while (org-match-line org-table-line-regexp)
      
      ;; update single line
      (when (setq id (oidx--get-or-set-field 'id))
	(setq kvs (oidx--collect-values-for-add-update-remote id))
	(oidx--write-fields kvs)
	(cl-incf lines))
      (forward-line))

    (goto-char oidx--below-hline)
    (org-table-align)
    (format "Updated %d lines" lines)))


(defun oidx--delete-ref-from-heading (ref)
  "Delete given REF from current heading."
  (save-excursion
    (end-of-line)
    (let ((end (point)))
      (beginning-of-line)
      (when (search-forward ref end t)
        (delete-char (- (length ref)))
        (just-one-space)))))


(defun oidx--delete-any-ref-from-tags ()
  "Delete any reference from list of tags."
  (let (new-tags)
    (mapc (lambda (tag)
            (unless (or (string-match oidx--ref-regex tag)
			(string= tag ""))
              (push tag new-tags)))
          (org-get-tags))
    (org-set-tags new-tags)))



;; Creating a new Index
(defun oidx--create-missing-index (&rest reasons)
  "Create a new empty index table with detailed explanation.  Argument REASONS explains why."

  (oidx--ask-before-create-index "Cannot find index table: "
                                 "new permanent" "."
                                 reasons)
  (oidx--create-index))


(defun oidx--report-index-error (&rest reasons)
  "Report an error (explained by REASONS) with the existing index and offer to create a valid one to compare with."

  (when oidx--buffer
    (pop-to-buffer-same-window oidx--buffer)
    (goto-char oidx--below-hline)
    (org-reveal t))
  (oidx--ask-before-create-index "The existing index contains this error: "
                                 "temporary" ", to compare with."
                                 reasons)
  (oidx--create-index t t))


(defun oidx--ask-before-create-index (explanation type for-what reasons)
                                                  ; checkdoc-params: (explanation type for-what reasons)
  "Ask the user before creating an index or throw error.  Arguments specify bits of issued message."
  (let (reason prompt)

    (setq reason (apply 'format reasons))

    (setq prompt (concat explanation reason "\n"
                         "However, this assistant can help you to create a "
                         type " index with detailed comments" for-what "\n\n"
                         "Do you want to proceed ?"))

    (unless (let ((max-mini-window-height 1.0))
              (y-or-n-p prompt))
      (error (concat explanation reason)))))


(defun oidx--create-index (&optional temporary compare)
  "Create a new empty index table with detailed explanation.
Specify flag TEMPORARY for the or COMPARE it with the existing index."
  (let (buffer
        title
        firstref
        id)

    (if temporary
        (let ((file-name (concat temporary-file-directory "org-index-example-index.org"))
              (buffer-name "*org-index-example-index*"))
          (setq buffer (get-buffer-create buffer-name))
          (with-current-buffer buffer
	    (setq buffer-file-name file-name)
	    ;; clear buffer
	    (setq buffer-save-without-query t)
	    (auto-save-mode t) ; disables mode
	    (ignore-errors (delete-file buffer-auto-save-file-name))
	    (erase-buffer)
            (org-mode)))
      
      (setq buffer (get-buffer (read-buffer "Please choose a buffer, where the new node for the index table will be appended. Buffer: "))))
    (setq title (read-from-minibuffer "Please enter the title of the index node (leave empty for default 'index'): "))
    (if (string= title "") (setq title "index"))
    
    (while (progn
             (setq firstref (read-from-minibuffer "Please enter your first reference-number. This is an integer number preceeded by some and optionally followed by some non-numeric chars; e.g. 'R1', '-1-' or '#1#' (and your initial number does not need to be '1'). The format of your reference-numbers only needs to make sense for yourself, so that you can spot it easily in your texts or write it on a piece of paper; it should however not already appear frequently within your existing notes, to avoid too many false hits when searching.\n\nPlease choose (leave empty for default 'R1'): "))
             (if (string= firstref "") (setq firstref "R1"))
             (let (desc)
               (when (string-match "[[:blank:]]" firstref)
                 (setq desc "Contains whitespace"))
               (when (string-match "[[:cntrl:]]" firstref)
                 (setq desc "Contains control characters"))
               (unless (string-match "^[^0-9]+[0-9]+[^0-9]*$" firstref)
                 ;; firstref not okay, report details
                 (setq desc
                       (cond ((string= firstref "") "is empty")
                             ((not (string-match "^[^0-9]+" firstref)) "starts with a digit")
                             ((not (string-match "^[^0-9]+[0-9]+" firstref)) "does not contain a number")
                             ((not (string-match "^[^0-9]+[0-9]+[^0-9]*$" firstref)) "contains more than one sequence of digits"))))
               (if desc
                   (progn
                     (read-from-minibuffer (format "Your input '%s' does not meet the requirements because it %s.\nPlease hit RET and try again: " firstref desc))
                     t)
                 nil))))

    (with-current-buffer buffer
      (goto-char (point-max))
      (insert (format "\n* %s %s\n" firstref title))
      (org-entry-put (point) "max-ref" firstref)
      (unless oidx--recording-screencast
	(if temporary
            (insert "
  Below you find your temporary index table, which WILL NOT LAST LONGER
  THAN YOUR CURRENT EMACS SESSION; please use it only for evaluation.
")
          (insert "
  Below you find your initial index table, which will grow over time.
"))
	(insert "  You may start using it by adding some lines. Just
  move to another heading within org, invoke `org-index' and
  choose the command 'add'.  After adding a few nodes, try the
  command 'occur' to search among them.

  For more details. invoke org-index command 'help', or
  read the same in the help of `org-index'.

  This node needs not be a top level node; its name is completely
  at your choice; it is found through its ID only.
")
	(unless temporary
          (insert "
  Remark: These lines of explanation can be removed at any time.
")))

      (setq id (org-id-get-create))
      (insert (format "

  | ref | category | keywords | tags | count | level | last-accessed | created | id  | yank |
  |     |          |          |      |       |       |               |         | <4> | <4>  |
  |-----+----------+----------+------+-------+-------+---------------+---------+-----+------|
  | %s  |          | %s       |      |       |       |               | %s      | %s  |      |

"
                      firstref
                      title
                      (with-temp-buffer (org-insert-time-stamp nil nil t))
                      id))

      ;; make sure, that node can be found
      (org-id-add-location id (buffer-file-name))

      (while (not (org-match-line org-table-line-regexp)) (forward-line -1))
      (unless buffer-read-only (org-table-align))
      (while (not (org-at-heading-p)) (forward-line -1))

      ;; read back some info about new index
      (let ((org-index-id id))
	(oidx--verify-id)
	(oidx--get-decoration-from-ref-field firstref))

      ;; remember at least for this session
      (setq org-index-id id)

      ;; present results to user
      (if temporary
          (progn
            ;; Present existing and temporary index together
            (when compare
              (pop-to-buffer-same-window oidx--buffer)
              (goto-char oidx--point)
              (oidx--unfold-buffer)
              (delete-other-windows)
              (select-window (split-window-vertically)))
            ;; show new index
            (pop-to-buffer-same-window buffer)
	    (set-buffer-modified-p nil)
            (org-id-goto id)
            (oidx--unfold-buffer)
            (if compare
                (progn
                  (message "Please compare your existing index (upper window) and a temporary new one (lower window) to fix your index")
                  (throw 'new-index nil))
              (message "This is your new temporary index, use command add to populate, occur to search.")))
        (progn
          ;; Show the new index
          (pop-to-buffer-same-window buffer)
          (delete-other-windows)
          (org-id-goto id)
          (oidx--unfold-buffer)
          (if (y-or-n-p "This is your new index table.  It is already set for this Emacs session, so you may try it out.  Do you want to save it's id to make it available in future Emacs sessions too ? ")
              (progn
                (customize-save-variable 'org-index-id id)
                (message "Saved org-index-id '%s' to %s." id (or custom-file user-init-file)))
            (let (sq)
              (setq sq (format "(setq org-index-id \"%s\")" id))
              (kill-new sq)
              (message "Did not make the id of this new index permanent; you may want to put\n\n   %s\n\ninto your own initialization; it is copied already, just yank it." sq)))

          (when (not org-index-key)
            (if (y-or-n-p "The central function `org-index' can be bound to a global key.  Do you want to make such a binding for now ? ")
	        (let* ((free-prefix-keys (remove nil (mapcar (lambda (c) (if (key-binding (kbd (format "C-c %c" c))) nil c)) (number-sequence ?a ?z))))
		       (prompt (concat "Please type your desired key sequence. For example, with the user-prefix key C-c, these keys are available: "
				       (mapconcat 'char-to-string free-prefix-keys ",")
				       ". But of course, you may choose any free key-sequence you like (C-g to cancel) -- "))
		       (preprompt "")
		       key)
	          (while (progn
		           (setq key (read-key-sequence (concat preprompt prompt)))
		           (setq preprompt (format "Key '%s' is already taken; please choose another one. " (kbd key)))
		           (and (key-binding key)
			        (not (string= (kbd key) (kbd "^g"))))))
	          (if (string= (kbd key) (kbd "^g"))
                      (message "Aborted")
		    (global-set-key key 'org-index)
		    (let ((saved ""))
		      (when (y-or-n-p "Do you want to save this for future Emacs sessions ? ")
		        (customize-save-variable 'org-index-key key)
		        (setq saved "and saved "))
		      (message "Set %sorg-index-key '%s' to %s." saved (kbd key) (or custom-file user-init-file)))))
	      (message "Did not set org-index-key; however this can be done any time with `org-customize'.")))
          (throw 'new-index nil))))))



;; Variable and Functions for occur; most of them share state
;; between the functions of the occur-family of functions
(defvar oidx--o-help-text nil "Text for help in occur buffer; cons with text short and long.")
(defvar oidx--o-help-overlay nil "Overlay for help in occur buffer.")
(defvar oidx--o-stack nil "Stack with list of matching lines; each frame of stack has one complete set of lines for each char typed in search.")
(defvar oidx--o-win-config nil "Window configuration stored away during occur.")
(defvar oidx--o-last-visible-initial nil "Initial point of last visibility.")
(defconst oidx--o-buffer-name "*org-index-occur*" "Name of occur buffer.")
(defvar oidx--o-search-text nil "Description of text to search for.")
(defconst oidx--o-more-lines-text "\n(more lines omitted)\n" "Note stating, that not all lines are display.")
(defvar oidx--o-assert-result nil "Set to true to verify result of occur (incremental result compare with single-pass result.")
(defvar oidx--o-start-of-lines nil "Start of table lines within result buffer.")
(defvar oidx--o-end-of-lines nil "End of table lines within result buffer.")
(defvar oidx--o-lines-collected 0 "Number of lines collected in occur buffer; helpful for tests.")


(defun oidx--do-occur ()
  "Perform command occur.
Optional argument ARG, when given does not limit number of lines shown."
  (let ((word "") ; last word to search for growing and shrinking on keystrokes
        (prompt "Search for: ")
        (lines-wanted (if (= org-index-occur-max-lines 0)
                          (window-body-height)
                        (min org-index-occur-max-lines (window-body-height))))
        words              ; list words that should match
        done               ; true, if loop is done
        in-c-backspace     ; true, while processing C-backspace
        initial-frame      ; Frame when starting occur
        key                ; input from user in various forms
        key-sequence
        key-sequence-raw)


    (setq initial-frame (selected-frame))
    (setq oidx--o-win-config (current-window-configuration))
    (pop-to-buffer-same-window (get-buffer-create oidx--o-buffer-name))
    (setq buffer-read-only nil)

    (oidx--o-prepare-buffer)
    (setq oidx--o-stack '())
    (push (oidx--o-find-matching-lines
           (cons word words) oidx--below-hline lines-wanted)
          oidx--o-stack)
    (oidx--o-show (car oidx--o-stack))
    
    ;; main loop
    (while (not done)
      
      (if in-c-backspace
          (setq key "<backspace>")
        
        (setq oidx--o-search-text (mapconcat 'identity (reverse (cons word words)) ","))
        
        ;; read key, if selected frame has not changed
        (if (eq (selected-frame) initial-frame)
            (progn
              (setq key-sequence
                    (let ((echo-keystrokes 0)
                          (full-prompt (format "%s%s"
                                               prompt
                                               oidx--o-search-text)))
                      (read-key-sequence full-prompt nil nil t t)))
              (setq key (key-description key-sequence))
              (setq key-sequence-raw (this-single-command-raw-keys)))
          (setq done t)
          (setq key-sequence nil)
          (setq key nil)
          (setq key-sequence-raw nil)))
      

      (cond

       ((member key (list "<C-backspace>" "M-DEL"))
        (setq in-c-backspace t))

       ;; erase last char
       ((member key (list "<backspace>" "DEL"))

        ;; if only one char left, c-backspace should end
        (if (= (length word) 0)
            (setq in-c-backspace nil))

        ;; previous frame
        (unless (= (length oidx--o-stack) 1)
          (pop oidx--o-stack))
        ;; get word and words from frame
        (-setq (word . words) (plist-get (car oidx--o-stack) :words))
        ;; display
        (oidx--o-show (car oidx--o-stack)))


       ;; space or comma: enter an additional search word
       ((member key (list "SPC" ","))
        ;; push current word and clear, no need to change display
        (unless (string= word "")
          (push word words)
          (setq word "")))
       

       ;; question mark: toggle display of headlines and help
       ((string= key "?")
        (setq oidx--o-help-text (cons (cdr oidx--o-help-text)
                                          (car oidx--o-help-text))) ; swap
        (overlay-put oidx--o-help-overlay 'display (car oidx--o-help-text)))


       ;; any printable char: add to current search word
       ((and (= (length key) 1)
             (aref printable-chars (elt key 0)))
        
        ;; append key to word
        (setq word (concat word key))
        
        (goto-char oidx--o-start-of-lines)
        ;; remove lines no longer matching
        (push (oidx--o-match-and-merge lines-wanted (cons word words)) oidx--o-stack)
        (oidx--o-show (car oidx--o-stack)))

       ;; anything else terminates input loop
       (t (setq done t))))

    ;; put back input event, that caused the loop to end
    (if (string= key "<escape>")
        (progn (if oidx--o-win-config (set-window-configuration oidx--o-win-config))
               (keyboard-quit))
      (unless (member key (list "SPCq" "C-g"))
        (setq unread-command-events (listify-key-sequence key-sequence-raw)))
      (message key))
    
    (oidx--o-make-permanent lines-wanted (car oidx--o-stack))

    ;; used in tests
    (if oidx--o-assert-result (oidx--o-do-assert-result (cons word words) lines-wanted))
    
    (oidx--o-install-keyboard-shortcuts)))


(defun oidx--o-prepare-buffer ()
  "Prepare result-buffer."

  ;; create result buffer
  (erase-buffer)
  (insert oidx--headings)
  
  ;; initialize help text
  (setq oidx--o-help-text
        (cons
         (concat
          (propertize "Incremental occur" 'face 'org-todo)
         (propertize  "; ? toggles help and headlines.\n" 'face 'org-agenda-dimmed-todo-face))
         (concat
          (propertize
           (oidx--wrap "Normal keys add to search word; <space> starts additional word; <backspace> erases last char, <M-backspace> last word, `C-g', all other keys end the search; they are kept and reissued in the final display of occur-results, where they can trigger various actions; see the help there (e.g. <return> as jump to heading).\n")
           'face 'org-agenda-dimmed-todo-face)
          oidx--headings)))

  ;; overlay for help text
  (setq oidx--o-help-overlay (make-overlay (point-min) (point-max)))
  (overlay-put oidx--o-help-overlay 'display (car oidx--o-help-text))
  (toggle-truncate-lines 1)
  (setq oidx--o-start-of-lines (point))
  (setq oidx--o-end-of-lines (point)))


(defun oidx--o-match-and-merge (lines-wanted words)
  "Create new match frame with lines matching WORDS from top and the rest from table; LINES-WANTED in total."
  (let (nmframe omframe oolines oolbps oline olines olbp olbps (ocount 0))
    (setq omframe (car oidx--o-stack))

    ;; get lines from old frame, that still match
    (setq oolines (reverse (plist-get omframe :lines)))
    (setq oolbps (reverse (plist-get omframe :lbps)))
    (while oolines
      (setq olbp (pop oolbps))
      (setq oline (oidx--o-test-words-and-fontify words (pop oolines)))
      (when oline
        (cl-incf ocount)
        (push oline olines)
        (push olbp olbps)))
    ;; get new stretch of lines
    (setq nmframe (oidx--o-find-matching-lines
                   words
                   (or (plist-get omframe :end)
                       oidx--below-hline)
                   (- lines-wanted ocount)))
    (oidx--plist-put nmframe :lines (append olines (plist-get nmframe :lines)))
    (oidx--plist-put nmframe :lbps (append olbps (plist-get nmframe :lbps)))
    (oidx--plist-put nmframe :count (+ ocount (plist-get nmframe :count)))
    nmframe))


(defun oidx--o-find-matching-lines (words start wanted)
  "Find WANTED lines from index table, that match WORDS; start at START.
Returns nil or plist with result"
  (let ((found 0)
        line lines lbps lbp lbp2)
    (with-current-buffer oidx--buffer
      (goto-char start)
      (while (and (org-match-line org-table-line-regexp)
                  (< found wanted))
        (when (setq
               lbp (line-beginning-position)
               lbp2 (line-beginning-position 2)
               line (oidx--o-test-words-and-fontify words (buffer-substring lbp lbp2)))
          (push line lines)
          (push lbp lbps)
          (cl-incf found))
        (forward-line)))
    (setq lbp2 (or lbp2 start))
    (list :end lbp2 :count found :lines (reverse lines) :words words :lbps (reverse lbps))))


(defun oidx--o-test-words-and-fontify (words line)
  "Test current LINE for match against WORDS and if yes, return it with hightlights."
  (let (pos dcline)

    ;; cut off after tags, so that id-field does not give spurious matches
    (setq pos 0)
    (dotimes (_ (+ org-index-occur-columns 1))
      (setq pos (+ 1 (cl-search "|" line :start2 pos))))
    (setq line (substring line 0 pos))
    (setq dcline (downcase line))
    (put-text-property 0 pos 'face 'org-table line)

    (catch 'not-found
      (dolist (word words)
        (if (setq pos (cl-search word (if (s-lowercase-p word) dcline line)))
            (put-text-property pos (+ pos (length word)) 'face 'isearch line)
          (throw 'not-found nil)))
      line)))


(defun oidx--o-show (frame)
  "Show top of `oidx--o-stack'.
Argument FRAME gives match-frame to show."
  (with-current-buffer oidx--o-buffer-name
    (goto-char oidx--o-start-of-lines)
    (delete-region oidx--o-start-of-lines oidx--o-end-of-lines)
    (mapc (lambda (x) (insert x "\n")) (plist-get frame :lines))
    (setq oidx--o-end-of-lines (point))
    (goto-char oidx--o-start-of-lines)))


(defun oidx--o-do-assert-result (words lines-wanted)
  "Assert result for tests; find LINES-WANTED matching WORDS."
  ;; sp = single-pass, mp = multi-pass
  (let* ((sp-frame (oidx--o-find-matching-lines
                    words oidx--below-hline lines-wanted))
         (sp-lines (plist-get sp-frame :lines))
         (mp-frame (car oidx--o-stack))
         (mp-lines (plist-get mp-frame :lines)))
        (while (or sp-lines mp-lines)
          (unless (string= (pop sp-lines) (pop mp-lines))
            (error "Assertion failed: single-pass result does not equal multi-pass result")))
	(when sp-lines
          (unless (apply #'< (plist-get sp-frame :lbps))
            (error "Assertion failed: single-pass result is not sorted")))))


(defun oidx--o-make-permanent (lines-wanted frame)
  "Make permanent copy of current view into index.
Argument LINES-WANTED specifies number of lines to display of match-frame FRAME."

  (let (line lines lines-collected header-lines)

    (with-current-buffer oidx--o-buffer-name
      (erase-buffer)
      (insert oidx--headings))
    (setq header-lines (line-number-at-pos))
    (setq oidx--o-start-of-lines (point))

    ;; For each line go into index buffer and get the complete line (including e.g. the id)
    (with-current-buffer oidx--buffer
      (save-excursion
        (mapc (lambda (p)
                (goto-char p)
                (setq line (buffer-substring (line-beginning-position) (line-end-position)))
                (put-text-property 0 (length line) 'org-index-lbp p line)
                (push line lines))
              (plist-get frame :lbps))))
    (mapc (lambda (l) (insert l "\n")) (reverse lines))
    (setq oidx--o-end-of-lines (point))
    
    (setq lines-collected (plist-get frame :count))
    (setq oidx--o-lines-collected lines-collected)
    (fundamental-mode)
    (setq truncate-lines t)

    ;; prepare help text
    (goto-char (point-min))
    (forward-line (1- header-lines))
    (setq oidx--o-help-overlay (make-overlay (point-min) (point)))
    (setq oidx--o-help-text
          (cons
           (oidx--wrap
            (propertize "Search is done;    ? toggles help and headlines.\n" 'face 'org-agenda-dimmed-todo-face))
           (concat
            (oidx--wrap
             (propertize
              (format
               (concat "Search is done."
                       (if (< lines-collected lines-wanted)
                           " Showing all %d matches for "
                         " Showing one window of matches for ")
                       "\"" oidx--o-search-text
                       "\". <return> jumps to node of line under cursor, <tab> in other window; `i' jumps to matching line in index, `h' to head of index; `+' increments count, <escape> or `q' aborts, `c' clocks in, `e' edits, `d' shows details, `l' offers links from node to visit."
                       "\n")
               lines-collected)
              'face 'org-agenda-dimmed-todo-face))
            oidx--headings)))
    
    (overlay-put oidx--o-help-overlay 'display (car oidx--o-help-text))

    ;; insert tail text late to avoid highlighting it
    (goto-char (point-max))
    (if (= lines-collected lines-wanted)
        (insert oidx--o-more-lines-text))
    (goto-char oidx--o-start-of-lines)
    
    (setq buffer-read-only t)))


(defun oidx--o-install-keyboard-shortcuts ()
  "Install keyboard shortcuts for result of occur buffer."

  (let (keymap)
    (setq keymap (make-sparse-keymap))
    (set-keymap-parent keymap org-mode-map)

    (dolist (keys-command
             '((("<return>" "RET") . oidx--o-action-goto-node)
               (("<tab>") . oidx--o-action-goto-node-other)
               (("i" "M-i") . oidx--o-action-goto-line-in-index)
               (("h" "M-h") . oidx--o-action-head-of-index)
               (("+" "M-+") . oidx--o-action-increment-count)
               (("<escape>" "q") . oidx--o-action-quit)
               (("c" "M-c") . oidx--o-action-clock-in)
               (("e" "M-e") . oidx--o-action-edit)
               (("d" "M-d") . oidx--o-action-details)
               (("l" "M-l") . oidx--o-action-offer-links)
               (("?" "M-?") . oidx--o-action-toggle-help)))
      (dolist  (key (car keys-command)) (define-key keymap (kbd key) (cdr keys-command))))

    (use-local-map keymap)))


(defun oidx--o-action-offer-links ()
  "Offer list of links from node under cursor."
  (interactive)
  (let* ((id (oidx--get-or-set-field 'id))
         (marker (org-id-find id t))
         count)
    (oidx--o-action-prepare)
    (if marker
        (let (url)
          (setq url (car (org-offer-links-in-entry (marker-buffer marker) marker)))
          (if (string= (substring url 0 4) "http")
              (progn
                (setq count (oidx--update-line (get-text-property (point) 'org-index-lbp)))
                (let ((inhibit-read-only t))
                  (oidx--get-or-set-field 'count (number-to-string count)))
                (browse-url url))
            (message "No link in node"))
          (move-marker marker nil))
      (message "Did not find node with id '%s'" id))))


(defun oidx--o-action-increment-count ()
  "Increment count of line under cursor and in index."
  (interactive)
  (let (count)
    (oidx--o-action-prepare)
    ;; increment in index
    (setq count (oidx--update-line (get-text-property (point) 'org-index-lbp)))
    ;; increment in this buffer
    (let ((inhibit-read-only t))
      (oidx--get-or-set-field 'count (number-to-string count)))
    (message "Incremented count to %d" count)))


(defun oidx--o-action-clock-in ()
  "Clock into node of line under cursor."
  (interactive)
  (oidx--o-action-prepare)
  (org-id-goto (oidx--get-or-set-field 'id))
  (org-with-limited-levels (org-clock-in))
  (if oidx--o-win-config (set-window-configuration oidx--o-win-config))
  (message "Clocked into node and returned to initial position."))


(defun oidx--o-action-head-of-index ()
  "Go to head of index."
  (interactive)
  (let ((pos (get-text-property (point) 'org-index-lbp)))
    (oidx--o-action-prepare)
    (oidx--o-test-stale pos)
    (pop-to-buffer oidx--buffer)
    (goto-char pos)
    (org-reveal t)
    (beginning-of-line)))


(defun oidx--o-action-goto-line-in-index ()
  "Go to matching line in index."
  (interactive)
  (let ((id (oidx--get-or-set-field 'id)))
    (oidx--o-action-prepare)
    (switch-to-buffer oidx--buffer)
    (oidx--go 'id id)
    (beginning-of-line))
  (message "Jumped to line in index."))


(defun oidx--o-action-goto-node-other ()
  "Find heading with ref or id in other window; or copy yank column."
  (interactive)
  (oidx--o-action-prepare t)
  (oidx--o-action-goto-node t))


(defun oidx--o-action-goto-node (&optional other)
  "Find heading with ref or id; if OTHER, in other window; or copy yank column."
  (interactive)
  (if (org-match-line org-table-line-regexp)
      (let ((id (oidx--get-or-set-field 'id))
            (ref (oidx--get-or-set-field 'ref))
            (yank (oidx--get-or-set-field 'yank)))
        (oidx--o-action-prepare t)
	(cond
         (id
	  (oidx--update-line (get-text-property (point) 'org-index-lbp))
          (oidx--find-id id other)) ; does its own message
         (ref
	  (oidx--update-line (get-text-property (point) 'org-index-lbp))
          (org-mark-ring-goto)
          (message "Found reference %s (no node is associated)" ref))
         (yank
          (oidx--update-line (get-text-property (point) 'org-index-lbp))
          (setq yank (replace-regexp-in-string (regexp-quote "\\vert") "|" yank nil 'literal))
          (kill-new yank)
          (org-mark-ring-goto)
          (if (and (>= (length yank) 4) (string= (substring yank 0 4) "http"))
              (progn
                (browse-url yank)
                (message "Opened '%s' in browser (and copied it too)" yank))
            (message "Copied '%s' (no node is associated)" yank)))
	 (t
          (error "Cannot act on this line: It contains neither id, nor reference, nor text to yank"))))))


(defun oidx--o-action-quit ()
  "Quit this occur and return to initial state."
  (interactive)
  (oidx--o-action-prepare)
  (if oidx--o-win-config (set-window-configuration oidx--o-win-config))
  (message "Back to initial state."))


(defun oidx--o-action-edit ()
  "Edit index line under cursor."
  (interactive)
  (oidx--o-action-prepare t)
  (message (oidx--do-edit)))


(defun oidx--o-action-details ()
  "Show details for index line under cursor."
  (interactive)
  (-let (((cols-vals . maxlen) (oidx--content-of-current-line)))
    (oidx--o-action-prepare)
    (display-buffer (get-buffer-create oidx--details-buffer-name) '((display-buffer-at-bottom)))
    (with-current-buffer oidx--details-buffer-name
      (let ((inhibit-read-only t))
        (erase-buffer)
        (dolist (col-val cols-vals)
          (insert (format (format "%%%ds: %%s\n" maxlen)
                          (symbol-name (car col-val))
                          (or (cdr col-val) ""))))
        (delete-char -1)
        (goto-char 0)
        (fit-window-to-buffer (get-buffer-window))
        (setq buffer-read-only t))))
  (message "Details for current index line."))


(defun oidx--o-action-toggle-help ()
  "Toggle display of usage and column headers."
  (interactive)
  (oidx--o-action-prepare)
  (oidx--refresh-parse-table)
  ; swap short and long help
  (setq-local oidx--o-help-text (cons (cdr oidx--o-help-text) (car oidx--o-help-text)))
  (overlay-put oidx--o-help-overlay 'display (car oidx--o-help-text)))


(defun oidx--o-action-prepare (&optional kill-details)
  "Common preparation for all occur actions.
KILL-DETAILS removes respective window."
  (if kill-details
      (ignore-errors (delete-windows-on oidx--details-buffer-name)))
  (oidx--retrieve-context-on-invoke)
  (oidx--refresh-parse-table))


(defun oidx--o-test-stale (pos)
  "Test, if current line in occur buffer has become stale at POS."
  (let (here there)
    (oidx--refresh-parse-table)
    (setq here (oidx--line-in-canonical-form))
    (with-current-buffer oidx--buffer
      (goto-char pos)
      (setq there (oidx--line-in-canonical-form)))
    (unless (string= here there)
      (error "Occur buffer has become stale; please repeat search"))))


(defun oidx--copy-visible (beg end)
  "Copy the visible parts of the region between BEG and END without adding it to `kill-ring'; copy of `org-copy-visible'."
  (let (snippets s)
    (save-excursion
      (save-restriction
	(narrow-to-region beg end)
	(setq s (goto-char (point-min)))
	(while (not (= (point) (point-max)))
	  (goto-char (org-find-invisible))
	  (push (buffer-substring s (point)) snippets)
	  (setq s (goto-char (org-find-visible))))))
    (apply 'concat (nreverse snippets))))


(provide 'org-index)

;; Local Variables:
;; fill-column: 75
;; comment-column: 50
;; End:

;;; org-index.el ends here

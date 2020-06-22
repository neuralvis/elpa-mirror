;;; neuron-mode.el --- Major mode for editing zettelkasten notes using neuron -*- lexical-binding: t; -*-

;;
;; Copyright (C) 2020 felko
;;
;; Author: felko <http://github/felko>
;; Homepage: https://github.com/felko/neuron-mode
;; Keywords: outlines
;; Package-Commit: 17a82a22c727da8afd5cd803e811bd929b8314d1
;; Package-Version: 20200622.242
;; Package-X-Original-Version: 0.1
;; Package-Requires: ((emacs "26.3") (f "0.20.0") (counsel "0.13.0") (markdown-mode "2.3"))
;;
;; This file is not part of GNU Emacs.

;;; License: GNU General Public License v3.0
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Editing zettelkasten notes using the neuron zettelkasten manager
;; https://neuron.zettel.page/

;;; Code:

(require 'counsel)
(require 'f)
(require 'json)
(require 'markdown-mode)
(require 'subr-x)
(require 'seq)
(require 'thingatpt)
(require 'url-parse)
(require 'url-util)
(require 'simple)

(defgroup neuron nil
  "A major mode for editing Zettelkasten notes with neuron."
  :prefix "neuron-"
  :link '(url-link "https://github.com/felko/neuron-mode")
  :group 'markdown)

(defcustom neuron-default-zettelkasten-directory (expand-file-name "~/zettelkasten")
  "The location of the default Zettelkasten directory."
  :group 'neuron
  :type  'string
  :safe  'f-directory?)

(defcustom neuron-generate-on-save nil
  "Whether to generate the necessary zettels when a buffer is saved."
  :group 'neuron
  :type  'boolean
  :safe  'booleanp)

;; TODO deprecate, replace with neuron-use-wiki-links
(defcustom neuron-use-short-links t
  "Whether to use <ID> or [ID](z:/) syntax when inserting zettel links."
  :group 'neuron
  :type  'boolean
  :safe  'booleanp)

(defcustom neuron-id-format 'hash
  "The ID format in which new zettels are created.
'hash will make neuron generate a hexadecimal 8-digit UUID.
'date will generate an ID that is baed on the current date,
    as well as an integer to distinguish zettels that were created the same day,
'prompt will ask for the user to specify the ID every time a zettel is created."
  :group 'neuron
  :type  'symbol)

(defcustom neuron-daily-note-id-format "%Y-%m-%d"
  "Format of daily note IDs.
When creating a daily note with `neuron-open-daily-notes' this format
string will be run through `format-time-string' to create a zettel
ID."
  :group 'neuron
  :type  'string)

(defcustom neuron-daily-note-title-format "%x"
  "Format of daily note titles.
When creating a daily note with `neuron-open-daily-notes' this format
string will be run through `format-time-string' to create the title
of the zettel."
  :group 'neuron
  :type  'string)

(defcustom neuron-daily-note-tags (list "journal/daily")
  "List of tags to add to a newly created daily notes file."
  :group 'neuron
  :type  '(repeat string))

(defgroup neuron-faces nil
  "Faces used in neuron-mode."
  :group 'neuron
  :group 'faces)

(defface neuron-link-face
  '((((class color) (min-colors 88) (background dark)) :foreground "orange1")
    (((class color) (min-colors 88) (background light)) :foreground "orange3")
    (t :inherit link))
  "Face for zettel IDs in zettels and ivy-read prompts"
  :group 'neuron-faces)

(defface neuron-invalid-zettel-id-face
  '((t :inherit error))
  "Face for zettel IDs in zettels and ivy-read prompts"
  :group 'neuron-faces)

(defface neuron-zettel-tag-face
  '((t :inherit shadow))
  "Face for zettel IDs in zettels and ivy-read prompts"
  :group 'neuron-faces)

(defface neuron-title-overlay-face
  '((((class color) (min-colors 88) (background dark)) :foreground "MistyRose2")
    (((class color) (min-colors 88) (background light)) :foreground "LightSlateGrey")
    (((class color) :foreground "grey"))
    (t :inherit italic))
  "Face for title overlays displayed next to short links."
  :group 'neuron-faces)

(defface neuron-invalid-link-face
  '((t :inherit error))
  "Face for the 'Unknown' label dislayed next to short links with unknown IDs."
  :group 'neuron-faces)

(defface neuron-link-mouse-face
  '((t :inherit highlight))
  "Face displayed when hovering a zettel short link.")

(defvar neuron-make-title
  (lambda (selection)
    (with-temp-buffer
      (insert selection)
      (goto-char (point-min))
      (call-interactively #'capitalize-dwim)
      (buffer-string)))
  "Postprocess the selected text to make the title of zettels.
This function is called by `neuron-create-zettel-from-selection' to
generate a title for the new zettel, it passes the selected text as
an argument.")

(defvar neuron--current-zettelkasten nil
  "The currently active zettelkasten.
Since it can be invalid sometimes, it should only be used in internal
functions when we know that the zettelkasten was just updated.")

(defun neuron--detect-zettelkasten (pwd)
  "Navigate upwards from PWD until a neuron.dhall file is found.
When no neuron.dhall file was found, return nil."
  (let ((is-zk (lambda (dir) (f-exists? (f-join "/" dir "neuron.dhall")))))
    (f-traverse-upwards is-zk pwd)))

(defun neuron--get-zettelkasten (&optional pwd)
  "Return the location of the current zettelkasten.
Assuming the current working directory is PWD, first try to
detect the zettelkasten automatically by traversing the hierarchy
upwards until a neuron.dhall file is found. When no neuron.dhall
file is found, return `neuron-default-zettelkasten-directory'.
Lastly, if the default zettelkasten location doesn't point to
an actual directory, return nil."
  (interactive "P")
  (or
   (neuron--detect-zettelkasten pwd)
   (let ((root neuron-default-zettelkasten-directory))
     (and (f-exists? root) (f-directory? root) neuron-default-zettelkasten-directory))))

(defun neuron--update-current-zettelkasten (root)
  "Update `neuron--current-zettelkasten' with the new value ROOT.
Refresh the zettel cache if the value has changed."
  (let ((old-root neuron--current-zettelkasten))
    (setq neuron--current-zettelkasten root)
    (when (or
           ;; When the current zettelkasten has changed since last time
           (and neuron--current-zettelkasten (not (equal old-root root)))
           ;; First time that a neuron-mode function was called:
           (not neuron--current-zettelkasten))
      (neuron--rebuild-cache))
    neuron--current-zettelkasten))

(defun neuron-zettelkasten (&optional pwd)
  "The location of the current Zettelkasten directory.
First, it tries to detect automatically the current zettelkasten assuming
the working directory is PWD, by traversing upwards in the directory
hierarchy until a neuron.dhall file is met, and returns
`neuron-default-zettelkasten-directory' when no neuron.dhall was found.
If in turn `neuron-default-zettelkasten-directory' doesn't point to an
existing directory, throw an user error."
  (neuron--update-current-zettelkasten
   (or
    (call-interactively 'neuron--get-zettelkasten pwd)
    (let ((default neuron-default-zettelkasten-directory))
      (and
       (when (not (f-exists? default))
         (user-error "Invalid zettelkasten: %s does not exist" default))
       (when (not (f-directory? default))
         (user-error "Invalid zettelkasten: %s is not a directory" default)))))))

;; Convenient alias when the result of `neuron-zettelkasten' isn't assigned
(defun neuron-check-if-zettelkasten-exists ()
  "Check whether the active zettelkasten exists."
  (neuron-zettelkasten))

(defun neuron--make-command (cmd &rest args)
  "Construct a neuron command CMD with argument ARGS.
If the current zettelkasten is ill-defined, return nil."
  (mapconcat
   #'shell-quote-argument
   (append (list "neuron" "--zettelkasten-dir" neuron--current-zettelkasten cmd) args) " "))

(defun neuron--make-query-uri-command (uri)
  "Construct a neuron query command that queries the zettelkasten from URI.
URI is expected to have a zquery:/ scheme."
  (neuron--make-command "query" "--uri" uri))

(defun neuron--run-command (cmd)
  "Run the CMD neuron command with arguments ARGS in the current zettekasten.
The command is executed as a synchronous process and the standard output is
returned as a string."
  (let* ((result    (with-temp-buffer
                      (list (call-process-shell-command cmd nil t) (buffer-string))))
         (exit-code (nth 0 result))
         (output    (nth 1 result)))
    (if (equal exit-code 0)
        (string-trim-right output)
      (and (user-error "Command \"%s\" exited with code %d: %s" cmd exit-code output)
           nil))))

(defun neuron--read-query-result (output)
  "Parse the OUTPUT of a query command in JSON.
Extract only the result itself, so the query type is lost."
  (map-elt (json-read-from-string output) 'result))

(defun neuron--query-url-command (uri)
  "Run a neuron query from a zquery URI."
  (neuron--read-query-result (neuron--run-command (neuron--make-query-uri-command uri))))

(defun neuron--run-rib-process (&rest args)
  "Run an asynchronous neuron process spawned by the rib command with arguments ARGS."
  (start-process-shell-command "rib" "*rib*" (apply #'neuron--make-command "rib" args)))

(defun neuron--run-rib-compile (&rest args)
  "Run an synchronous neuron command spawned by the rib command with arguments ARGS."
  (compile (apply #'neuron--make-command "rib" args)))

(defvar neuron--zettel-cache nil
  "Map containing all zettels indexed by their ID.")

(defun neuron--rebuild-cache ()
  "Rebuild the zettel cache with the current zettelkasten."
  (let ((zettels (neuron--query-url-command "z:zettels"))
        (assoc-id (lambda (zettel) (cons (intern (map-elt zettel 'id)) zettel))))
    (setq neuron--zettel-cache (mapcar assoc-id zettels))))

(defun neuron--list-buffers ()
  "Return the list of all open buffers in which neuron-mode is active."
  (let ((is-neuron-buffer (lambda (buffer) (with-current-buffer buffer (eq major-mode 'neuron-mode)))))
    (seq-filter is-neuron-buffer (buffer-list))))

(defun neuron-refresh ()
  "Regenerate the zettel cache and the title overlays in all neuron-mode buffers."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (neuron--rebuild-cache)
  (mapcar
   (lambda (buffer) (with-current-buffer buffer (neuron--setup-overlays)))
   (neuron--list-buffers))
  (message "Regenerated zettel cache"))

(defun neuron--is-valid-id (id)
  "Check whether the ID is a valid neuron zettel ID.
Valid IDs should be strings of alphanumeric characters."
  (string-match (rx bol (+ (or (char (?A . ?Z)) (char (?a . ?z)) digit (char "_-"))) eol) id))

(defun neuron--generate-id-arguments (id)
  "Build the command line arguments that specifies the ID of a new zettel.
When ID is non-nil, use that ID, otherwise use the default strategy defined
by `neuron-id-format'. If it is `'prompt' and that the entered ID is invalid,
return nil."
  (if (and id (neuron--is-valid-id id))
      (list "--id" id)
    (pcase neuron-id-format
      ('hash '("--id-hash"))
      ('date '("--id-date"))
      ('prompt
       (if-let* ((id (read-string "ID: "))
                 (_  (neuron--is-valid-id id)))
           (list "--id" id)
         (user-error "Invalid ID: %S" id))))))

(defun neuron-create-zettel (title &optional id)
  "Create a new zettel in the current zettelkasten.
The new zettel will be generated with the given TITLE and ID if specified.
When TITLE is nil, prompt the user."
  (interactive (list (read-string "Title: ")))
  (neuron-check-if-zettelkasten-exists)
  (when-let* ((id-args (neuron--generate-id-arguments id))
              (args    (append '("new") id-args (list title)))
              (path    (neuron--run-command (apply #'neuron--make-command args))))
    (and
     (neuron--rebuild-cache)
     (message (concat "Created " (f-filename path)))
     (neuron--get-cached-zettel-from-id (f-base path)))))

(defun neuron-new-zettel (&optional title id)
  "Create a new zettel and open it in a new buffer.
The new zettel will be generated with the given TITLE and ID if specified.
When TITLE is nil, prompt the user."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (when-let* ((zettel  (call-interactively #'neuron-create-zettel title id))
              (buffer  (find-file-noselect (map-elt zettel 'path))))
    (and
     (pop-to-buffer-same-window buffer)
     (with-current-buffer buffer (neuron-mode) buffer))))

;;;###autoload
(defun neuron-open-daily-notes ()
  "Create or open today's daily notes."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (let* ((today  (current-time))
         (zid    (format-time-string neuron-daily-note-id-format today))
         (title  (format-time-string neuron-daily-note-title-format today))
         (exists (alist-get 'path (neuron--query-zettel-from-id zid)))
         (path   (or exists (let ((zettel (neuron-create-zettel title zid))) (map-elt zettel 'path))))
         (buffer (and path (find-file-noselect path))))
    (and
     (pop-to-buffer-same-window buffer)
     (with-current-buffer buffer
       (neuron-mode)
       (unless exists
         (dolist (tag neuron-daily-note-tags)
           (neuron-add-tag tag)))))))

(defun neuron--style-zettel-id (zid)
  "Style a ZID as shown in the ivy prompt."
  (propertize (format "<%s>" zid) 'face 'neuron-link-face))

(defun neuron--style-tags (tags)
  "Style TAGS as shown in the ivy prompt when selecting a zettel."
  (if (eq tags [])
      ""
    (propertize (format "(%s)" (s-join ", " tags)) 'face 'neuron-zettel-tag-face)))

(defun neuron--propertize-zettel (zettel)
  "Format ZETTEL as shown in the selection prompt."
  (let* ((zid (map-elt zettel 'id))
         (display
          (format "%s %s %s"
                  (neuron--style-zettel-id zid)
                  (map-elt zettel 'title)
                  (neuron--style-tags (map-elt zettel 'tags)))))
    (propertize display 'zettel zettel)))

(defun neuron--select-zettel-from-list (zettels &optional prompt require-match)
  "Select a zettel from a given list.
ZETTELS is a list of maps containing zettels (keys: id, title, day, tags, path)
PROMPT is the prompt passed to `ivy-read'.  When REQUIRE-MATCH is
non-nil require the input to match an existing zettel."
  (let* ((selection
          (ivy-read (or prompt "Select Zettel: ")
                    (mapcar #'neuron--propertize-zettel zettels)
                    :caller 'neuron--select-zettel-from-list
                    :require-match require-match)))
    (or (get-text-property 0 'zettel selection) selection)))

(defun neuron--select-zettel-from-cache (&optional prompt)
  "Select a zettel from the current cache.
PROMPT is the prompt passed to `ivy-read'."
  (neuron--select-zettel-from-list (map-values neuron--zettel-cache) prompt t))

(defun neuron--select-zettel-from-query (uri)
  "Select a zettel from the match of URI."
  (neuron--select-zettel-from-list (neuron--query-url-command uri) nil t))

(defun neuron-select-zettel (&optional prompt)
  "Find a zettel in the current zettelkasten.
PROMPT is the prompt passed to `ivy-read'."
  (neuron-check-if-zettelkasten-exists)
  (neuron--select-zettel-from-cache prompt))

(defun neuron-edit-zettel ()
  "Select and edit a zettel from the currently active zettelkasten."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (let* ((zettel (neuron-select-zettel "Edit zettel: "))
         (path   (map-elt zettel 'path))
         (buffer (find-file-noselect path)))
    (and
     (pop-to-buffer-same-window buffer)
     (neuron-mode))))

(defun neuron-edit-zettelkasten-configuration ()
  "Open the neuron.dhall configuration file at the root of the zettelkasten."
  (interactive)
  (find-file (f-join "/" (neuron-zettelkasten) "neuron.dhall")))

(defun neuron--insert-static-link-action (path)
  "Insert a link to file PATH relative to the static directory."
  (if (f-descendant-of? path (f-join "/" neuron--current-zettelkasten "static"))
      (insert (format "[](%s)" (f-relative path neuron--current-zettelkasten)))
    (when (y-or-n-p (format "File %s is not in the static directory, copy it to %s/static?" path root))
      (let ((copied-path (f-join "/" root "static" (f-filename path))))
        (copy-file path copied-path)
        (insert (format "[](%s)" (f-relative copied-path root)))))))

(defun neuron-insert-static-link ()
  "Insert a link to a file in the static directory."
  (interactive)
  (when-let* ((root              (neuron-zettelkasten))
              (default-directory (f-join "/" root "static")))
    (ivy-read "Select static file: " #'read-file-name-internal
              :matcher #'counsel--find-file-matcher
              :action #'neuron--insert-static-link-action
              :keymap counsel-find-file-map
              :caller 'neuron-insert-static-link)))

(defun neuron--insert-zettel-link-from-id (id)
  "Insert a zettel link.
Depending on the value of `neuron-use-short-links',
the inserted link will either be of the form <ID> or
[ID](z:/)."
  (if neuron-use-short-links
      (progn
        (insert (format "<%s>" id))
        (neuron--setup-overlays))
    (format "[%s](z:/)" id)))

(defun neuron-insert-zettel-link ()
  "Insert a markdown hypertext link to another zettel."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (neuron--insert-zettel-link-from-id (map-elt (neuron-select-zettel) 'id)))

(defun neuron-insert-new-zettel ()
  "Create a new zettel."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (when-let* ((title  (read-string "Title: "))
              (path   (neuron-new-zettel title))
              (id     (f-base (f-no-ext path)))
              (buffer (find-file-noselect path)))
    (progn
      (neuron--rebuild-cache)
      (neuron--insert-zettel-link-from-id id)
      (pop-to-buffer-same-window buffer)
      (neuron-mode)
      (message (concat "Created " (f-filename path))))))

(defun neuron-create-zettel-from-selection ()
  "Transforms the selected text into a new zettel with the selection as a title."
  (interactive)
  (let* ((selection (buffer-substring-no-properties (region-beginning) (region-end)))
         (title     (funcall neuron-make-title selection))
         (zettel    (neuron-create-zettel title)))
    (save-excursion
      (call-interactively #'delete-region)
      (goto-char (region-beginning))
      (insert (neuron--insert-zettel-link-from-id (alist-get 'id zettel)))
      (neuron--overlay-update))))

(defun neuron-create-and-insert-zettel-link (no-prompt)
  "Insert a markdown hypertext link to another zettel.
If the selected zettel does not exist it will be created.  When
NO-PROMPT is non-nil do not prompt when creating a new zettel."
  (interactive "P")
  (neuron-check-if-zettelkasten-exists)
  (let* ((selection
          (neuron--select-zettel-from-list
           (map-values neuron--zettel-cache)
           "Link zettel: "))
         (id (and (listp selection) (alist-get 'id selection))))
    (pcase selection
      ;; Existing zettel:
      ((guard id)
       (neuron--insert-zettel-link-from-id id))
      ;; Title of new zettel:
      ((pred stringp)
       (when (or no-prompt
                 (y-or-n-p (concat "Create a new zettel (" selection ")? ")))
         (let ((id (map-elt (neuron-create-zettel selection) 'id)))
           (neuron--rebuild-cache)
           (neuron--insert-zettel-link-from-id id)))))))

(defun neuron-toggle-connection-type ()
  "Toggle the link under point between folgezettel and cf connection."
  (interactive)
  (if (thing-at-point-looking-at
       neuron-link-regex
       ;; limit to current line
       (max (- (point) (line-beginning-position))
            (- (line-end-position) (point))))
      (if-let* ((link (match-string 1))
                (start (match-beginning 0))
                (end (match-end 0))
                (query (neuron--parse-query-from-url-or-id link))
                (conn (alist-get 'conn query))
                (toggled (if (eq conn 'ordinary) 'folgezettel 'ordinary))
                (new-query (map-insert (map-delete query 'conn) 'conn toggled)))
          (save-excursion
            (goto-char start)
            (delete-region start end)
            (insert (neuron-render-query new-query))
            (neuron--setup-overlays))
        (user-error "Invalid query"))
    (user-error "No query under point")))

(defun neuron--flatten-tag-node (node &optional root)
  "Flatten NODE into a list of tags.
Each element is a map containing 'tag and 'count keys.
The full tag is retrieved from the ROOT argument that is passed recursively.
See `neuron--flatten-tag-tree'."
  (let* ((name  (map-elt node 'name))
         (count (map-elt node 'count))
         (children (map-elt node 'children))
         (tag   (if root (concat root "/" name) name))
         (elem  (list (cons 'count count) (cons 'tag tag))))
    (cons elem (neuron--flatten-tag-tree children tag))))

(defun neuron--flatten-tag-tree (tree &optional root)
  "Flatten TREE into a list of tags.
Each element is a map containing 'tag and 'count keys.
The full tag is retrieved from the ROOT argument that is passed recursively."
  (apply #'append (mapcar (lambda (node) (neuron--flatten-tag-node node root)) tree)))

(defun neuron--propertize-tag (elem)
  "Format ELEM as shown in the tag selection prompt.
ELEM is a map containing the name of the tag and the number of associated zettels."
  (let* ((tag   (map-elt elem 'tag))
         (count (map-elt elem 'count))
         (display-count (propertize (format "(%d)" count) 'face 'shadow)))
    (propertize (format "%s %s" tag display-count) 'tag tag 'count count)))

(defun neuron--select-tag-from-query (uri &optional require-match)
  "Prompt for a tag that is matched by the zquery URI.
If REQUIRE-MATCH is non-nil require user input to match an existing
tag."
  (let* ((tags (neuron--flatten-tag-tree (neuron--query-url-command uri)))
         (selection
          (ivy-read "Select tag: "
                    (mapcar #'neuron--propertize-tag tags)
                    :predicate (lambda (tag) (not (zerop (get-text-property 0  'count tag))))
                    :caller 'neuron-select-tag
                    :require-match require-match)))
    (or (get-text-property 0 'tag selection) selection)))

(defun neuron--navigate-to-metadata-field (field)
  "Move point to the character after metadata FIELD.
If FIELD does not exist it is created."
  (goto-char (point-min))
  (let* ((delim (rx bol "---" (0+ blank) eol))
         (begin (if (looking-at-p delim) (point)
                  (save-excursion (insert "---\n---\n"))
                  (point)))
         (end (save-excursion
                (goto-char begin)
                (forward-line)
                (while (not (looking-at-p delim))
                  (forward-line))
                (point)))
         (fieldre (rx-to-string `(: bol (0+ blank) ,field ":" (0+ blank)))))
    (unless (search-forward-regexp fieldre end t)
      (goto-char end)
      (forward-line -1)
      (end-of-line)
      (insert (concat "\n" field ": ")))))

(defun neuron-add-tag (tag)
  "Add TAG to the list of tags.
When called interactively this command prompts for a tag."
  (interactive (list (neuron-select-tag)))
  (save-excursion
    (neuron--navigate-to-metadata-field "tags")
    (insert (concat "\n  - " tag)))
  (neuron--rebuild-cache))

(defun neuron-select-tag (&optional require-match)
  "Prompt for a tag that is already used in the zettelkasten.
If REQUIRE-MATCH is non-nil require user input to match an existing
tag."
  (neuron-check-if-zettelkasten-exists)
  (neuron--select-tag-from-query "z:tags" require-match))

(defun neuron-insert-tag ()
  "Select and insert a tag that is already used in the zettelkasten."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (insert (neuron-select-tag)))

(defun neuron-query-tags (&rest tags)
  "Select and edit a zettel from those that are tagged by TAGS."
  (interactive (list (neuron-select-tag t)))
  (neuron-check-if-zettelkasten-exists)
  (let ((query (mapconcat (lambda (tag) (format "tag=%s" tag)) tags "&")))
    (neuron--edit-zettel-from-query (format "z:zettels?%s" query))))

(defun neuron--edit-zettel-from-path (path)
  "Open a neuron zettel from PATH."
  (pop-to-buffer-same-window (find-file-noselect path))
  (neuron-mode))

(defun neuron--query-zettel-from-id (id)
  "Query a single zettel from the active zettelkasten from its ID.
Returns a map containing its title, tag and full path."
  (neuron--read-query-result (neuron--run-command (neuron--make-command "query" "--id" id))))

(defun neuron--get-cached-zettel-from-id (id &optional retry)
  "Fetch a cached zettel from its ID.
When RETRY is non-nil and that the ID wasn't found, the cache is regenerated
and queried a second time. This is called internally to automatically refresh
the cache when the ID is not found."
  (or (map-elt neuron--zettel-cache (intern id))
      (when retry
        (neuron--rebuild-cache)
        (or (map-elt neuron--zettel-cache (intern id))
            (user-error "Cannot find zettel with ID %s" id)))))

(defun neuron--edit-zettel-from-id (id)
  "Open a neuron zettel from ID."
  (let ((zettel (neuron--get-cached-zettel-from-id id)))
    (neuron--edit-zettel-from-path
     (map-elt zettel 'path))))

(defun neuron--edit-zettel-from-query (uri)
  "Select and edit a zettel from a neuron query URI."
  (neuron--edit-zettel-from-path (map-elt (neuron--select-zettel-from-query uri) 'path)))

(defun neuron--get-current-zettel-id ()
  "Extract the zettel ID of the current file."
  (f-base (buffer-name)))

(defun neuron--open-page (rel-path)
  "Open the REL-PATH in the browser.
The path is relative to the neuron output directory."
  (let* ((path (f-join "/" neuron--current-zettelkasten ".neuron" "output" rel-path))
         (url (format "file://%s" path)))
    (browse-url url)))

(defun neuron--open-zettel-from-id (id)
  "Open the generated HTML file from the zettel ID."
  (neuron--open-page (format "%s.html" id)))

(defun neuron-open-zettel ()
  "Select a zettel and open the associated HTML file."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (neuron--open-zettel-from-id (map-elt (neuron-select-zettel "Open zettel: ") 'id)))

(defun neuron-open-index ()
  "Open the index.html file."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (neuron--open-page "index.html"))

(defun neuron-open-current-zettel ()
  "Open the current zettel's HTML file in the browser."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (neuron--open-zettel-from-id (neuron--get-current-zettel-id)))

(defconst neuron-link-regex
  (concat "<\\(z:" thing-at-point-url-path-regexp "\\|[A-Za-z0-9-_]+\\(?:\?[^][\t\n\\ {}]*\\)?\\)>")
  "Regex matching zettel links like <URL> or <ID>.
Group 1 is the matched ID or URL.")

(defun neuron--extract-id-from-partial-url (url)
  "Extract the ID from a single zettel URL."
  (let* ((struct (url-generic-parse-url url))
         (path   (car (url-path-and-query struct)))
         (type   (url-type struct))
         (parts  (s-split "/" path)))
    (pcase (length parts)
      (1 (when (not type) path))  ; path is ID
      (2 (when (and (equal type "z") (equal (nth 0 parts) "zettel")) (nth 1 parts))))))

(defun neuron--follow-query (query)
  "Follow a neuron link from a zettel ID or an URL.
QUERY is a query object as described in `neuron--parse-query-from-url-or-id'."
  (let ((url (map-elt query 'url)))
    (pcase (map-elt query 'type)
      ('zettel  (neuron--edit-zettel-from-id (map-elt query 'id)))
      ('zettels (neuron--edit-zettel-from-query url))
      ('tags    (neuron-query-tags (neuron--select-tag-from-query url))))))

(defun neuron--parse-query-from-url-or-id (url-or-id)
  "Parse a neuron URL or a raw zettel ID as an object representing the query.
URL-OR-ID is a string that is meant to be parsed inside neuron links inside
angle brackets. The query is returned as a map having at least a `'type' field.
When URL-OR-ID is a raw ID, or that it is an URL having startin with z:zettel,
the map also has an `'id' field. Whenever URL-OR-ID is an URL and not an ID,
the map features an `'url' field."
  (let* ((struct (url-generic-parse-url url-or-id))
         (path-and-query (url-path-and-query struct))
         (path   (car path-and-query))
         (query  (cdr path-and-query))
         (parts  (s-split "/" path))
         (type   (url-type struct))
         (args   (when query (url-parse-query-string query)))
         (conn   (if (assoc "cf" args) 'ordinary 'folgezettel))
         (common `((conn . ,conn)
                   (url . ,url-or-id)
                   (args . ,(assoc-delete-all "cf" args)))))
    (append
     common
     (if (equal type "z")
         (pcase (car parts)
           ("zettel"  (when-let ((id (nth 1 parts))) `((type . zettel) (id . ,id))))
           ("zettels" `((type . zettels)))
           ("tags"    `((type . tags))))
       ;; Probably just an ID
       `((type . zettel) (id . ,path))))))

(defun neuron-render-query (query)
  "Render a neuron query in markdown.
QUERY is an alist containing at least the query type and the URL."
  (let* ((args (alist-get 'args query))
         (conn (alist-get 'conn query))
         (url-args (if (eq conn 'ordinary) (cons '("cf" "") args) args))
         (url-query (url-build-query-string url-args))
         (url-suffix (if url-args (format "?%s" url-query) "")))
    (pcase (alist-get 'type query)
      ('zettel (format "<%s%s>" (alist-get 'id query) url-suffix))
      ('zettels (format "<z:zettels%s>" url-suffix))
      ('tags (format "<z:tags%s>" url-suffix)))))

(defun neuron-follow-thing-at-point ()
  "Open the zettel link at point."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  ;; New links (from the `thing-at-point' demo)
  (if (thing-at-point-looking-at
       neuron-link-regex
       ;; limit to current line
       (max (- (point) (line-beginning-position))
            (- (line-end-position) (point))))
      (if-let ((query (neuron--parse-query-from-url-or-id (match-string 1))))
          (neuron--follow-query query)
        (user-error "Invalid query"))
    ;; Old style links
    ;; TODO deprecate
    (let* ((link   (markdown-link-at-pos (point)))
           (id     (nth 2 link))
           (url    (nth 3 link))
           (struct (url-generic-parse-url url))
           (type   (url-type struct)))
      (pcase type
        ((or "z" "zcf") (neuron--edit-zettel-from-id id))
        ((or "zquery" "zcfquery")
         (pcase (url-host struct)
           ("search" (neuron--edit-zettel-from-path (map-elt (neuron--select-zettel-from-query url) 'path)))
           ("tags"   (neuron-query-tags (neuron--select-tag-from-query url)))))
        (_          (markdown-follow-thing-at-point link))))))

(defun neuron-rib-watch ()
  "Start a web app for browsing the zettelkasten."
  (interactive)
  (let ((root (neuron-zettelkasten)))
    (if (neuron--run-rib-process "-w")
        (message "Watching %s for changes..." root)
      (user-error "Failed to watch %s" root))))

(defun neuron-rib-serve ()
  "Start a web app for browsing the zettelkasten."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (if (neuron--run-rib-process "-wS")
      (message "Started web application on localhost:8080")
    (user-error "Failed to run rib server on localhost:8080")))

(defun neuron-rib-generate ()
  "Do an one-off generation of the web interface of the zettelkasten."
  (interactive)
  (let ((root (neuron-zettelkasten)))
    (if (neuron--run-rib-compile)
        (message "Generated HTML files")
      (user-error "Failed to generate %s" root))))

(defun neuron-rib-open-page (page)
  "Open the web-application at page PAGE."
  (neuron-check-if-zettelkasten-exists)
  (browse-url (format "http://localhost:8080/%s" page)))

(defun neuron-rib-open-z-index ()
  "Open the web application in the web browser at z-index."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (neuron-rib-open-page "z-index.html"))

(defun neuron-rib-open-current-zettel ()
  "Open the web application in the web browser at the current zettel note."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (let ((id (f-base (buffer-file-name))))
    (neuron-rib-open-page (concat id ".html"))))

(defun neuron-rib-open-zettel ()
  "Open a zettel in the web application."
  (interactive)
  (neuron-check-if-zettelkasten-exists)
  (let ((zettel (neuron-select-zettel)))
    (neuron-rib-open-page (concat (map-elt zettel 'id) ".html"))))

(defun neuron-rib-kill ()
  "Stop the web application."
  (interactive)
  (kill-buffer "*rib*"))

(defun neuron--setup-overlay-from-id (ov zid)
  "Setup a single title overlay from a zettel ID.
OV is the overay to setup or update and ZID is the zettel ID."
  (if-let* ((zettel (ignore-errors (neuron--get-cached-zettel-from-id zid)))
            (title  (map-elt zettel 'title)))
      (overlay-put ov 'after-string (format " %s" (propertize title 'face 'neuron-title-overlay-face)))
    (overlay-put ov 'after-string (format " %s" (propertize "Unknown ID" 'face 'neuron-invalid-zettel-id-face)))
    (overlay-put ov 'face 'neuron-invalid-link-face)))

(defun neuron--overlay-update (ov after &rest _)
  "Delete the title overlay OV on modification.
When AFTER is non-nil, this hook is being called after the update occurs."
  (let ((link (buffer-substring (overlay-start ov) (overlay-end ov))))
    (when after
      (if (string-match neuron-link-regex link)
          (if-let ((query (neuron--parse-query-from-url-or-id (match-string 1 link))))
              (neuron--setup-overlay-from-query ov query)
            (overlay-put ov 'face 'neuron-invalid-link-face))
        (delete-overlay ov)))))

(defun neuron--setup-overlay-from-query (ov query)
  "Setup a overlay OV from any zettel link QUERY."
  (overlay-put ov 'evaporate t)
  (overlay-put ov 'modification-hooks (list #'neuron--overlay-update))
  (overlay-put ov 'face 'neuron-link-face)
  (overlay-put ov 'mouse-face 'neuron-link-mouse-face)
  (overlay-put ov 'keymap neuron-mode-mouse-map)
  (when (equal (map-elt query 'type) 'zettel)
    (neuron--setup-overlay-from-id ov (map-elt query 'id))))

(defun neuron--setup-overlays ()
  "Setup title overlays on zettel links."
  (remove-overlays)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward neuron-link-regex nil t)
      (let ((ov    (make-overlay (match-beginning 0) (match-end 0) nil t nil))
            (query (neuron--parse-query-from-url-or-id (match-string 1))))
        (neuron--setup-overlay-from-query ov query)))))

(defvar neuron-mode-map nil "Keymap for `neuron-mode'.")

(progn
  (setq neuron-mode-map (make-sparse-keymap))

  (define-key neuron-mode-map (kbd "C-c C-z")   #'neuron-new-zettel)
  (define-key neuron-mode-map (kbd "C-c C-e")   #'neuron-edit-zettel)
  (define-key neuron-mode-map (kbd "C-c C-t")   #'neuron-insert-tag)
  (define-key neuron-mode-map (kbd "C-c C-S-t") #'neuron-query-tags)
  (define-key neuron-mode-map (kbd "C-c C-l")   #'neuron-insert-zettel-link)
  (define-key neuron-mode-map (kbd "C-c C-S-L") #'neuron-insert-new-zettel)
  (define-key neuron-mode-map (kbd "C-c C-s")   #'neuron-insert-static-link)
  (define-key neuron-mode-map (kbd "C-c C-r")   #'neuron-open-current-zettel)
  (define-key neuron-mode-map (kbd "C-c C-o")   #'neuron-follow-thing-at-point)

  (setq neuron-mode-mouse-map (make-sparse-keymap))
  (define-key neuron-mode-mouse-map [mouse-1]   #'neuron-follow-thing-at-point))

(defvar neuron-mode-hook nil
  "Hook run when entering `neuron-mode'.")

(push "z:" thing-at-point-uri-schemes)

;;;###autoload
(define-derived-mode neuron-mode markdown-mode "Neuron"
  "A major mode to edit Zettelkasten notes with neuron."
  (neuron-check-if-zettelkasten-exists)
  (when neuron-generate-on-save
    (add-hook 'after-save-hook #'neuron-rib-generate t t))
  (add-hook 'after-save-hook #'neuron--setup-overlays t t)
  (neuron--setup-overlays)
  (neuron--rebuild-cache)
  (use-local-map neuron-mode-map))

(provide 'neuron-mode)

;;; neuron-mode.el ends here

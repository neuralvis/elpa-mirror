;;; shroud.el --- Interface for Shroud

;; Copyright (C) 2019  Amar Singh

;;; Author: Amar Singh <nly@disroot.org>
;;; Homepage: http://git.nly.info.tm:9001/shroud.git
;; Package-Version: 20190518.1508
;;; Package-X-Original-Version: 1.12
;;; Keywords: tools
;;; Package-Requires: ((emacs "24") (f "0.20") (bui "1.2.0") (epg "1.0.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Shroud is a simple password manager using Gnupg to encrypt plain
;; scheme expressions.  This package provides functions for working
;; with shroud.  To use: M-x shroud.
;;

;;; Code:

(require 'f)
(require 'bui)
(require 'epg)

(defgroup shroud '()
  "Interface for shroud password manager"
  :prefix "shroud-"
  :group 'shroud)

(defcustom shroud-password-length 8
  "Default password length."
  :group 'shroud
  :type 'number)

(defcustom shroud-executable (executable-find "shroud")
  "Shroud executable."
  :group 'shroud
  :type 'executable)

(defcustom shroud-database-file (or (concat (getenv "HOME")
					    "/.config/shroud/db.gpg"))
  "Shroud Datastore file.

GPG Encrypted."
  :group 'shroud
  :type 'file)

(defcustom shroud-timeout (or (getenv "SHROUD_CLIPBOARD_TIMEOUT")
      45)
  "Number of seconds to wait before clearing the password."
  :group 'shroud
  :type 'integer)

;;; use shroud--run instead.
(defun shroud--internal-old (shroud-command &rest args)
  "Internal shroud helper function.
Execute SHROUD-COMMAND with &rest ARGS."
  (s-trim (shell-command-to-string
            (mapconcat 'identity
                       (cons shroud-executable
                             (cons shroud-command
                                   (delq nil args)))
                       " "))))

(defun shroud--run-internal (&rest args)
  "Run the shroud commands with ARGS.
Nil arguments will be ignored.  Returns the output on success,  or
  outputs error messasge on failure."
  (with-temp-buffer
    (let* ((tempfile (make-temp-file ""))
           (exit-code
            (apply 'call-process
                   (append
                    (list shroud-executable nil (list t tempfile) nil)
                    (delq nil args)))))
      (unless (zerop exit-code)
        (erase-buffer)
        (insert-file-contents tempfile))
      (delete-file tempfile)
      (if (zerop exit-code)
          (s-trim (buffer-string))
        (error (s-trim (buffer-string)))))))

(defalias 'shroud--run 'shroud--run-internal)

;;; Help
(defun shroud--help (&rest sub-entry)
  "Return shroud help strings.
SUB-ENTRY is passed straight to shroud."
  (apply #'shroud--run (car sub-entry) "--help" '()))

(defun shroud--help--list ()
  "Return help strings for shroud list."
  (shroud--help "list"))

(defun shroud--help--remove ()
  "Return help strings for shroud remove."
  (shroud--help "remove"))

(defun shroud--help--hide ()
  "Return help strings for shroud hide."
  (shroud--help "hide"))

(defun shroud--help--show ()
  "Return help strings for shroud show."
  (shroud--help "show"))

(defun shroud--version ()
  "Return shroud version."
  (shroud--run "--version"))

;;; List Entries
(defun shroud--list ()
  "Return the output of shroud list.
ARGS are passed straight to shroud."
  (split-string  (shroud--run "list") "\n"))

;;; Hide secrets
(defun shroud--hide (&rest args)
  "Return the output of shroud hide.
ARGS are passed straight to shroud."
  (apply #'shroud--run "hide" args))

(defun shroud--hide-edit (&rest args)
  "Return the output of shroud edit.
ARGS are passed straight to shroud."
  (apply #'shroud--hide "--edit" args))
;;; shroud hide edit entry password
;;; shroud hide edit entry username
;;; shroud hide edit add entry new-entry value
;;; shroud hide edit

(defun shroud--show (entry &rest args)
  "Return the output of shroud show ENTRY.
if ARGS are nil, shroud will show you all sub-entries.
Otherwise, you can pass the ARGS as STRING."
  (apply #'shroud--run "show" entry args))

;;; Bug when entries may contain empty entries or newlines in entries
(defun shroud--show-entry (entry)
  "Return the results of ‘shroud--show’ ENTRY in Lisp lists."
  (mapcar #'(lambda (x) (split-string x " "))
          (mapcar #'(lambda (s) (replace-regexp-in-string "[ \t\n\r]+" " " s))
                  (split-string (shroud--show entry) "\n"))))

(defun shroud--show-sub-entries (entry &rest sub-entry)
  "Return the output of shroud show ENTRY.
if SUB-ENTRY are nil, shroud will show you all sub-entries.
Otherwise, you can pass the ARGS as STRING."
  (apply #'shroud--show entry sub-entry))

(defun shroud--show-clipboard (entry &rest sub-entries)
  "Add the ENTRY and SUB-ENTRIES to clipboard."
  (apply #'shroud--show "--clipboard" entry sub-entries))

(defun shroud--show-username (entry)
  "Show the username for given ENTRY."
  (shroud--show entry "username"))

(defun shroud--show-password (entry)
  "Show the password for given ENTRY."
  (shroud--show entry "password"))

(defun shroud--show-url (entry)
  "Show the url for given ENTRY."
  (shroud--show entry "url"))

(defun shroud--remove (entry)
  "Shroud remove ENTRY."
  (shroud--run "remove" entry))

(defmacro shroud--query (q)
  `(lambda (s) (s-matches? ,q s)))

(defun shroud--find (entry)
  "Shroud find ENTRY.

Returns a list of matches."
  (-filter (shroud--query entry) (shroud--list)))

;;; So, we have most of the commands that we will need to use bound to
;;; very friendly elisp functions. Notably missing is clipboard clear
;;; functionality.

;;; However, since I am already depending on shroud, it's better to
;;; slowly improve upon the broken application rather wait for myself
;;; to get the motivation(tm) to do it properly.

;;; I like the popup buffer UI a lot. I think a good UI would still be
;;; a helm UI but i still don't fully understand how it might work.

;;; Let's implement what we know already, We need a popup buffer which
;;; will show the available entries in shroud.  First course of
;;; action, define a procedure to output all shroud entries in a new
;;; buffer. Then, We will have a shroud-minor-mode-map we will add the
;;; keybindings to, so that we can quickly execute commands on
;;; entries. Commands like adding password, url, or either username to
;;; the kill-ring.

;;; Minor mode map will contain the keyboard shortcuts for
;;; `shroud-minor-mode'.It may not be necessary after we have a better
;;; Interface like BUI.
;;; This procedure prints the available entries in shroud in a split
;;; window.  The ad-hoc buffer interface we created earlier is not
;;; sufficient, it uses up too much space, messes up the previous
;;; window layout. We'd like to use something more convenient, and at
;;; the same time, avoid the work that comes with it. The author of
;;; this package is already familiar with Buffer User Interface (BUI)
;;; used in guix.el. So, it would be a fine first choice. We want a
;;; buffer to display the available password entries, and though, bui
;;; should provide us to display more details, for the privacy context
;;; of our application, we'd like to only show the Title, and perhaps
;;; the URL? Depending on how risky you are feeling, you could display
;;; even emails/username(!) for peek-over-the-shoulder security
;;; attacks. But make no mistake, this package is by no means secure,
;;; as it stores the password as plain string in the kill
;;; ring. Lazy...  err, lack of incentive.

;;; Load the bui library

;;; Hug it, I'll drop the nly/ prefix, it just seems silly now.
;;; The entry point to the shroud BUI.
;;; Let's just read directly from the db.gpg file using elisp

;;; Alright, so it appears shroud is very limited in terms of
;;; functionality and i can probably do much better if i simply use
;;; the elisp features to read and parse the file. Shroud provides
;;; another interface to the database, which then makes three
;;; interfaces, plain text; after decryption, shroud cli, shroud.el,
;;; and pure elisp interface. At this point only the data structure is
;;; important.  So, emacs has features to decrypt a file, decrypt
;;; buffers and whatnot. I have a feeling this is also going to be a
;;; bit ad-hoc, which scares me. Ad-hoc code is never portable or
;;; doesnt last as long. Nevertheless it's much better than limiting
;;; myself to the very limited cli interface, through which all elisp
;;; code has to go anyway. Alternatively can i use a guile daemon?

;;; Elisp reader for shroud db.gpg
;; Individually reading entries is painfully slow
(defun shroud--read-db (&optional db-file)
  "Decrypt and read the shroud db.  By default it's the db.gpg file.

Optionally DB-FILE is the file you want to read."
  (read (with-temp-buffer
          (insert-file-contents-literally (or db-file shroud-database-file))
          (let ((context (epg-make-context 'OpenPGP)))
            (decode-coding-string
             (epg-decrypt-string context (buffer-substring-no-properties (point-min) (point-max)))
             'utf-8)))))

;;; Just reading the database is not enough, we need to slighly
;;; massage the data so that it's usable by BUI.
(defun shroud-entries ()
  "Format the shroud db to something suitable for BUI."
  ;; (mapcar 'shroud-entry (shroud--list)) ;; too slow
  ;; This function can read a shroud db from a file.
  (let* ((db (shroud--read-db)))
    (cl-labels
        ((flatten-contents (x) (rest (first x)))
         (name-from-id (x)
                       (cons (if (equal (first x) 'id)
                                 'name
                               (first x))
                             (rest x))))
      (mapcar
       #'(lambda (x) (cons (first x)
                      (cons (name-from-id (first x))
                            (flatten-contents (rest x)))))
       db))))

;;; This is the interface for defining a BUI interface. It has a
;;; simple declarative syntax and a clean seperation of processes. For
;;; example, the BUI requires the entries to be formatted, you can
;;; define the format within this interface, and then leisurely define
;;; a procedure, externally, which may "massage" your data into the
;;; correct format.
(bui-define-interface shroud-entries list
  :buffer-name "*Shroud*"
  :get-entries-function 'shroud-entries
  :format
  '((name nil 30 t)
    (password nil 30 t)
    (username nil 8 t)
    (url nil 8 t)
    (notes nil 8 t))
  :sort-key '(name))

(defun shroud-bui--deprecated ()
  "Display a list of entries in the shroud db."
  (bui-get-display-entries 'shroud-entries 'list))

;; New BUI
(bui-define-groups shroud
  :parent-group tools
  :parent-faces-group faces
  :group-doc "Settings for '\\[shroud]' command."
  :faces-group-doc "Faces for '\\[shroud]' command.")

(defun shroud-find-entries (&optional search-type &rest search-values)
  (let* ((entries (shroud--list)))
  (or search-type (setq search-type 'all))
  (cl-case search-type
    (all entries)
    (name (-mapcat #'shroud--find search-values))
    (t (error "Unknown search type: %S" search-type)))))

(defun shroud-entry->entry (a)
  `((name . ,a)
    (id . ,a)))

(defun entry->shroud-entry (a)
  (alist-get 'name a))

(defun shroud-get-entries (&rest args)
  (mapcar #'shroud-entry->entry
          (apply #'shroud-find-entries args)))

(bui-define-interface shroud list
  :buffer-name "*Shroud*"
  :get-entries-function 'shroud-get-entries
  :format '((name nil 30 t))
  :sort-key '(name))

(let ((map shroud-list-mode-map))
  (define-key map (kbd "c") 'shroud-list-copy-current-entry-pass)
  (define-key map (kbd "d")   'shroud-list-remove-current-entry)
  (define-key map (kbd "e")   'shroud-list-edit-current-entry)
  (define-key map (kbd "a")   'shroud-list-add-entry)
  (define-key map (kbd "w")   'shroud-list-copy-current-entry-url)
  (define-key map (kbd "I")   'shroud-list-copy-current-entry-username))

(defun shroud-list-copy-current-entry-pass ()
  (interactive)
  (and (kill-new (shroud--show-password (bui-list-current-id)))
       (message "Password copied")))

(defun shroud-list-copy-current-entry-url ()
  (interactive)
  (and (kill-new (shroud--show-url (bui-list-current-id)))
       (message "Url copied")))

(defun shroud-list-copy-current-entry-username ()
  (interactive)
  (and (kill-new (shroud--show-username (bui-list-current-id)))
       (message "Username copied")))

(defun shroud-list-remove-current-entry ()
  (interactive)
  (and (shroud--remove (bui-list-current-id))
       (message "Entry deleted")))

(defvar shroud-edit-entry-minor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-s") 'shroud-save-entry)
    map))

;;; Editing is a bit more involved
(define-minor-mode shroud-edit-entry-minor-mode
  "Minor mode for editing shroud entry"
  :init-value nil
  :group 'shroud
  :lighter " Shroud-edit"
  :require 'shroud
  :keymap shroud-edit-entry-minor-mode-map
  )

(defcustom shroud--alist
  '((id . "")
    (contents .
              ((username . "")
               (password . "")
               (url . "")
               (notes . ()))))
  "Shroud alist format"
  :type 'alists)

(defun shroud--k+v->string (pair)
  (if (not (-cons-pair? (cdr pair)))
      (format "%s=%s" (car pair) (cdr pair))
    (format "%s=%s" (car pair) (cdr pair))))

(defun shroud-alist-serialize (exp)
  (s-join " " (-map #'shroud--k+v->string (alist-get 'contents exp))))

(defun shroud--hide-alist (exp)
  "Fix s-split, blocks from adding spaces anywhere. Though spaces
might fail further down the program."
  (if (shroud--find (alist-get 'id exp))
      (apply #'shroud--hide-edit
             (alist-get 'id exp)
             (s-split " " (shroud-alist-serialize exp)))
    (apply #'shroud--hide
           (alist-get 'id exp)
           (s-split " " (shroud-alist-serialize exp)))))

(defun shroud-save-entry (&optional exp)
  (interactive)
  (shroud--hide-alist
   (or exp (with-current-buffer (current-buffer)
                                (read (buffer-string))))))

(defun shroud--make-entry-buffer (entry)
  (concat "*shroud-edit*-" entry))

(defun shroud--make-buffer-entry (buffer)
  (car (s-split "<" (substring buffer (length "*shroud-edit*-")))))

(defun shroud-list-edit-current-entry--internal (&optional entry)
  (interactive)
  (let* ((entry (or entry (bui-list-current-id)))
        (buffer (generate-new-buffer-name (shroud--make-entry-buffer entry))))
    (and
     (progn
          ;; open the entry in a new buffer
          ;; allow the user to make changes
          ;; when user saves C-x C-s then
          ;; 1. save the entry 2. discard the buffer
          (generate-new-buffer buffer)
          (switch-to-buffer-other-window buffer)
          (with-current-buffer buffer
            (emacs-lisp-mode)
            (shroud-edit-entry-minor-mode)
            (insert (format "%s" shroud--alist))))
         (message (format "Shroud: editing %s , when finished Press C-c C-s" entry)))))

(defun shroud-list-edit-current-entry ()
  (interactive)
  (let ((entry (bui-list-current-id)))
    (and (shroud-list-edit-current-entry--internal entry)
       (message (concat "TODO: Edit " entry)))))

(defun shroud-list-add-entry--internal (&optional entry)
  (interactive)
  (let* ((buffer (generate-new-buffer-name (shroud--make-entry-buffer "new"))))
    (and
     (progn
          ;; open the entry in a new buffer
          ;; allow the user to make changes
          ;; when user saves C-x C-s then
          ;; 1. save the entry 2. discard the buffer
          (generate-new-buffer buffer)
          (switch-to-buffer-other-window buffer)
          (with-current-buffer buffer
            (emacs-lisp-mode)
            (shroud-edit-entry-minor-mode)
            (insert (format "%s" shroud--alist))))
         (message (format "Shroud: editing %s , when finished Press C-c C-s" entry)))))

(defun shroud-list-add-entry ()
  (interactive)
  (and (shroud-list-add-entry--internal)
       (message (concat "TODO: Add "))))


;;;###autoload
(defun shroud-bui ()
  "Display a list of buffers."
  (interactive)
  (bui-get-display-entries 'shroud 'list))

;;;###autoload
(defalias 'shroud 'shroud-bui)
;; interactively using M-x shroud
;; or (global-set-key '("C-c p") 'shroud)

(provide 'shroud)

;;; shroud.el ends here

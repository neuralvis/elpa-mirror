;;; gkroam.el --- A lightweight org-mode roam replica  -*- lexical-binding: t; -*-

;; Copyright (C) 2020 Kinney Zhang
;;
;; Version: 2.2.0
;; Package-Version: 20200924.1607
;; Package-Commit: 17a570821d601f3f061cd17de707bd1642f69762
;; Keywords: org, convenience
;; Author: Kinney Zhang <kinneyzhang666@gmail.com>
;; URL: https://github.com/Kinneyzhang/gkroam.el
;; Package-Requires: ((emacs "26.3") (company "0.9.10") (simple-httpd "1.5.1") (undo-tree "0.7.5"))

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; Gkroam is a light-weight roam repica, built on top of Org-mode.

;;; ChangeLog:

;; v1.0 - Auto update link references at the buttom of page buffer.

;; v2.0 - Use overlay to hide and show gkroam brackets accordingly and fix some bugs.

;; v2.0.1 - Fix 'hide and show brackets' problems in some main occasion.
;; Such as newline, etc.

;; v2.0.2 - Fix `gkroam-publish-current-file' and `gkroam-preview-current',
;; automatically convert gkroam link to org link and convert it back
;; after published (use 'undo', not reliable). But it has problem with publishing
;; the whole project.

;; v2.0.3 - Fix `gkroam-publish-site' and `gkroam-preview'. Now you can publish and
;; preview the whole roam site.

;; v2.0.4 - Many bugs fixed and code improvement.

;; v2.1.0 - A more powerful linked references system.

;; v2.1.1 - Change package name to 'gkroam' from 'gk-roam'.

;; v2.2.0 - Edit many pages in one side window and save changes separately.

;;; Code:

(require 'ox-publish)
(require 'simple-httpd)
(require 'company)
(require 'undo-tree)

;;;; Declarations
(declare-function org-publish-project "ox-publish")
(defvar org-link-frame-setup)
(defvar org-publish-project-alist)

;;;; Variables
(defgroup gkroam nil
  "A roam replica on top of emacs org-mode."
  :tag "gkroam"
  :group 'org)

(defcustom gkroam-root-dir "~/gkroam/org/"
  "Gkroam's root directory, with org files in it."
  :type 'string
  :group 'gkroam)

(defcustom gkroam-pub-dir "~/gkroam/site/"
  "Gkroam's publish directory, with html files in it."
  :type 'string
  :group 'gkroam)

(defcustom gkroam-pub-css "<link rel=\"stylesheet\" href=\"https://gongzhitaao.org/orgcss/org.css\">"
  "Gkroam publish css style."
  :type 'string
  :group 'gkroam)

(defcustom gkroam-page-template
  "#+TITLE: %s\n#+OPTIONS: toc:nil H:2 num:0\n"
  "Gkroam page's template, including export options of org files, end with \\n"
  :type 'string
  :group 'gkroam)

(defcustom gkroam-index-title "INDEX"
  "Title of index page."
  :type 'string
  :group 'gkroam)

(defvar gkroam-toggle-brackets-p t
  "Determine whether to show brackets in page link.")

(defvar gkroam-pages nil
  "Page candidates for completion.")

(defvar gkroam-mode-map (make-sparse-keymap)
  "Keymap for `gkroam-mode'.")

(defvar gkroam-has-link-p nil
  "Judge if has link or hashtag in gkroam buffer.")

(defvar gkroam-update-index-timer nil
  "Gkroam indexing timer.")

(defvar gkroam-link-regexp
  (rx (seq (group "{[")
           (group (+? (not (any "/\n"))))
           (group "]}")))
  "Regular expression that matches a gkroam link.")

(defvar gkroam-hashtag-regexp
  (rx (seq (group "#{[")
           (group (+? (not (any "/\n"))))
           (group "]}")))
  "Regular expression that matches a gkroam hashtag.")

(defvar gkroam-return-wconf nil
  "Saved window configuration before goto gkroam edit.")

(defvar gkroam-edit-flag nil
  "Non-nil means it's in process of gkroam edit.")

(defvar gkroam-edit-buf "*gkroam-edit*"
  "Gkroam edit buffer name.")

(defvar gkroam-edit-pages nil
  "Pages that have been editing in gkroam edit buffer.
The value is a list of page's title.")

(defvar gkroam-slash-magics nil
  "Gkroam slash commands.")

;;;; Functions
(defun gkroam-link-frame-setup ()
  "Alter `org-link-frame-setup' for gkroam."
  (setq org-link-frame-setup
        '((vm . vm-visit-folder-other-frame)
          (vm-imap . vm-visit-imap-folder-other-frame)
          (gnus . org-gnus-no-new-news)
          (file . find-file)
          (wl . wl-other-frame))))

(defun gkroam-at-root-p ()
  "Check if current file exists in `gkroam-root-dir'.
If BUFFER is non-nil, check the buffer visited file."
  (when (buffer-file-name)
    (file-equal-p (file-name-directory (buffer-file-name))
                  (expand-file-name gkroam-root-dir))))

(defun gkroam--get-title (page)
  "Get PAGE's title."
  (with-temp-buffer
    (insert-file-contents (gkroam--get-file page) nil 0 2000 t)
    (goto-char (point-min))
    (re-search-forward (concat "^ *#\\+TITLE:") nil t)
    (string-trim (buffer-substring (match-end 0) (line-end-position)))))

(defun gkroam--get-page (title)
  "Get gkroam page from TITLE."
  (let ((pages (gkroam--all-pages))
        file)
    (catch 'break
      (dolist (page pages)
        (setq file (gkroam--get-file page))
        (with-temp-buffer
          (insert-file-contents file nil 0 2000 t)
          (goto-char (point-min))
          (when (re-search-forward (format "^ *#\\+TITLE: *%s *$" title) nil t)
            (throw 'break page)))))))

(defun gkroam--get-file (page)
  "Get gkroam file accroding to PAGE."
  (expand-file-name page gkroam-root-dir))

(defun gkroam--all-pages ()
  "Get all gkroam pages."
  (directory-files gkroam-root-dir nil (rx bol (+ (in num)) ".org" eol)))

(defun gkroam--all-titles ()
  "Get all gkroam titles."
  (let* ((pages (gkroam--all-pages)))
    (mapcar (lambda (page) (gkroam--get-title page)) pages)))

(defun gkroam--gen-file ()
  "Generate new gkroam file path."
  (expand-file-name (gkroam--gen-page) gkroam-root-dir))

(defun gkroam--gen-page ()
  "Generate new gkroam page filename, without directory prefix."
  (format "%s.org" (format-time-string "%Y%m%d%H%M%S")))

(defsubst gkroam--format-link (title)
  "Format TITLE into a gkroam page link."
  (format "{[%s]}" title))

(defun gkroam--format-backlink (page)
  "Format gkroam backlink in PAGE."
  (let* ((title (gkroam--get-title page)))
    (format "[[file:%s][%s]]" page title)))

;; ----------------------------------------
(defvar gkroam-link-re-format
  "\\(\\(-\\|+\\|*\\|[0-9]+\\.\\|[0-9]+)\\) .*?{\\[%s\\]}.*\\(\n+ +.*\\)*
\\|\\(.*{\\[%s\\]}.*\\\\\n\\(.+\\\\\n\\)*.+\\|\\(.+\\\\\n\\)+.*{\\[%s\\]}.*\\\\\n\\(.+\\\\\n\\)*.+\\|\\(.+\\\\\n\\)+.*{\\[%s\\]}.*\\)
\\|.*#\\+begin_verse.*\n+\\(.+\n+\\|.*{\\[%s\\]}.*\n+\\)*.*{\\[%s\\]}.*\n+\\(\\)+\\(.+\n+\\|.*{\\[%s\\]}.*\n+\\)*.*#\\+end_verse.*
\\|.*{\\[%s\\]}.*\n\\)"
  "Gkroam link regexp format used for searching link context.")

(defun gkroam--search-process (page linum)
  "Return a rg process to search PAGE's link and output LINUM lines before and after matched string."
  (let ((title (gkroam--get-title page))
        (name (generate-new-buffer-name " *gkroam-rg*")))
    (start-process name name "rg" "-C"
                   (number-to-string linum)
                   "-FN" "--heading"
                   (format "{[%s]}" title)
                   (expand-file-name gkroam-root-dir) ;; must be absolute path.
                   "-g" "!index.org*")))

(defun gkroam--process-link-in-references (string)
  "Remove links in reference's STRING."
  (with-temp-buffer
    (insert string)
    (goto-char (point-min))
    (while (re-search-forward "#{\\[" nil t)
      (replace-match "*#"))
    (goto-char (point-min))
    (while (re-search-forward "\\({\\[\\|\\]}\\)" nil t)
      (replace-match "*"))
    (buffer-string)))

(defun gkroam-process-searched-string (string title)
  "Process searched STRING by 'rg', get page LINUM*2+1 lines of TITLE and context."
  (with-temp-buffer
    (insert string)
    (goto-char (point-min))
    (let ((gkroam-file-re (expand-file-name "[0-9]\\{14\\}\\.org" gkroam-root-dir))
          (num 0) references)
      (while (re-search-forward gkroam-file-re nil t)
        (let* ((path (match-string-no-properties 0))
               (page (file-name-nondirectory path))
               content context)
          (forward-line)
          (catch 'break
            (while (re-search-forward
                    (replace-regexp-in-string "%s" title gkroam-link-re-format)
                    nil t)
              (setq num (1+ num))
              (setq content (concat (match-string-no-properties 0) "\n"))
              ;; (setq content (gkroam-process-references-style content))
              (setq context (concat context content))
              (save-excursion
                (when (re-search-forward
                       (replace-regexp-in-string "%s" title gkroam-link-re-format)
                       nil t)
                  (re-search-backward gkroam-file-re nil t)
                  (unless (string= path (match-string-no-properties 0))
                    (throw 'break nil))))))
          (setq context (gkroam--process-link-in-references context))
          (setq references
                (concat references
                        (format "** %s\n%s" (gkroam--format-backlink page) context)))))
      (cons num references))))

(defun gkroam--search-linked-pages (process callback)
  "Call CALLBACK After the PROCESS finished."
  (let (sentinel)
    (setq sentinel
          (lambda (process event)
            (if (string-match-p (rx (or "finished" "exited"))
                                event)
                (if-let ((buf (process-buffer process)))
                    (with-current-buffer buf
                      (funcall callback (buffer-string)))
                  (error "Gkroam’s rg process’ buffer is killed"))
              (error "Gkroam’s rg process failed with signal: %s"
                     event))))
    (set-process-sentinel process sentinel)))

(defun gkroam-update-reference (page)
  "Update gkroam PAGE's reference."
  (unless (executable-find "rg")
    (user-error "Cannot find program rg"))
  (let ((linum 10))
    (gkroam--search-linked-pages
     (gkroam--search-process page linum)
     (lambda (string)
       (let* ((title (gkroam--get-title page))
              (file (gkroam--get-file page))
              (file-buf (find-file-noselect file t)))
         (with-current-buffer file-buf
           (save-excursion
             (goto-char (point-max))
             (re-search-backward "\n-----\n" nil t)
             (delete-region (point) (point-max))
             (unless (string= string "")
               (let* ((processed-str (gkroam-process-searched-string string title))
                      (num (car processed-str))
                      (references (cdr processed-str)))
                 (insert "\n-----\n")
                 (goto-char (point-min))
                 (re-search-forward "-----\n" nil t)
                 (insert (format "* %d Linked References\n" num))
                 (insert references))
               (save-buffer))))))))
  (message "%s reference updated" page))

(defun gkroam-new (title)
  "Just create a new gkroam page titled with TITLE."
  (let* ((file (gkroam--gen-file)))
    (with-current-buffer (find-file-noselect file t)
      (insert
       (format (concat gkroam-page-template "» [[file:index.org][%s]]\n\n")
               title gkroam-index-title))
      (save-buffer))
    (push title gkroam-pages)
    file))

(defun gkroam-update-index ()
  "Update gkroam index page."
  (let* ((index-org (expand-file-name "index.org" gkroam-root-dir))
         (index-buf (find-file-noselect index-org t)))
    (with-current-buffer index-buf
      (erase-buffer)
      (insert (format (concat gkroam-page-template "\n* Site Map\n\n")
                      gkroam-index-title))
      (dolist (page (gkroam--all-pages))
        (insert (format " + [[file:%s][%s]]\n" page (gkroam--get-title page))))
      (save-buffer))
    index-buf))

;; (define-minor-mode gkroam-index-mode
;;   "Update index using idle timer."
;;   :init-value nil
;;   :lighter ""
;;   :group "gkroam"
;;   (if gkroam-index-mode
;;       (setq gkroam-update-index-timer
;;             (run-with-idle-timer 5 10 #'gkroam-update-index))
;;     (cancel-timer gkroam-update-index-timer)
;;     (setq gkroam-update-index-timer nil)))

;;;; Commands
;;;###autoload
(defun gkroam-find (&optional title)
  "Create a new gkroam page or open an exist one in current window, titled with TITLE."
  (interactive)
  (let* ((title (or title (completing-read "New title or open an exist one: "
                                           (gkroam--all-titles) nil nil)))
         (page (gkroam--get-page title)))
    (if page
        (find-file (gkroam--get-file page))
      (find-file (gkroam-new title)))
    (gkroam-update)))

;;;###autoload
(defun gkroam-daily ()
  "Create or open gkroam daily notes."
  (interactive)
  (let* ((title (format-time-string "%b %d, %Y")))
    (gkroam-find title)))

;;;###autoload
(defun gkroam-insert (&optional title)
  "Insert a gkroam page titled with TITLE."
  (interactive)
  (if (gkroam-at-root-p)
      (let* ((title (or title (completing-read
                               "Choose a page or create a new: "
                               (gkroam--all-titles) nil nil
                               (thing-at-point 'word t))))
             (page (gkroam--get-page title)))
        (insert (gkroam--format-link title))
        (save-buffer)
        (gkroam-update-reference page))
    (message "Not in the gkroam directory!")))

;;;###autoload
(defun gkroam-new-at-point ()
  "Insert a file link and create a new file according to text at point."
  (interactive)
  (if (gkroam-at-root-p)
      (let* ((title (thing-at-point 'word t))
             (page-exist-p (gkroam--get-page title)))
        (if page-exist-p
            (progn
              (backward-word)
              (kill-word 1)
              (gkroam-insert title))
          (gkroam-new title)
          (backward-word)
          (kill-word 1)
          (gkroam-insert title)
          (gkroam-find title)))
    (message "Not in the gkroam directory!")))

;;;###autoload
(defun gkroam-new-from-region ()
  "Insert a file link and create a new file according to a selected region."
  (interactive)
  (if (and (gkroam-at-root-p) (region-active-p))
      (let* ((beg (region-beginning))
             (end (region-end))
             (title (buffer-substring-no-properties beg end))
             (page-exist-p (gkroam--get-page title)))
        (if page-exist-p
            (progn
              (delete-region beg end)
              (gkroam-insert title))
          (gkroam-new title)
          (delete-region beg end)
          (gkroam-insert title)
          (gkroam-find title)))
    (message "Not in the gkroam directory!")))

;;;###autoload
(defun gkroam-smart-new ()
  "Smartly create a new file according to point or region."
  (interactive)
  (cond
   ((region-active-p) (gkroam-new-from-region))
   ((thing-at-point 'word) (gkroam-new-at-point))
   (t (call-interactively #'gkroam-find))))

;;;###autoload
(defun gkroam-index ()
  "Show gkroam index page."
  (interactive)
  (switch-to-buffer (gkroam-update-index)))

;;;###autoload
(defun gkroam-update ()
  "Update current gkroam buffer's reference."
  (interactive)
  (if (gkroam-at-root-p)
      (gkroam-update-reference (file-name-nondirectory (buffer-file-name)))
    (message "Not in the gkroam directory!")))

;;;###autoload
(defun gkroam-update-all ()
  "Update all gkroam files' reference."
  (interactive)
  (gkroam-update-index)
  (let ((pages (gkroam--all-pages)))
    (mapcar #'gkroam-update-reference pages)))

(defun gkroam-resolve-link (orig-fun file &rest args)
  "Convert gkroam link to org link.
This is an advice for ORIG-FUN with argument FILE and other ARGS."
  (with-current-buffer (find-file-noselect file t)
    (goto-char (point-min))
    (setq gkroam-has-link-p nil)
    (while (re-search-forward gkroam-link-regexp nil t)
      (setq gkroam-has-link-p t)
      (let (beg end title hashtag-p)
        (setq beg (match-beginning 0))
        (setq end (match-end 0))
        (setq title (match-string-no-properties 2))
        (save-excursion
          (goto-char (1- beg))
          (when (string= (thing-at-point 'char t) "#")
            (setq hashtag-p t)))
        (delete-region beg end)
        (when hashtag-p (delete-region (1- beg) beg))
        (insert (format (if hashtag-p
                            "[[file:%s][#%s]]"
                          "[[file:%s][%s]]")
                        (gkroam--get-page title) title))))
    (save-buffer)
    (apply orig-fun file args)
    (when gkroam-has-link-p
      ;; if possible, use original undo function.
      (undo-tree-undo))))

(defun gkroam-set-project-alist ()
  "Add gkroam project to `org-publish-project-alist'."
  (setq org-publish-project-alist
        (remove (assoc "gkroam" org-publish-project-alist) org-publish-project-alist))
  (add-to-list
   'org-publish-project-alist
   `("gkroam"
     :base-extension "org"
     :recursive nil
     :base-directory ,(expand-file-name gkroam-root-dir)
     :publishing-directory ,(expand-file-name gkroam-pub-dir)
     :publishing-function org-html-publish-to-html
     :html-head ,gkroam-pub-css)))

;;;###autoload
(defun gkroam-publish-current-file ()
  "Publish current file."
  (interactive)
  (if (gkroam-at-root-p)
      (progn
        (gkroam-update)
        (if undo-tree-mode
            (org-publish-file (buffer-file-name))
          (message "please enable 'undo-tree-mode' in this buffer!")))
    (message "Not in the gkroam directory!")))

;;;###autoload
(defun gkroam-preview-current ()
  "Preview current file."
  (interactive)
  (if (gkroam-at-root-p)
      (let ((current-file (concat (file-name-base (buffer-file-name)) ".html")))
        (httpd-serve-directory gkroam-pub-dir)
        (unless (httpd-running-p) (httpd-start))
        (gkroam-publish-current-file)
        (if undo-tree-mode
            (browse-url (format "http://%s:%d/%s" "127.0.0.1" 8080 current-file))
          (message "please enable 'undo-tree-mode' in this buffer!")))
    (message "Not in the gkroam directory!")))

;;;###autoload
(defun gkroam-publish-site (&optional force async)
  "Publish gkroam project to html site.
If FORCE is non-nil, force to publish all pages.
If ASYNC is non-nil, publish pages in an async process."
  (interactive)
  (gkroam-update-index)
  ;; (gkroam-update-all)
  (if global-undo-tree-mode
      (org-publish-project "gkroam" force async)
    (message "please enable 'global-undo-tree-mode'!")))

;;;###autoload
(defun gkroam-preview ()
  "Preview gkroam site."
  (interactive)
  (progn
    (httpd-serve-directory gkroam-pub-dir)
    (unless (httpd-running-p) (httpd-start))
    (gkroam-publish-site t nil)
    (if global-undo-tree-mode
        (browse-url (format "http://%s:%d" "127.0.0.1" 8080))
      (message "please enable 'global-undo-tree-mode'!"))))

;;; ----------------------------------------
;; minor mode: gkroam-link-mode

(define-button-type 'gkroam-link
  'action #'gkroam-follow-link
  'title nil
  'follow-link t
  'help-echo "Jump to page")

(defun gkroam-follow-link (button)
  "Jump to the page that BUTTON represents."
  (with-demoted-errors "Error when following the link: %s"
    (if (string= (buffer-name) gkroam-edit-buf)
        (progn
          (other-window 1)
          (gkroam-find (button-get button 'title)))
      (gkroam-find (button-get button 'title)))))

(defun gkroam-link-fontify (beg end)
  "Put gkroam link between BEG and END."
  (goto-char beg)
  (while (re-search-forward gkroam-link-regexp end t)
    (make-text-button (match-beginning 0)
                      (match-end 0)
                      :type 'gkroam-link
                      'face '(:underline nil)
                      'title (match-string-no-properties 2))))

(defun gkroam-hashtag-fontify(beg end)
  "Put gkroam link between BEG and END."
  (goto-char beg)
  (while (re-search-forward gkroam-hashtag-regexp end t)
    (make-text-button (match-beginning 0)
                      (match-end 0)
                      :type 'gkroam-link
                      'face '(:underline nil)
                      'title (match-string-no-properties 2))))

(define-minor-mode gkroam-link-mode
  "Recognize gkroam link."
  :lighter ""
  :keymap (make-sparse-keymap)
  (if gkroam-link-mode
      (progn
        (jit-lock-register #'gkroam-hashtag-fontify)
        (jit-lock-register #'gkroam-link-fontify))
    (jit-lock-unregister #'gkroam-hashtag-fontify)
    (jit-lock-unregister #'gkroam-link-fontify))
  (jit-lock-refontify))

;; gkroam overlays

(defun gkroam-overlay-region (beg end prop value)
  "Put overlays in region started by BEG and ended with END.
The overlays has a PROP and VALUE."
  (overlay-put (make-overlay beg end) prop value))

(defun gkroam-overlay-hashtag ()
  "Overlay gkroam hashtag."
  (with-silent-modifications
    (gkroam-overlay-region (match-beginning 1) (match-beginning 2) 'display "")
    (gkroam-overlay-region (match-beginning 3) (match-end 0) 'display "")
    (gkroam-overlay-region (1- (match-beginning 0)) (match-end 0) 'face 'shadow)))

(defun gkroam-overlay-shadow-brackets ()
  "Set overlays to shadow brackets."
  (with-silent-modifications
    (remove-overlays (match-beginning 1) (match-beginning 2) 'display "")
    (remove-overlays (match-beginning 3) (match-end 0) 'display "")
    (gkroam-overlay-region (match-beginning 1) (match-beginning 2) 'face 'shadow)
    (gkroam-overlay-region (match-beginning 3) (match-end 0) 'face 'shadow)
    (gkroam-overlay-region (match-beginning 0) (match-end 0) 'face 'warning)))

(defun gkroam-overlay-hide-brackets ()
  "Set overlays to hide gkroam brackets."
  (with-silent-modifications
    (gkroam-overlay-region (match-beginning 1) (match-beginning 2) 'display "")
    (gkroam-overlay-region (match-beginning 3) (match-end 0) 'display "")
    (gkroam-overlay-region (match-beginning 0) (match-end 0) 'face 'warning)))

(defun gkroam-put-overlays (beg &optional bound)
  "Put overlays between BEG and BOUND."
  (when (eq major-mode 'gkroam-mode)
    (let ((bound (or bound (point-max))))
      (save-excursion
        (goto-char beg)
        (while (re-search-forward gkroam-link-regexp bound t)
          (if (string= (char-to-string
                        (char-before (match-beginning 0)))
                       "#")
              (gkroam-overlay-hashtag)
            (if gkroam-toggle-brackets-p
                (gkroam-overlay-shadow-brackets)
              (gkroam-overlay-hide-brackets))))))))

(defun gkroam-restore-line-overlays ()
  "Restore overlays in last line."
  (gkroam-put-overlays (line-beginning-position) (line-end-position)))

(defun gkroam-remove-line-overlays ()
  "Remove overlays in current line."
  (when (eq major-mode 'gkroam-mode)
    (save-excursion
      (goto-char (line-beginning-position))
      (when (re-search-forward gkroam-link-regexp (line-end-position) t)
        (with-silent-modifications
          (remove-overlays (line-beginning-position) (line-end-position)))))))

(defun gkroam-overlay-buffer ()
  "Put overlay in currnt gkroam buffer."
  (gkroam-put-overlays (line-end-position) (point-max))
  (gkroam-put-overlays (point-min) (line-beginning-position)))

;;;###autoload
(defun gkroam-toggle-brackets ()
  "Determine whether to show brackets in page link."
  (interactive)
  (if gkroam-toggle-brackets-p
      (setq gkroam-toggle-brackets-p nil)
    (setq gkroam-toggle-brackets-p t))
  (gkroam-overlay-buffer))

;;; ----------------------------------------
;; minor mode: gkroam-edit-mode

(defun gkroam-dwim-page ()
  "Get page from gkroam link, org link, region or at point."
  (let (title page)
    (cond
     ((button-at (point))
      (setq title (string-trim (button-label (button-at (point))) "#?{\\[" "\\]}")))
     ((get-text-property (point) 'htmlize-link)
      (setq page (string-trim-left
                  (plist-get (get-text-property (point) 'htmlize-link) :uri) "file:")))
     ((region-active-p)
      (setq title (buffer-substring-no-properties (region-beginning) (region-end))))
     ((thing-at-point 'word t)
      (setq title (thing-at-point 'word t)))
     (t (setq title "")))
    (unless (string-empty-p title)
      (if (or page (gkroam--get-page title))
          (cons (or page (gkroam--get-page title)) 'page)
        (cons title 'title)))))

(defun gkroam--get-content-region ()
  "Get the region of real contents.
The region is a begin position and end position cons."
  (let (beg end)
    (goto-char (point-min))
    (re-search-forward "\\[\\[file:index\\.org\\]\\[.+?\\]\\]" nil t)
    (setq beg (1+ (match-end 0)))
    (if (re-search-forward "^-----" nil t)
        (setq end (1- (match-beginning 0)))
      (setq end (point-max)))
    (cons beg end)))

(defun gkroam--get-content (page)
  "Get the real contents in PAGE.
Except mata infomation and page references."
  (let ((file (gkroam--get-file page))
        region beg end)
    (with-current-buffer (find-file-noselect file t)
      (setq region (gkroam--get-content-region))
      (setq beg (car region))
      (setq end (cdr region))
      (string-trim (buffer-substring-no-properties beg end)))))

(defun gkroam-edit-append--cons ()
  "Get the title and content cons needed to be appended to side window."
  (let ((title-or-page (car (gkroam-dwim-page)))
        (type (cdr (gkroam-dwim-page)))
        title page content)
    (when title-or-page
      (pcase type
        ('page
         (setq page title-or-page)
         (setq title (gkroam--get-title page))
         (setq content (gkroam--get-content page)))
        (_
         (setq title title-or-page)
         (setq content "")))
      (cons title content))))

(defun gkroam-edit-append--process (content)
  "Process the CONTENT of appended page to make sure the headline level is greater than one."
  (with-temp-buffer
    (insert content)
    (goto-char (point-min))
    (while (re-search-forward "^*+ " nil t)
      (backward-char 1)
      (insert "*"))
    (buffer-string)))

(defun gkroam-edit-append (title content)
  "Append TITLE and CONTENT in gkroam edit buffer."
  (goto-char (point-min))
  (re-search-forward "^*" nil t)
  (goto-char (line-beginning-position))
  (newline-and-indent 2)
  (goto-char (point-min))
  (insert (format "* %s\n%s" title content)))

(defun gkroam-edit-write--process (content)
  "Process the CONTENT, restore the headline level when write back to pages."
  (with-temp-buffer
    (insert content)
    (goto-char (point-min))
    (while (re-search-forward "^*+ " nil t)
      (backward-char 1)
      (delete-char -1))
    (buffer-string)))

(defun gkroam-edit-write-pages ()
  "Write the gkroam edit buffer contents to pages separately."
  (interactive)
  (let (title content page file plist region beg end)
    (goto-char (point-min))
    (while (re-search-forward "^* .+" nil t)
      (setq title (string-trim-left (match-string-no-properties 0) "* "))
      (setq page (gkroam--get-page title))
      (if page
          (setq file (gkroam--get-file page))
        (setq file (gkroam-new title)))
      (goto-char (line-beginning-position))
      (setq plist (cadr (org-element-headline-parser (point-max))))
      (setq beg (plist-get plist :contents-begin))
      (setq end (plist-get plist :contents-end))
      (setq content (string-trim (buffer-substring beg end)))
      (setq content (gkroam-edit-write--process content))
      (goto-char end)
      (save-excursion
        (with-current-buffer (find-file-noselect file t)
          (let (beg2 end2)
            (setq region (gkroam--get-content-region))
            (setq beg2 (car region))
            (setq end2 (cdr region))
            (delete-region beg2 end2)
            (goto-char beg2)
            (insert (format "\n%s\n" content))
            (save-buffer)
            (gkroam-overlay-buffer)))))))

(defun gkroam-reset-variables ()
  "Reset all variables gkroam edit relays on."
  (setq gkroam-edit-flag nil)
  (setq gkroam-edit-pages nil)
  (setq gkroam-return-wconf nil))

(defun gkroam-edit-finalize ()
  "Finalize current gkroam edit process, write content to pages ordinally and restore window configuration."
  (interactive)
  (gkroam-edit-write-pages)
  (kill-current-buffer)
  (set-window-configuration gkroam-return-wconf)
  (gkroam-reset-variables))

(defun gkroam-edit-kill ()
  "Abort current gkroam edit process and restore window configuration."
  (interactive)
  (kill-current-buffer)
  (set-window-configuration gkroam-return-wconf)
  (gkroam-reset-variables))

(defvar gkroam-edit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-c" #'gkroam-edit-finalize)
    (define-key map "\C-c\C-k" #'gkroam-edit-kill)
    map)
  "Keymap for `gkroam-edit-mode', a minor mode.
Use this map to set additional keybindings for when Gkroam mode is used
for a side edit buffer.")

(defvar gkroam-edit-mode-hook nil
  "Hook for the `gkroam-edit-mode' minor mode.")

(define-minor-mode gkroam-edit-mode
  "Minor mode for special key bindings in a gkroam edit buffer.
Turning on this mode runs the normal hook `gkroam-edit-mode-hook'."
  nil " Edit" gkroam-edit-mode-map
  (setq-local
   header-line-format
   (substitute-command-keys
    "\\<gkroam-edit-mode-map>Edit buffer, finish \
`\\[gkroam-edit-finalize]', abort `\\[gkroam-edit-kill]'.")))

;;;###autoload
(defun gkroam-edit ()
  "Temporary edit pages in side window."
  (interactive)
  (let* ((cons (gkroam-edit-append--cons))
         title content)
    (if (null cons)
        (progn
          (setq title (completing-read "Choose a page to edit: "
                                       (gkroam--all-titles) nil nil))
          (setq content (gkroam-edit-append--process
                         (gkroam--get-content (gkroam--get-page title)))))
      (setq title (car cons))
      (setq content (gkroam-edit-append--process (cdr cons))))
    (if (member title gkroam-edit-pages)
        (message "'%s' page is already in edit buffer!" title)
      (push title gkroam-edit-pages)
      (if (null gkroam-edit-flag)
          (progn
            (setq gkroam-return-wconf
                  (current-window-configuration))
            (delete-other-windows)
            (split-window-right)
            (other-window 1)
            (switch-to-buffer gkroam-edit-buf)
            (gkroam-edit-append title content)
            (gkroam-mode)
            (gkroam-edit-mode)
            (setq gkroam-edit-flag t))
        (select-window (get-buffer-window gkroam-edit-buf))
        (gkroam-edit-append title content)
        (gkroam-mode)
        (gkroam-edit-mode)))))

;; ----------------------------------------
;; major mode

(defun gkroam-company-bracket-p ()
  "Judge if need to company bracket link."
  (save-excursion
    (let (word)
      (setq word (thing-at-point 'word t))
      (backward-word 1)
      (backward-char 2)
      (string= (thing-at-point 'sexp t)
               (format "{[%s]}" word)))))

(defun gkroam-company-hashtag-p ()
  "Judge if need to company hashtag link."
  (save-excursion
    (skip-chars-backward "^#" (line-beginning-position))
    (and (not (= (line-beginning-position) (point)))
         (thing-at-point 'word t))))

(defun gkroam-company-slash-p ()
  "Judge if need to company slash."
  (save-excursion
    (skip-chars-backward "^/" (line-beginning-position))
    (and (not (= (line-beginning-position) (point)))
         (thing-at-point 'word t))))

(defun gkroam--complete-hashtag (title)
  "Complete hashtag with brackets for TITLE."
  (let (len)
    (when (gkroam-company-hashtag-p)
      (save-excursion
        (setq len (abs (skip-chars-backward "^#")))
        (insert "{[")
        (forward-char len)
        (insert "]}")))
    title))

(defun gkroam-completion-finish (title)
  "Function binded to `company-completion-finish-hook' after finishing complete TITLE."
  (when (gkroam-company-hashtag-p)
    (gkroam--complete-hashtag title)
    (save-buffer)))

(defun gkroam-completion-at-point ()
  "Function binded to `completion-at-point-functions'."
  (interactive)
  (let (bds beg end)
    (cond
     ((gkroam-company-bracket-p)
      (setq bds (bounds-of-thing-at-point 'list))
      (setq beg (1+ (car bds)))
      (setq end (1- (cdr bds)))
      (list beg end gkroam-pages . nil))
     ((gkroam-company-hashtag-p)
      (setq bds (bounds-of-thing-at-point 'symbol))
      (setq beg (car bds))
      (setq end (cdr bds))
      (list beg end gkroam-pages . nil))
     ((gkroam-company-slash-p)
      (setq bds (bounds-of-thing-at-point 'symbol))
      (setq beg (car bds))
      (setq end (cdr bds))
      (list beg end gkroam-slash-magics . nil)))))

(defun gkroam-set-major-mode ()
  "Set major mode to `gkroam-mode' after find file in `gkroam-root-dir'."
  (interactive)
  (when (file-equal-p
         (file-name-directory (buffer-file-name))
         (expand-file-name gkroam-root-dir))
    (gkroam-mode)))

(add-hook 'find-file-hook #'gkroam-set-major-mode)

(define-derived-mode gkroam-mode org-mode "gkroam"
  "Major mode for gkroam."
  (gkroam-link-mode)
  
  (add-hook 'completion-at-point-functions #'gkroam-completion-at-point nil 'local)
  (add-hook 'company-completion-finished-hook #'gkroam-completion-finish nil 'local)
  
  (add-hook 'gkroam-mode-hook #'gkroam-link-frame-setup)
  (add-hook 'gkroam-mode-hook #'gkroam-set-project-alist)
  (add-hook 'gkroam-mode-hook #'toggle-truncate-lines)
  (add-hook 'gkroam-mode-hook #'gkroam-overlay-buffer)
  
  (add-hook 'pre-command-hook #'gkroam-restore-line-overlays)
  (add-hook 'post-command-hook #'gkroam-remove-line-overlays)
  
  (advice-add 'org-publish-file :around #'gkroam-resolve-link)
  
  (setq gkroam-pages (gkroam--all-titles))
  (setq-local gkroam-has-link-p nil)
  (setq-local org-startup-folded nil)
  (setq-local org-return-follows-link t)
  (use-local-map gkroam-mode-map))

;; ---------------------------------
(provide 'gkroam)
;;; gkroam.el ends here

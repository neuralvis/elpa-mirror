;;; helm-w3m.el --- W3m bookmark - helm interface. -*- lexical-binding: t -*-

;; Copyright (C) 2012 ~ 2015 Thierry Volpiatto <thierry.volpiatto@gmail.com>

;; Version: 1.6.8
;; Package-Version: 20181029.726
;; Package-Commit: c15d926631198d6d759ec8881837bcca5a64963b
;; Package-Requires: ((helm "1.5") (w3m "0.0") (cl-lib "0.5") (emacs "24.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'cl-lib)
(require 'helm)
(require 'helm-utils)
(require 'helm-adaptive)
;; Some users have the emacs-w3m library in load-path
;; without having the w3m executable :-;
;; So check if w3m program is present before trying to load
;; emacs-w3m.
(when (executable-find "w3m")
  (require 'w3m-bookmark nil t))

(declare-function w3m-browse-url "w3m.el")


(defgroup helm-w3m nil
  "W3m related Applications and libraries for Helm."
  :group 'helm)

(defcustom helm-w3m-actions (helm-make-actions
                             "Browse Url"
                             (lambda (candidate)
                               (helm-w3m-browse-bookmark candidate))
                             "Browse Url new tab"
                             (lambda (candidate)
                               (helm-w3m-browse-bookmark candidate nil t))
                             "Copy Url"
                             (lambda (elm)
                               (kill-new (helm-w3m-bookmarks-get-value elm)))
                              "Browse Url Externally"
                              (lambda (candidate)
                                (helm-w3m-browse-bookmark candidate t))
                              "Delete Bookmarks"
                              (lambda (candidate)
                                (helm-w3m-delete-bookmark candidate))
                              "Rename Bookmark"
                              (lambda (candidate)
                                (helm-w3m-rename-bookmark candidate)))
  "Actions for helm-w3m bookmarks."
  :group 'helm-w3m
  :type '(alist :key-type string :value-type function))

(defface helm-w3m-bookmarks '((t (:foreground "cyan1" :underline t)))
  "Face for w3m bookmarks" :group 'helm-w3m)


(defvar w3m-bookmark-file "~/.w3m/bookmark.html")
(defvar helm-w3m-bookmarks-regexp ">\\([^><]+.[^</a>]\\)")
(defvar helm-w3m-bookmark-url-regexp "\\(https\\|http\\|ftp\\|file\\)://[^>]*")
(defvar helm-w3m-bookmarks-alist nil)
(defvar helm-source-w3m-bookmarks
  (helm-build-sync-source "W3m Bookmarks"
    :init (lambda ()
            (setq helm-w3m-bookmarks-alist
                  (helm-html-bookmarks-to-alist
                   w3m-bookmark-file
                   helm-w3m-bookmark-url-regexp
                   helm-w3m-bookmarks-regexp)))
    :candidates (lambda ()
                  (mapcar #'car helm-w3m-bookmarks-alist))
    :filtered-candidate-transformer
     '(helm-adaptive-sort
       helm-highlight-w3m-bookmarks)
    :action 'helm-w3m-actions
    :persistent-action (lambda (candidate)
                         (if current-prefix-arg
                             (helm-w3m-browse-bookmark candidate t)
                           (helm-w3m-browse-bookmark candidate nil t)))
    :persistent-help "Open URL with emacs-w3m in new tab / \
C-u \\[helm-execute-persistent-action]: Open URL with Firefox")
  "Needs w3m and emacs-w3m.

http://w3m.sourceforge.net/
http://emacs-w3m.namazu.org/")


(defun helm-w3m-bookmarks-get-value (elm)
  (replace-regexp-in-string
   "\"" "" (cdr (assoc elm helm-w3m-bookmarks-alist))))

(defun helm-w3m-browse-bookmark (elm &optional use-external new-tab)
  (let* ((fn  (if use-external 'helm-browse-url 'w3m-browse-url))
         (arg (and (eq fn 'w3m-browse-url) new-tab)))
    (funcall fn (helm-w3m-bookmarks-get-value elm) arg)))

(defun helm-highlight-w3m-bookmarks (bookmarks _source)
  (cl-loop for i in bookmarks
        collect (propertize
                 i 'face 'helm-w3m-bookmarks
                 'help-echo (helm-w3m-bookmarks-get-value i))))


(defun helm-w3m-delete-bookmark-1 (elm)
  "Delete w3m bookmark from `w3m-bookmark-file'."
  (with-current-buffer
      (find-file-noselect w3m-bookmark-file)
    (goto-char (point-min))
    (when (search-forward elm nil t)
      (forward-line 0)
      (delete-region (point)
                     (line-end-position))
      (delete-blank-lines))
    (save-buffer)
    (kill-buffer)))

(defun helm-w3m-delete-bookmark (_candidate)
  (cl-loop for bmk in (helm-marked-candidates)
           do (helm-w3m-delete-bookmark-1 bmk)))

(defun helm-w3m-rename-bookmark (elm)
  "Rename w3m bookmark in `w3m-bookmark-file'."
  (let* ((old-title (replace-regexp-in-string ">" "" elm))
         (new-title (helm-read-string "NewTitle: " old-title)))
    (with-current-buffer
        (find-file-noselect w3m-bookmark-file)
      (goto-char (point-min))
      (when (search-forward (concat elm "<") nil t)
        (goto-char (1- (point)))
        (delete-char (- (length old-title)))
        (insert new-title))
      (save-buffer)
      (kill-buffer))))

;;;###autoload
(defun helm-w3m-bookmarks ()
  "Preconfigured `helm' for w3m bookmark.

Needs w3m and emacs-w3m.

http://w3m.sourceforge.net/
http://emacs-w3m.namazu.org/"
  (interactive)
  (helm :sources `(helm-source-w3m-bookmarks
                   ,(helm-build-dummy-source "DuckDuckgo"
                      :action (lambda (candidate)
                                (w3m-browse-url
                                 (format helm-surfraw-duckduckgo-url
                                         (url-hexify-string candidate))
                                 helm-current-prefix-arg))))
        :buffer "*helm w3m bookmarks*"))


(provide 'helm-w3m)

;; Local Variables:
;; byte-compile-warnings: (not cl-functions obsolete)
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; helm-w3m.el ends here

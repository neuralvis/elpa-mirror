;;; all-the-icons-ibuffer.el --- Display icons for all buffers in ibuffer        -*- lexical-binding: t; -*-

;; Copyright (C) 2020 Vincent Zhang

;; Author: Vincent Zhang <seagle0128@gmail.com>
;; Homepage: https://github.com/seagle0128/all-the-icons-ibuffer
;; Version: 1.3.0
;; Package-Version: 20201027.758
;; Package-Commit: c41e12033712969bfa2e3e9f1c62feae866a48ac
;; Package-Requires: ((emacs "24.4") (all-the-icons "2.2.0"))
;; Keywords: convenience, icons, ibuffer

;; This file is not part of GNU Emacs.

;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;

;;; Commentary:

;; Display icons for all buffers in ibuffer.
;;
;; Install:
;; From melpa, `M-x package-install RET all-the-icons-ibuffer RET`.
;; (all-the-icons-ibuffer-mode 1)
;; or
;; (use-package all-the-icons-ibuffer-mode
;;   :ensure t
;;   :init (all-the-icons-ibuffer-mode 1))


;;; Code:

(require 'ibuffer)
(require 'all-the-icons)

(defgroup all-the-icons-ibuffer nil
  "Display icons for all buffers in ibuffer."
  :group 'all-the-icons
  :group 'ibuffer
  :link '(url-link :tag "Homepage" "https://github.com/seagle0128/all-the-icons-ibuffer"))

(defface all-the-icons-ibuffer-icon-face
  '((t (:inherit default)))
  "Face used for the icons while `all-the-icons-ibuffer-color-icon' is nil."
  :group 'all-the-icons-ibuffer)

(defcustom all-the-icons-ibuffer-color-icon t
  "Whether display the colorful icons.

It respects `all-the-icons-color-icons'."
  :group 'all-the-icons-ibuffer
  :type 'boolean)

(defcustom all-the-icons-ibuffer-icon-size 1.0
  "The default icon size in ibuffer."
  :group 'all-the-icons-ibuffer
  :type 'number)

(defcustom all-the-icons-ibuffer-icon-v-adjust 0.0
  "The default vertical adjustment of the icon in ibuffer."
  :group 'all-the-icons-ibuffer
  :type 'number)

(defcustom all-the-icons-ibuffer-human-readable-size t
  "Use human readable file size in ibuffer."
  :group 'all-the-icons-ibuffer
  :type 'boolean)

(defcustom all-the-icons-ibuffer-formats
  `((mark modified read-only ,(if (>= emacs-major-version 26) 'locked "")
          ;; Here you may adjust by replacing :right with :center or :left
          ;; According to taste, if you want the icon further from the name
          " " (icon 2 2 :left :elide)
          ,(propertize " " 'display `(space :align-to 8))
          (name 18 18 :left :elide)
          " " (size-h 9 -1 :right)
          " " (mode+ 16 16 :left :elide)
          " " filename-and-process+)
    (mark " " (name 16 -1) " " filename))
  "A list of ways to display buffer lines with `all-the-icons'.

See `ibuffer-formats' for details."
  :group 'all-the-icons-ibuffer
  :type '(repeat sexp))



;; For alignment, the size of the name field should be the width of an icon
;;;###autoload(autoload 'ibuffer-make-column-icon "all-the-icons-ibuffer")
(define-ibuffer-column icon
  (:name "  " :inline t)
  (let ((icon (if (and (buffer-file-name) (all-the-icons-auto-mode-match?))
                  (all-the-icons-icon-for-file (file-name-nondirectory (buffer-file-name))
                                               :height all-the-icons-ibuffer-icon-size
                                               :v-adjust all-the-icons-ibuffer-icon-v-adjust)
                (all-the-icons-icon-for-mode major-mode
                                             :height all-the-icons-ibuffer-icon-size
                                             :v-adjust all-the-icons-ibuffer-icon-v-adjust))))
    (if (or (null icon) (symbolp icon))
        (setq icon (all-the-icons-faicon "file-o"
                                         :face (if all-the-icons-ibuffer-color-icon
                                                   'all-the-icons-dsilver
                                                 'all-the-icons-ibuffer-icon-face)
                                         :height (* 0.9 all-the-icons-ibuffer-icon-size)
                                         :v-adjust all-the-icons-ibuffer-icon-v-adjust))
      (let* ((props (get-text-property 0 'face icon))
             (family (plist-get props :family))
             (face (if all-the-icons-ibuffer-color-icon
                       (or (plist-get props :inherit) props)
                     'all-the-icons-ibuffer-icon-face))
             (new-face `(:inherit ,face
                         :family ,family
                         :height ,all-the-icons-ibuffer-icon-size)))
        (propertize icon 'face new-face)))))

;; Human readable file size for ibuffer
;;;###autoload(autoload 'ibuffer-make-column-size-h "all-the-icons-ibuffer")
(define-ibuffer-column size-h
  (:name "Size"
   :inline t
   :props ('font-lock-face 'font-lock-comment-face)
   :header-mouse-map ibuffer-size-header-map
   :summarizer
   (lambda (column-strings)
     (let ((total 0))
       (dolist (string column-strings)
	     (setq total
	           ;; like, ewww ...
	           (+ (float (string-to-number string))
		          total)))
       (format "%.0f" total))))
  (let ((size (buffer-size)))
    (if all-the-icons-ibuffer-human-readable-size
        (file-size-human-readable size)
      (format "%s" size))))

;;;###autoload(autoload 'ibuffer-make-column-mode+ "all-the-icons-ibuffer")
(define-ibuffer-column mode+
  (:name "Mode"
   :inline t
   :header-mouse-map ibuffer-mode-header-map
   :props ('font-lock-face 'font-lock-keyword-face
                           'mouse-face 'highlight
	                       'keymap ibuffer-mode-name-map
	                       'help-echo "mouse-2: filter by this mode"))
  (format-mode-line mode-name nil nil (current-buffer)))

;;;###autoload(autoload 'ibuffer-make-column-filename-and-process+ "all-the-icons-ibuffer")
(define-ibuffer-column filename-and-process+
  (:name "Filename/Process"
   :props ('font-lock-face 'font-lock-string-face)
   :header-mouse-map ibuffer-filename/process-header-map
   :summarizer
   (lambda (strings)
     (setq strings (delete "" strings))
     (let ((procs 0)
	       (files 0))
       (dolist (string strings)
         (when (get-text-property 1 'ibuffer-process string)
           (setq procs (1+ procs)))
	     (setq files (1+ files)))
       (concat (cond ((zerop files) "No files")
		             ((= 1 files) "1 file")
		             (t (format "%d files" files)))
	           ", "
	           (cond ((zerop procs) "no processes")
		             ((= 1 procs) "1 process")
		             (t (format "%d processes" procs)))))))
  (let ((proc (get-buffer-process buffer))
	    (filename (ibuffer-make-column-filename buffer mark)))
    (if proc
	    (concat (propertize (format "(%s %s)" proc (process-status proc))
			                'font-lock-face 'italic
                            'ibuffer-process proc)
		        (if (> (length filename) 0)
		            (format " %s" filename)
		          ""))
      filename)))

(defvar all-the-icons-ibuffer-old-formats ibuffer-formats)

;;;###autoload
(define-minor-mode all-the-icons-ibuffer-mode
  "Display icons for all buffers in ibuffer."
  :lighter nil
  :global t
  (if all-the-icons-ibuffer-mode
      (setq ibuffer-formats all-the-icons-ibuffer-formats)
    (setq ibuffer-formats all-the-icons-ibuffer-old-formats)))

(provide 'all-the-icons-ibuffer)

;;; all-the-icons-ibuffer.el ends here

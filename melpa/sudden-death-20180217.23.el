;;; sudden-death.el --- Totsuzen-no-Shi

;; Copyright 2012 yewton

;; Author: yewton
;; URL: https://github.com/yewton/sudden-death.el
;; Package-Version: 20180217.23
;; Package-Commit: 791a63d3f4df192e71f4232a9a4c5588f4b43dfb
;; Version: 0.2.1

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Enclose the active region with a fancy fence.
;; cf. https://github.com/aquarla/sudden_death

;; To install, save this on your load path and add the following to
;; your .emacs file:
;;
;; (require 'sudden-death)

;; To use, activate region and type M-x sudden-death.

;;; Code:

(defconst sudden-death-fence-n (decode-char 'ucs #x4EBA))
(defconst sudden-death-fence-nw (decode-char 'ucs #xFF3F))
(defconst sudden-death-fence-w (decode-char 'ucs #xFF1E))
(defconst sudden-death-fence-sw (decode-char 'ucs #xFFE3))
(defconst sudden-death-fence-s (decode-char 'ucs #xFF39))
(defconst sudden-death-fence-se (decode-char 'ucs #xFFE3))
(defconst sudden-death-fence-e (decode-char 'ucs #xFF1C))
(defconst sudden-death-fence-ne (decode-char 'ucs #xFF3F))
(defconst sudden-death-fence-space (decode-char 'ucs #x3000))

;;;###autoload
(defun sudden-death ()
  "Enclose the active region with a fancy fence."
  (interactive)
  (when (region-active-p)
    (let ((lines (split-string (buffer-substring-no-properties (region-beginning) (region-end)) "\n"))
          (max-width 0)
          top middle bottom result
          (left (string sudden-death-fence-w sudden-death-fence-space))
          (right (string sudden-death-fence-space sudden-death-fence-e))
          )
      (mapc
           #'(lambda (x)
               (setq max-width (max max-width (string-width x)))) lines)
      (setq top (make-string (/ max-width 2) sudden-death-fence-n))
      (setq middle
            (mapconcat
             #'(lambda (x)
                 (concat left x (make-string (- max-width (string-width x)) ?\ ) right))
             lines "\n"))
      (setq bottom (make-string (/ max-width 2) sudden-death-fence-s))
      (setq result
            (concat (string sudden-death-fence-nw sudden-death-fence-n)
                    top
                    (string sudden-death-fence-n sudden-death-fence-ne)
                    "\n"
                    middle
                    "\n"
                    (string sudden-death-fence-sw sudden-death-fence-s)
                    bottom
                    (string sudden-death-fence-s sudden-death-fence-se)))
      (kill-region (region-beginning) (region-end))
      (insert result))))

;; Setup/Activation
(provide 'sudden-death)
;;; sudden-death.el ends here

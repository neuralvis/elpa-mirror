;;; mouse-slider-mode.el --- scale numbers dragged under the mouse -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Christopher Wellons <mosquitopsu@gmail.com>
;; URL: https://github.com/skeeto/mouse-slider-mode
;; Package-Version: 20161021.1914
;; Package-Commit: b3c19cd231edecce76787c5a9bbe5e4046d91f88
;; Version: 0.1
;; Package-Requires: ((emacs "24.3") (cl-lib "0.3"))

;;; Commentary:

;; With this minor mode enabled in a buffer, right-clicking and
;; dragging horizontally with the mouse on any number will
;; increase/decrease it. It's works like this (video is not actually
;; about this minor mode):

;;   http://youtu.be/FpxIfCHKGpQ

;; If an evaluation function is defined for the current major mode in
;; `mouse-slider-mode-eval-funcs', the local expression will also be
;; evaluated as the number is updated. For example, to add support for
;; [Skewer](https://github.com/skeeto/skewer-mode) in
;; [js2-mode](https://github.com/mooz/js2-mode),

;;   (add-to-list 'mouse-slider-mode-eval-funcs
;;                '(js2-mode . skewer-eval-defun))

;; The variable `mouse-slider-eval' enables/disables this evaluation
;; step.

;;; Code:

(require 'cl-lib)
(require 'thingatpt)

(defvar mouse-slider-scale 1500
  "Rate at which numbers scale. Smaller means faster.")

(defvar mouse-slider-direction :horizontal
  "Selects either :horizontal or :vertical for action direction.")

(defvar mouse-slider-mode-eval-funcs
  `((emacs-lisp-mode . ,(apply-partially #'eval-defun nil)))
  "Alist of evaluation functions to run after scaling numbers in
various major modes.")

(defvar-local mouse-slider-eval t
  "When true, run the evaluation function listed in
`mouse-slider-mode-eval-funcs' after updating numbers.")

(defvar mouse-slider-mode-map
  (let ((map (make-sparse-keymap)))
    (prog1 map
      (define-key map (kbd "<down-mouse-3>") 'mouse-slider-slide)))
  "Keymap for mouse-slider-mode.")

;;;###autoload
(define-minor-mode mouse-slider-mode
  "Scales numbers when they are right-click dragged over."
  :keymap mouse-slider-mode-map
  :lighter " MSlider")

(defvar mouse-slider-number-regexp
  "[-+]?[0-9]*\\.?[0-9]+\\([eE][-+]?[0-9]+\\)?"
  "Regular expression used to match numbers.")

(defun mouse-slider-number-bounds ()
  "Return the bounds of the number at point."
  (save-excursion
    (while (and (not (bobp)) (looking-at-p mouse-slider-number-regexp))
      (backward-char 1))
    (unless (bobp) (forward-char 1))
    (let ((start (point)))
      (re-search-forward mouse-slider-number-regexp)
      (cons start (point)))))

(cl-defun mouse-slider-replace-number (value)
  "Replace the number at point with VALUE."
  (save-excursion
    (let ((region (mouse-slider-number-bounds)))
      (delete-region (car region) (cdr region))
      (goto-char (car region))
      (insert (format "%s" value)))))

(defun mouse-slider-round (value decimals)
  "Round VALUE to DECIMALS decimal places."
  (let ((n (float (expt 10 decimals))))
    (/ (round (* value n)) n)))

(defun mouse-slider-scale (base pixels)
  "Scale BASE by a drag distance of PIXELS."
  (let* ((half-total-range (* 2.0 (1+ (abs base))))
         (drag-distance-value (* half-total-range
                                 (/ pixels (float mouse-slider-scale)))))
    (+ base drag-distance-value)))

(defun mouse-slider-slide (event)
  "Handle a mouse slider event by continuously updating the
number where the mouse drag began."
  (interactive "e")
  (save-excursion
    (goto-char (posn-point (cl-second event)))
    (let ((base (thing-at-point 'number)))
      (when base
        (cl-flet ((xy (event) (let ((pos (posn-x-y (cl-second event))))
                                (cl-ecase mouse-slider-direction
                                  (:horizontal (car pos))
                                  (:vertical   (* -1 (cdr pos)))))))
          (track-mouse
            (cl-loop for movement = (read-event)
                     while (mouse-movement-p movement)
                     ;; left means decrease, right means increase
                     for diff = (+ (xy movement) (* -1 (xy event)))
                     for value = (mouse-slider-scale base diff)
                     when (not (zerop (xy movement)))
                     do (mouse-slider-replace-number
                         (if (integerp base)
                             ;; integers remain integers
                             (round value)
                           ;; round to 2 decimal places
                           (mouse-slider-round value 2)))
                     ;; Eval
                     for f =
                     (cdr (assoc major-mode mouse-slider-mode-eval-funcs))
                     when (and f mouse-slider-eval)
                     do (funcall f))))))))

(defun mouse-slider-toggle-eval ()
  (interactive)
  (setq mouse-slider-eval (not mouse-slider-eval))
  (message "mouse-slider-eval: %s"
           (if mouse-slider-eval "enabled" "disabled")))

(provide 'mouse-slider-mode)

;;; mouse-slider-mode.el ends here

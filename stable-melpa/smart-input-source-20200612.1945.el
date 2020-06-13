;;; smart-input-source.el --- Switch OS native input source smartly -*- lexical-binding: t; -*-

;; URL: https://github.com/laishulu/emacs-smart-input-source
;; Package-Version: 20200612.1945
;; Package-Commit: 89777801e07176d66c2b7d7b875808001682f6c2
;; Created: March 27th, 2020
;; Keywords: convenience
;; Package-Requires: ((names "0.5") (emacs "25"))
;; Version: 1.0

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; This package provide modes to switch OS native input source smartly.
;; For more information see the README in the GitHub repo.

;;; Code:

;; `define-namespace' is autoloaded, so there's no need to require `names'.
;; However, requiring it here means it will also work for people who don't
;; install through package.el.
(eval-when-compile (require 'names))
(require 'subr-x)

(define-namespace smart-input-source-

(defvar external-ism "macism"
  "Path of external ism.")

(defvar do-get-input-source nil
  "Function to get the current input source.

Should return a string which is the id of the input source.")

(defvar do-set-input-source nil
  "Function to set the input source.

Should accept a string which is the id of the input source.")

(defvar english-pattern "[a-zA-Z]"
  "Pattern to identify a character as english.")

(defvar english-input-source "com.apple.keylayout.US"
  "Input source for english.")

(defvar start-with-english t
  "Switch to english when `global-auto-english-mode' enabled.")

(defvar other-pattern "\\cc"
  "Pattern to identify a character as other lang.")
(make-variable-buffer-local (quote other-pattern))

(defvar blank-pattern "[:blank:]"
  "Pattern to identify a character as blank.")
(make-variable-buffer-local (quote blank-pattern))

(defvar other-input-source "com.sogou.inputmethod.sogou.pinyin"
  "Input source for other lang.")
(make-variable-buffer-local (quote other-input-source))

(defvar aggressive-line t
  "Aggressively detect context across blank lines.")
(make-variable-buffer-local (quote aggressive-line))

(defvar tighten-other-punctuation t
  "Auto delete blank between inline english and other lang puctuation.")
(make-variable-buffer-local (quote tighten-other-punctuation))

(defface inline-english-face
  '()
  "Face of the inline english region overlay."
  :group 'smart-input-source)

(set-face-attribute
 'smart-input-source-inline-english-face nil
 :foreground (face-attribute 'font-lock-constant-face :foreground)
 :inverse-video t)

;;
;; Following symbols are not supposed to be used directly by end user.
;;

(declare-function evil-normal-state-p "ext:evil-states.el" (&optional state) t)
(declare-function evil-visual-state-p "ext:evil-states.el" (&optional state) t)
(declare-function evil-motion-state-p "ext:evil-states.el" (&optional state) t)
(declare-function evil-operator-state-p "ext:evil-states.el" (&optional state) t)
(declare-function company--active-p "ext:company.el" () t)
(declare-function mac-input-source "ext:macfns.c" (&optional SOURCE FORMAT) t)
(declare-function mac-select-input-source "ext:macfns.c"
                  (SOURCE &optional SET-KEYBOARD-LAYOUT-OVERRIDE-P) t)

;;
;; Following codes are mainly about input source manager
;;
(defconst ENGLISH 1)
(defconst OTHER 2)

;; Emacs mac port builtin input source manager
(defconst ISM-EMP 1)

(defvar -ism nil "The input source manager.")
(defvar -ism-inited nil "Input source manager initialized.")

(defun -init-ism ()
  "Init input source manager."
  (when (and (string= (window-system) "mac")
             (fboundp 'mac-input-source))
    (setq -ism ISM-EMP))

  (when (and (not -ism) external-ism)
    (let ((ism-path (executable-find external-ism)))
      (setq -ism ism-path)))

  (when -ism
    (unless (functionp do-get-input-source)
      (setq do-get-input-source (-mk-get-input-source-fn)))

    (unless (functionp do-set-input-source)
      (setq do-set-input-source (-mk-set-input-source-fn))))

  (setq -ism-inited t))

(defun -mk-get-input-source-fn ()
  "Make a function to be bound to `do-get-input-source'."
  (when -ism
    (if (equal -ism ISM-EMP)
        #'mac-input-source
      (lambda ()
        (string-trim (shell-command-to-string -ism))))))

(defun -mk-set-input-source-fn ()
  "Make a function to be bound to `do-set-input-source'."
  (when -ism
    (if (equal -ism ISM-EMP)
        (lambda (source) (mac-select-input-source source))
      (lambda (source)
        (string-trim
         (shell-command-to-string (concat -ism " " source)))))))

(defun -get-input-source ()
  "Get the input source id."
  (when (functionp do-get-input-source)
    (funcall do-get-input-source)))

(defun -set-input-source (lang)
  "Set the input source according to lang LANG, avoiding unnecessary switch."
  (when (functionp do-set-input-source)
    (let ((ENGLISH_SOURCE english-input-source)
          (OTHER_SOURCE other-input-source))
      (pcase (-get-input-source)
        ((pred (equal ENGLISH_SOURCE))
         (when (equal lang OTHER)
           (funcall do-set-input-source OTHER_SOURCE)))
        ((pred (equal OTHER_SOURCE))
         (when (equal lang ENGLISH)
           (funcall do-set-input-source ENGLISH_SOURCE)))))))

(defun set-input-source-english ()
  "Set input source to `english-input-source'."
  (interactive)
  (unless -ism-inited
    (-init-ism))
  (when -ism
    (-set-input-source ENGLISH)))

(defun set-input-source-other ()
  "Set input source to `other-input-source'."
  (interactive)
  (unless -ism-inited
    (-init-ism))
  (when -ism
    (-set-input-source OTHER)))

;;;###autoload
(define-minor-mode global-auto-english-mode
  "Automatically select english input source when startup or with evil.

- For GUI session of ~emacs mac port~, use native API to select input source
  for better performance.
- If ~emacs mac port~ is unavailable, or in terminal session, use external ism
  tool to select input source.
- If no ism found, then do nothing."
  :global t
  :init-value nil
  (unless -ism-inited
    (-init-ism))

  (when -ism
    (if global-auto-english-mode
        (progn
          (when start-with-english (set-input-source-english))
          (when (featurep 'evil)
            (add-hook 'evil-insert-state-exit-hook
                      #'smart-input-source-set-input-source-english)))
      (when (featurep 'evil)
        (remove-hook 'evil-insert-state-exit-hook
                     #'smart-input-source-set-input-source-english)))))

;;
;; Following codes are mainly about follow-context-mode
;;

(defun -string-match-p (regexp str &optional start)
  "Robust wrapper of `string-match-p'.

Works when REGEXP or STR is not a string REGEXP, STR, START all has the same
meanings as `string-match-p'."
  (and (stringp regexp)
       (stringp str)
       (string-match-p regexp str start)))

(cl-defstruct back-detect ; result of backward detect
  to ; point after first non-blank char in the same line
  char ; first non-blank char at the same line (just before position `to')
  cross-line-to ; point after first non-blank char cross lines
  cross-line-char ; first non-blank char cross lines before the current position
  )

(defun -back-detect-chars ()
  "Detect char backward by two steps.

  First backward skip blank in the current line,
  then backward skip blank across lines."
  (save-excursion
    (skip-chars-backward blank-pattern)
    (let ((to (point))
          (char (char-before (point))))
      (skip-chars-backward (concat blank-pattern "[:cntrl:]"))
      (let ((cross-line-char (char-before (point))))
        (make-back-detect :to to
                          :char (when char (string char))
                          :cross-line-to (point)
                          :cross-line-char (when cross-line-char
                                             (string cross-line-char)))))))

(cl-defstruct fore-detect ; result of forward detect
  to ; point before first non-blank char in the same line
  char ; first non-blank char at the same line (just after position `to')
  cross-line-to ; point before first non-blank char cross lines
  cross-line-char ; first non-blank char cross lines after the current position
  )

(defun -fore-detect-chars ()
  "Detect char forward.

  Forward skip blank in the current line."
  (save-excursion
    (skip-chars-forward blank-pattern)
    (let ((to (point))
          (char (char-after (point))))
      (skip-chars-forward (concat blank-pattern "[:cntrl:]"))
      (let ((cross-line-char (char-after (point))))
        (make-fore-detect :to to
                          :char (when char (string char))
                          :cross-line-to (point)
                          :cross-line-char (when cross-line-char
                                             (string cross-line-char)))))))

(defun -guess-context ()
  "Guest the lang context for the current point."
  (let* ((back-detect (-back-detect-chars))
         (fore-detect (-fore-detect-chars))

         (back-to (back-detect-to back-detect))
         (back-char (back-detect-char back-detect))
         (cross-line-back-to (back-detect-cross-line-to back-detect))
         (cross-line-back-char (back-detect-cross-line-char back-detect))

         (fore-to (fore-detect-to fore-detect))
         (fore-char (fore-detect-char fore-detect))
         (cross-line-fore-to (fore-detect-cross-line-to fore-detect))
         (cross-line-fore-char (fore-detect-cross-line-char fore-detect)))

    (cond

     ;; [^][blank][other lang]
     ((and (< fore-to (line-end-position))
           (> fore-to (point))
           (-string-match-p other-pattern fore-char))
      ENGLISH)

     ;; [line beginning][^][english]
     ;; [english][^][english]
     ;; [not english][blank][^][english]
     ((and (or (= back-to (line-beginning-position))
               (and (= back-to (point))
                    (-string-match-p english-pattern back-char))
               (and (< back-to (point))
                    (not (-string-match-p english-pattern back-char))))
           (< fore-to (line-end-position))
           (= fore-to (point))
           (-string-match-p english-pattern fore-char))
      ENGLISH)

     ;; [line beginning][^][other lang]
     ;; [other lang][^][other lang]
     ;; [not other lang][blank][^][other lang]
     ((and (or (= back-to (line-beginning-position))
               (and (= back-to (point))
                    (-string-match-p other-pattern back-char))
               (and (< back-to (point))
                    (not (-string-match-p other-pattern back-char))))
           (< fore-to (line-end-position))
           (= fore-to (point))
           (-string-match-p other-pattern fore-char))
      OTHER)

     ;; [english][^][line end]
     ((and (= back-to (point))
           (-string-match-p english-pattern back-char)
           (= fore-to (line-end-position)))
      ENGLISH)

     ;; [other][^][line end]
     ((and (= back-to (point))
           (-string-match-p other-pattern back-char)
           (= fore-to (line-end-position)))
      OTHER)

     ;; [english: include the previous line][blank][^]
     ((and (or aggressive-line
               (> cross-line-back-to (line-beginning-position 0)))
           (< cross-line-back-to (line-beginning-position))
           (-string-match-p english-pattern cross-line-back-char))
      ENGLISH)

     ;; [other lang: include the previous line][blank][^]
     ((and (or aggressive-line
               (> cross-line-back-to (line-beginning-position 0)))
           (< cross-line-back-to (line-beginning-position))
           (-string-match-p other-pattern cross-line-back-char))
      OTHER)

     ;; [^][blank][english: include the next line]
     ((and (or aggressive-line
               (< cross-line-fore-to (line-end-position 2)))
           (> cross-line-fore-to (line-end-position))
           (-string-match-p english-pattern cross-line-fore-char))
      ENGLISH)

     ;; [^][blank][other lang: include the next line]
     ((and (or aggressive-line
               (< cross-line-fore-to (line-end-position 2)))
           (> cross-line-fore-to (line-end-position))
           (-string-match-p other-pattern cross-line-fore-char))
      OTHER))))


;;;###autoload
(define-minor-mode follow-context-mode
  "Switch input source smartly according to context.

- For GUI session of ~emacs mac port~, use native API to select input source
  for better performance.
- If ~emacs mac port~ is unavailable, or in terminal session, use external ism
  tool to select input source.
- If no ism found, then do nothing."
  :init-value nil

  (unless -ism-inited
    (-init-ism))

  (when -ism
    (if follow-context-mode
        (when (featurep 'evil)
          (add-hook 'evil-insert-state-entry-hook
                    #'smart-input-source-follow-context))
      (when (featurep 'evil)
        (remove-hook 'evil-insert-state-entry-hook
                     #'smart-input-source-follow-context)))))

(defun follow-context ()
  "Follow the context to switch input source."
  (let ((context (-guess-context)))
    (when context
      (-set-input-source context))))

;;
;; Following codes are mainly about the inline english region overlay
;;

(defvar -inline-overlay nil
  "The active inline overlay.")
(make-variable-buffer-local (quote -inline-overlay))

(defvar -last-inline-overlay-start-position nil
  "Start position of the last inline overlay (already deactivated).")
(make-variable-buffer-local (quote -last-inline-overlay-start-position))

(defvar -last-inline-overlay-end-position nil
  "End position of the last inline overlay (already deactivated).")
(make-variable-buffer-local (quote -last-inline-overlay-end-position))

;;;###autoload
(define-minor-mode inline-english-mode
  "English overlay mode for mixed language editing.

- For GUI session of ~emacs mac port~, use native API to select input source
  for better performance.
- If ~emacs mac port~ is unavailable, or in terminal session, use external ism
  tool to select input source.
- If no ism found, then do nothing."
  :init-value nil

  (unless -ism-inited
    (-init-ism))

  (when -ism
    (if inline-english-mode
        (add-hook 'post-self-insert-hook
                  #'smart-input-source-check-to-activate-overlay)
      (remove-hook 'post-self-insert-hook
                   #'smart-input-source-check-to-activate-overlay))))

(defun check-to-activate-overlay()
  "Check whether to activate the inline english region overlay.

Check the context to determine whether the overlay should be activated or not,
if the answer is yes, then activate the /inline english region/, set the
input source to English, and then return ~t~."
  (when (and inline-english-mode
             (not (overlayp -inline-overlay))
             (not (button-at (point)))
             (not (and (featurep 'evil)
                       (or (evil-normal-state-p)
                           (evil-visual-state-p)
                           (evil-motion-state-p)
                           (evil-operator-state-p)))))
    (let* ((back-detect (-back-detect-chars))
           (back-to (back-detect-to back-detect))
           (back-char (back-detect-char back-detect)))
      ;; [other lang][blank][^]
      (when (and (> back-to (line-beginning-position))
                 (< back-to (point))
                 (-string-match-p other-pattern back-char))
        (activate-inline-overlay back-to)
        (set-input-source-english)
        t))))

(defun activate-inline-overlay (start)
  "Activate the inline english region overlay from START."
  (when (overlayp -inline-overlay)
    (delete-overlay -inline-overlay))
  (setq -inline-overlay (make-overlay start (point) nil t t ))
  (overlay-put -inline-overlay 'face 'smart-input-source-inline-english-face)
  (overlay-put -inline-overlay 'keymap
               (let ((keymap (make-sparse-keymap)))
                 (define-key keymap (kbd "RET")
                   'smart-input-source-deactivate-inline-overlay)
                 (define-key keymap (kbd "<return>")
                   'smart-input-source-deactivate-inline-overlay)
                 keymap))
  (setq -last-inline-overlay-start-position nil)
  (setq -last-inline-overlay-end-position nil)
  (add-hook 'post-command-hook
            #'smart-input-source-check-to-deactivate-overlay)
  (message "Press <RETURN> to close inline english region."))

(defun check-to-deactivate-overlay ()
  "Check whether to deactivate the inline english region overlay."
  (when (and inline-english-mode (overlayp -inline-overlay))
    (setq -last-inline-overlay-start-position (overlay-start -inline-overlay))
    (setq -last-inline-overlay-end-position (overlay-end -inline-overlay))
    (when (or (= -last-inline-overlay-start-position
                 -last-inline-overlay-end-position)
              (or(< (point) -last-inline-overlay-start-position)
                 (> (point) -last-inline-overlay-end-position)))
      (deactivate-inline-overlay))))

(defun deactivate-inline-overlay ()
  "Deactivate the inline english region overlay."
  (interactive)

  ;; company
  (if (and (featurep 'evil)
           (company--active-p))
      (company-complete-selection)

    ;; clean up
    (remove-hook 'post-command-hook
                 #'smart-input-source-check-to-deactivate-overlay)
    (add-hook 'post-self-insert-hook
              #'smart-input-source-check-to-tighten-other-punctuation)
    (when (overlayp -inline-overlay)
      (delete-overlay -inline-overlay)
      (setq -inline-overlay nil))

    ;; select input source
    (let* ((start -last-inline-overlay-start-position)
           (end -last-inline-overlay-end-position)
           (back-detect (-back-detect-chars))
           (back-to (back-detect-to back-detect)))

      ;; [:blank inline overlay:]^
      ;; [:with trailing blank :]^
      (when (and start end
                 (or (= back-to start)
                     (and (> back-to start)
                          (< back-to end)
                          (< back-to (point)))))
        (set-input-source-other)))))

(defun check-to-tighten-other-punctuation ()
  "Check to delete blank between inline english and other lang puctuation."
  (remove-hook 'post-self-insert-hook
               #'smart-input-source-check-to-tighten-other-punctuation)
  (when (and -last-inline-overlay-end-position
             (= -last-inline-overlay-end-position (1- (point))))
    (let ((char (char-before (point))))
      (when (and (-string-match-p "[[:punct:]]" (string char))
                 (-string-match-p other-pattern (string char)))
        (save-excursion
          (backward-char)
          (let ((end (point)))
            (skip-chars-backward blank-pattern)
            (let ((start (point)))
              (delete-region start end))))))))

(define-minor-mode mode
  "Switch input source smartly.

Just for lazy user, at the cost of inconsistent logic on use of the global mode
`global-auto-english-mode'. It's highly recommended to use 
`smart-input-source-global-auto-english-mode',
`smart-input-source-inline-english-mode'
`smart-input-source-follow-context-mode'
separatly instead of this all-in-one mode.
"
  :init-value nil

  (unless -ism-inited
    (-init-ism))

  (when -ism
    (if mode
        (progn
          (unless global-auto-english-mode
            (global-auto-english-mode t))
          (inline-english-mode t)
          (follow-context-mode t))
      ;; only turn off buffer local mode
      (inline-english-mode -1)
      (follow-context-mode -1))))

;; end of namespace
)

(provide 'smart-input-source)
;;; smart-input-source.el ends here

;;; package-filter.el --- package archive whitelist and blacklist

;; Copyright 2012-2014 Donald Ephraim Curtis
;; Copyright 2012-2014 Steve Purcell
;;
;; Author: Donald Ephraim Curtis <dcurtis@milkbox.net>
;; URL: https://github.com/milkypostman/package-filter
;; Package-Version: 20161122.719
;; Package-Commit: bc73b41aea1d65ca44ef1593ca13126df9bbb39e
;; Version: 0.3

;;; Commentary:

;; **** Obsolete since Emacs 24.4: Users should customize or otherwise
;; **** modify the new `package-pinned-packages` variable instead.

;; This package adds functionality to `package.el` to allow creating
;; a whitelist or blacklist of packages for a specific repository.
;; This allows for disabling all packages from a specific repository
;; and only enabling certain packages, or simply blacklist a certain
;; subset of packages.

;;; Code:

;;;###autoload
(defcustom package-archive-enable-alist nil
  "Optional Alist of enabled packages used by `package-filter'.
The format is (ARCHIVE . PACKAGE ...), where ARCHIVE is a string
matching an archive name in `package-archives', PACKAGE is a
symbol of a package in ARCHIVE to enable.

If no ARCHIVE exists in the alist, all packages are enabled."
  :group 'package
  :type '(alist :key-type string :value-type (repeat symbol)))


;;;###autoload
(defcustom package-archive-exclude-alist nil
  "Alist of packages excluded by `package-filter'.
The format is (ARCHIVE . PACKAGE ...), where ARCHIVE is a string
matching an archive name in `package-archives', PACKAGE is a
symbol of a package in that archive to exclude.

Any specified package is excluded regardless of the value of
`package-archive-enable-alist'"
  :group 'package
  :type '(alist :key-type string :value-type (repeat symbol)))


;;;###autoload
(defcustom package-filter-function 'package-filter
  "Optional predicate function used to internally
filter packages used by package.el.

Return nil to filter a function from the list.

The function is called with the arguments PACKAGE VERSION ARCHIVE, where
PACKAGE is a symbol, VERSION is a vector as produced by `version-to-list', and
ARCHIVE is the string name of the package archive."
  :group 'package
  :type 'function)


;;;###autoload
(defadvice package-compute-transaction
  (before
   package-compute-transaction-reverse (package-list requirements)
   activate compile)
  "reverse the requirements"
  (setq requirements (reverse requirements)))


;;;###autoload
(defadvice package--add-to-archive-contents
  (around package-filter-add-to-archive-contents (package archive)
          activate compile)
  "Add filtering of available packages using `package-filter-function',
if non-nil."
  (when (and package-filter-function
             (funcall package-filter-function
                      (car package)
                      (package-desc-vers (cdr package))
                      archive))
    ad-do-it))


;;;###autoload
(defun package-filter (package version archive)
  "Check package against enabled and excluded list for the `archive'.

Filter packages not in the associated list for `archive' in
`package-archive-enable-alist'.

Filter packages in the associated list for `archive' in
`package-archive-exclude-alist'."
  (let ((enable-rules (cdr (assoc archive package-archive-enable-alist)))
        (exclude-rules (cdr (assoc archive package-archive-exclude-alist))))
    (and (not (memq package exclude-rules))
         (or (not enable-rules)
             (memq package enable-rules)))))



(provide 'package-filter)

;;; package-filter.el ends here

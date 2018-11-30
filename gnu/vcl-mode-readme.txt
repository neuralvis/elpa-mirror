Emacs support for Varnish's configuration language:
https://varnish-cache.org/docs/trunk/users-guide/vcl.html
This version of vcl-mode supports VCL-4.0.

The features provided are auto-indentation (based on CC-mode's
engine), keyword highlighting, and matching of {"..."} multi-line
string delimiters.

If you need support for VCL-2.0, you might have more luck with the older
package: https://github.com/ssm/elisp/blob/master/vcl-mode.el

Installation:
You may wish to use precompiled version of the mode. To create it
run:
   emacs -batch -f batch-byte-compile vcl-mode.el
Install the file vcl-mode.elc (and, optionally, vcl-mode.el) to
a directory in your Emacs load-path.

Customization:
 To your .emacs or site-start.el add:
 (autoload 'vcl-mode "vcl-mode" "Major mode for Varnish VCL sources" t)
 (add-to-list 'auto-mode-alist (cons (purecopy "\\.vcl\\'")  'vcl-mode))
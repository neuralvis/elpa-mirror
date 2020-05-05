This library provides links of symbols (functions, variables,
faces) within Emacs' Info viewer to their help documentation.  This
linking is done, when the symbol names in texinfo documentations
(like the Emacs- and Elisp manual) are `quoted-symbols' or
functions which are prefixed by M-x, for example "... use M-x
function-name ..." or "... use `M-x function-name' ...".  The
symbol names must be known to Emacs, i.e. their names are stored in
the variable `obarray'.

You can follow these additional links with the usual Info
keybindings.  The customisation variable
`mouse-1-click-follows-link' is influencing the clicking behavior
(and the tooltips) of the links, the variable's default is 450
(milli seconds) setting it to nil means only clicking with mouse-2
is following the link (hint: Drew Adams).

The code uses mostly mechanisms from Emacs' lisp/help-mode.el file.

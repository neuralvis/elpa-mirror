This library provides links of symbols (functions, variables,
faces) within Emacs' Info viewer to their help documentation.  This
linking is done, when the symbol names in texinfo documentations
(like the Emacs- and Elisp manual) are

1. Quoted symbol names like `quoted-symbol' or:

2. Function names are prefixed by M-x, for example M-x
function-name or are quoted and prefixed like `M-x function-name'.

3. Function names appearing behind the following forms, which
occur, for example, in the Elisp manual:

  -- Special Form: function-name
  -- Command:
  -- Function:
  -- Macro:

4. And variables names behind the following text:

  -- User Option: variable-name
  -- Variable:

 In any case all symbol names must be known to Emacs, i.e. their
names are found in the variable `obarray'.

You can follow the additional links with the usual Info
keybindings.  The customisation variable
`mouse-1-click-follows-link' is influencing the clicking behavior
(and the tooltips) of the links, the variable's default is 450
(milli seconds) setting it to nil means only clicking with mouse-2
is following the link (hint: Drew Adams).

The link color of symbols - referencing their builtin documentation
- is distinct from links which are referencing further Info
 documentation.

Inform is checking if the Info documents are relevant Elisp and
Emacs related files to avoid false positives.  Please see the
customization variable `inform-none-emacs-or-elisp-documents'.

The code uses mostly mechanisms from Emacs' lisp/help-mode.el file.

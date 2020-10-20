For some of us old neck beards who learned to write software on
pucch cards and print out our code and output on wide line
printers.  When reading long rows of text across a 14 7/8" page it
was helpful to have alternating bands of subtle background coloring
to guide your eyes across the line.  This is also referred to as
`zebra striping` and is enabled in on PostScript output in
`ps-print.el' by enabling the `ps-zebra-stripes' setting.

To enable `greenbar-mode' in your `comint-mode' buffers, add the
following to your Emacs configuration:

    (add-hook 'comint-mode-hook #'greenbar-mode)

If you want to enable `greenbar-mode' only in a single mode derived
from `comint-mode', then you need to add `greenbar-mode' only to
the desired derive mode hook.  Adding `greenbar-mode' to
`comint-mode-hook' enables it for all comint derived modes.

The variable `greenbar-color-theme' is a list of predefined bar
background colors.  Each element of the list is a list: the first
member of which is a symbol that is the name of the theme; the rest
of the list are color names which are used as background colors for
successive bands of lines.

The variable `greenbar-color-list' controls which set of color bars
are to be applied.  The value is either a name from color theme
defined in `greenbar-color-themes' or it is a list of color names.
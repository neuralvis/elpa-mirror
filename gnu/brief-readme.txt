This Extended Brief editor emulator was originally based on the
CRiSP mode emulator (listed below), with extensive rewriting over
17+ years.  Almost all of the original Brief 3.1 Editor keys are
implemented and extended.

A lot of editor behaviors were also adapted to Emacs.  One example
is that this Brief emulator is able to respect `visual-line-mode',
`toggle-truncate-lines' and hidden/abbreviated mode texts (which
usually shown as "..." in Emacs) such as org-mode, hideshow mode
and hideif mode (hide C/C++ "#ifdef" conditional compilation units,
another package that I had rewritten).  When texts are hidden at
cursor line, Brief line-oriented commands like line-cut, line-copy,
line-deletion ... will operate on all hidden lines.  For a complete
description of the functions extended, search the "brief.el" source
code for ";;; Brief Extension:".  Main TOC is:

 * Visual mode, line truncation and hidden texts
 * Fast line number computation cache
 * Huge clipboard/Xselection texts
 * External Xselection helper programs `xsel' and `xclip'
 * Fast cursor movement
 Key Binding Compatibility Note
 Platform Compatibility Notes
 Enabling Brief Mode
 Cygwin 2.x Users

Based CRiSP version info:
 CRiSP mode from XEmacs: revision 1.34 at 1998/08/11 21:18:53.

  CRiSP mode was created on 01 Mar 1996 by
  "Gary D. Foster <gfoster@suzieq.ml.org>"
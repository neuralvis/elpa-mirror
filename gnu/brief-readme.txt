This Brief editor emulator was originally based on the CRiSP mode
emulator (listed below), with extensive rewriting.

 CRiSP mode from XEmacs: revision 1.34 at 1998/08/11 21:18:53.

  CRiSP mode was created on 01 Mar 1996 by
  "Gary D. Foster <gfoster@suzieq.ml.org>"

There is also an Emacs version of "crisp.el" which is now obsolete
but still (temporarily) exists in the Emacs source code repository
at "<emacs>/src/lisp/obsolete/crisp.el".  In case of it being
removed from Emacs source tree someday, I moved the whole
development history from Emacs source into ELPA repository at
"<elpa>/packages/crisp".  To check the whole development history
log you need to clone the ELPA git repository, then go to
sub-directory "packages/crisp" and type the command
"git log --follow crisp.el".  Notice the "--follow" argument,
lacking it git will only give you the history "after" the
directory structure changed, which was introduced when moving
CRiSP from Emacs source repository to ELPA.
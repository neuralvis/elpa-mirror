abridge-diff can be installed from Melpa with M-x `package-install' RET
abridge-diff.

Usage:

Once installed, abridge-diff will immediately start abridging all
refined (word change highlighted) diff hunks, shortening them by
replacing unnecessary surround context with ellipses (...) . You
can enable and disable showing the abridged version using
abridge-diff-toggle-hiding.  Automatically configures itself to work
with magit, adding a new `D a' diff setup command, which toggles the
abridging.  Hunks are shown as abridged by default.

Settings:

You can customize settings with these variables; just M-x customize-group abridge-diff:
 abridge-diff-word-buffer: Number of words to preserve around refined regions.
 abridge-diff-first-words-preserve: Keep at least this many words visible at the beginning of an abridged line with refined diffs.
 abridge-diff-invisible-min: Minimum region length (in characters) between refined areas that can be made invisible.
 abridge-diff-no-change-line-words: Number of words to keep at the beginning of a line without any refined diffs.

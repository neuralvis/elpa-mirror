This package provides the commands `nswbuff-switch-to-next-buffer'
and `nswbuff-switch-to-previous-buffer' to respectively switch to
the next or previous buffer in the buffer list.

The option `nswbuff-exclude-buffer-regexps' defines a list of regular
expressions for excluded buffers.  The default setting excludes
buffers whose name begin with a blank character.  To exclude all the
internal buffers (that is *scratch*, *Message*, etc...) you could
use the following regexps '("^ .*" "^\\*.*\\*").

Buffers can also be excluded by major mode using the option
`nswbuff-exclude-mode-regexp'.

The option `nswbuff-include-buffer-regexps' defines a list of regular
expressions of buffers that must be included, even if they already match a
regexp in `nswbuff-exclude-buffer-regexps'.  (The same could be done by using
more sophisticated exclude regexps, but this option keeps the regexps cleaner
and easier to understand.)

You can further customize the list of switchable buffers by setting the
option `nswbuff-buffer-list-function' to a function that returns a list of
buffers.  Only the buffers returned by this function will be offered for
switching.  Note that this list is still checked against
`nswbuff-exclude-buffer-regexps', `nswbuff-exclude-mode-regexp' and
`nswbuff-include-buffer-regexps', so set these to `nil' if you do not want
this.  If `nswbuff-buffer-list-function' is `nil' or if its function returns
`nil', the list of buffers returned by the function `buffer-list' is used.

One function already provided that makes use of this option is
`nswbuff-projectile-buffer-list', which returns the buffers of the current
[Projectile](http://batsov.com/projectile/) project plus any buffers in
`(buffer-list)' that match `nswbuff-include-buffer-regexps'.

Switching buffers pops-up a status window at the bottom of the
selected window.  The status window shows the list of switchable
buffers where the switched one is hilighted using
`nswbuff-current-buffer-face'.  This window is automatically
discarded after any command is executed or after the delay
specified by `nswbuff-clear-delay'.

The bufferlist is sorted by how recently the buffers were used.  If
you prefer a fixed (cyclic) order set `nswbuff-recent-buffers-first'
to nil.

When the status window disappears because of the clear-delay you
still stay in switching mode.  The timeout is only a visual
thing.  If you want it to have the same effect as using the buffer,
set `nswbuff-clear-delay-ends-switching' to t.

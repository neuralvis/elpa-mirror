Provides a global minor mode, `ns-auto-titlebar-mode' which - when
enabled - keeps the "ns-appearance" frame parameter correctly set
in GUI frames so that it matches the currently-enabled theme,
whether it is light or dark.

Usage:

    (when (eq system-type 'darwin) (ns-auto-titlebar-mode))

Note that it is safe to omit the "when" condition if you prefer.

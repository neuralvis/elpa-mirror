This library allows elisp authors to easily provide an idiomatic
command to reformat the current buffer using a command-line
program, together with an optional minor mode which can apply this
command automatically on save.

In its initial release it supports only reformatters which read
from stdin and write to stdout, but a more versatile interface will
be provided as development continues.

As an example, let's define a reformat command that applies the
"dhall format" command.  We'll assume here that we've already defined a
variable `dhall-command' which holds the string name or path of the
dhall executable:

    (reformatter-define dhall-format
      :program dhall-command
      :args '("format"))

The `reformatter-define' macro expands to code which generates both
the `dhall-format' interactive command and a local minor mode
called `dhall-format-on-save-mode'

The generated minor mode allows idiomatic per-directory or per-file
customisation, via the "modes" support baked into Emacs' file-local
and directory-local variables mechanisms.  For example, users of
the above example might add the following to a project-specific
.dir-locals.el file:

    ((dhall-mode
      (mode . dhall-format-on-save)))

See the documentation for `reformatter-define', which provides a
number of options for customising the generated code.

Library authors might like to provide autoloads for the generated
code, e.g.:

    ;;;###autoload (autoload 'dhall-format "current-file" nil t)
    ;;;###autoload (autoload 'dhall-format-on-save-mode "current-file" nil t)

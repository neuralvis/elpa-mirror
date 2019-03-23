In an Org mode buffer:

- Toggle the mode with {M-x org-pretty-tags-mode RET}.
- Activate the mode with {C-u M-x org-pretty-tags-mode RET}.
- Deactivate the mode with {C-u -1 M-x org-pretty-tags-mode RET}.

The same commands in an Org agenda buffer perform in the same way as
stated above for _every_ Org mode buffer.

- Toggle the mode in every buffer with {M-x org-pretty-tags-mode-global RET}.
- Activate the mode in every buffer with {C-u M-x org-pretty-tags-mode-global RET}.
- Deactivate the mode in every buffer with {C-u -1 M-x org-pretty-tags-mode-global RET}.

Use {M-x customize-variable RET org-pretty-tags-surrogate-strings RET} to
define surrogate strings for tags.  E.g. add the pair "money", "$$$".

If you don't like the predefined surrogates then just delete them.

Use {M-x customize-variable RET org-pretty-tags-surrogate-images RET} to
define surrogate images for tags.  The definition of the image is
expected to be a path to an image.  E.g. add the pair "org", "<path to
org icon>".

See also the literate source file.  E.g. see https://gitlab.com/marcowahl/org-pretty-tags.

This library offers an integration between bibtex-completion and
org-roam by delegating the tasks of note's creation, editing and
retrieval to org-roam.  From the org-roam's perspective, the library
provides a means to populate org-roam templates with bibliographic
information secured through bibtex-completion,.

To use it:

call interactively `org-roam-bibtex-mode' or
call (org-roam-bibtex-mode +1) from Lisp.

After enabling `org-roam-bibtex-mode', the function
`org-roam-bibtex-edit-notes' will shadow
`bibtex-completion-edit-notes' in Helm-bibtex, Ivy-bibtex and its
surrogate will be used as a `org-ref-notes-function' in Org-ref
(see `org-ref' documentation for how to setup many-files notes).

As a user option, `org-roam-capture-templates' can be dynamically
preformatted with bibtex field values.  See
`org-roam-bibtex-preformat-keywords' for more details.

Optionally, automatic switching to the perspective (Persp-mode)
with the notes project (Projectile) is possible.  See
`org-roam-bibtex-edit-notes' for more details.

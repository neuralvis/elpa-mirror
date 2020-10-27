This is a convenient bundle of language grammars and queries for
`tree-sitter'. It serves as an interim distribution mechanism, until
`tree-sitter' is widespread enough for language major modes to include these
definitions on their own.

Basically it's a multi-step process:

1. `tree-sitter-langs' populates global registries of grammars and queries.
   These global registries are defined by `tree-sitter-mode' and other
   `tree-sitter'-based language-agnostic minor modes, to extend existing
   major modes.

2. New `tree-sitter'-based language-specific minor modes use these global
   registries to extend existing major modes.

3. Major modes adopt new `tree-sitter'-based features, and distribute the
   grammars and queries on their own. They can either put these definitions
   in the global registries, or keep using them only internally.

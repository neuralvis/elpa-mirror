Common operations such as colouring text for HTML and LaTeX
backends are provided.  Below is an example.

#+begin_red org
/This/
      *text*
             _is_
                  red!
#+end_red

This file has been tangled from a literate, org-mode, file;
and so contains further examples demonstrating the special
blocks it introduces.


The system is extensible:
Users register a handler ORG-SPECIAL-BLOCK-EXTRAS--TYPE
for a new custom block TYPE, which is then invoked.
The handler takes three arguments:
- CONTENTS: The string contents delimited by the custom block.
- BACKEND:  The current exportation backend; e.g., 'html or 'latex.
The handler must return a string.

Full documentation can be found at
https://alhassy.github.io/org-special-block-extras

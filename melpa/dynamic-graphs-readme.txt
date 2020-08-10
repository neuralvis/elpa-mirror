Make dynamic graphs: take a graph (as defined for graphviz), apply
some filters, and display it as an image.  The graph can be either
a function that inserts the graph (and is called for each
redisplay), or a buffer that can change.  An imap file is created
in addition to the image so that clicks on image can be related to
individual nodes (TODO: only for rectangles so far)

The filters can apply both enhancing operations (add colors, ...)
and more complicated operations coded in gvpr.  As a special case
there is a filter that removes all nodes that are more distant than
a parameter from a root node.

The image is displayed with a specialized minor mode.
Predefined key bindings on the displayed image in this mode include:
- e (dynamic-graphs-set-engine) change grahviz engine (dot, circo, ...)
- c (dynamic-graphs-remove-cycles) change whether cycles are removed
- 1-9 (dynamic-graphs-zoom-by-key) set maximum displayed distance from a root node
- mouse-1 (dynamic-graphs-handle-click) follow link defined in imap
  file - that is, in URL attribute of the node.  Link is followed
  by customizable function, by default `browse-url' - but
  `org-link-open-from-string' might be more useful.
- S-mouse-1 (dynamic-graphs-shift-focus) if the link for node is
  id:<node name>, extract node name and make it a new
  root.  Predefined filter `node-refs' set hrefs in such way.  This
  simplifies things when nodes relate to org mode items, but
  actually does not make much sense otherwise.

Example:

(dynamic-graphs-display-graph "test" nil
		   (lambda ()
		     (insert "digraph Gr {A->B B->C C->A A->E->F->G}"))
		   '(2 remove-cycles "N {style=\"filled\",fillcolor=\"lightgreen\"}"
                  node-refs boxize))

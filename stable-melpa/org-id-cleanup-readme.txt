Purpose:

 Interactively cleanup unused IDs created by org-id.
 There are IDs, that are no longer referenced from anywhere else in org.

 Normal usage of org-id does not lead to a lot of unreferenced IDs,
 and org-id normally does not suffer from them.
 However, some packages (like org-working-set) lead to such IDs during
 normal usage; in such cases it might be helpful clean up.

Setup:

 - org-id-cleanup should be installed with package.el

Purpose:

 Interactively cleanup unused IDs of org-id.
 The term 'unused' refers to IDs, that have been created by org-id quite
 regularly, but are now no longer referenced from anywhere within in org.
 This might happen by deleting a link, that once referenced such an id.

 Normal usage of org-id does not lead to a lot of such unused IDs, and
 org-id normally does not suffer from them.

 However, some packages (like org-working-set) lead to a larger number of
 such unused IDs evend during normal usage; in such cases it might be
 helpful clean up.

Setup:

 - org-id-cleanup should be installed with package.el

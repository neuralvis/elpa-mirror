OrgMsg can be considered an extension of the `message-user-agent'
to use Org mode for email composition and Org mode HTML export
engine to produce HTML emails.

This module provides the OrgMsg mode which make use of Org mode
for body HTML composition, `message-mode' for overall mail
composition and `mml-mode' to handle inline images inclusion and
attach files.

- It uses `gnus-article-browse-html-article' to generate an HTML
  version of the article to reply to.  This HTML content is
  modified to add the reply generated using org-mode HTML export.
- It overrides `mml-expand-html-into-multipart-related' to add the
  support for file attachment.

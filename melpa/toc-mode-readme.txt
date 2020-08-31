toc-mode.el is a package to create and add a Table of Contents to pdf and
djvu documents. It implements features to extract a Table of Contents from
the textlayer of a document or via OCR if that last option is necessary or
prefered. Subsequently this package implements various features to assist in
tidy up the extracted Table of Contents, adjust the pagenumbers and finally
parsing the Table of Contents into syntax that is understood by the
`pdfoutline' and `djvused' commands that are used to add the table of
contents to pdf- and djvu-files respectively.

Requirements: Currently the package requires the `pdftotext' (part of
poppler-utils), `pdfoutline' (part of fntsample) and `djvused' (part of
http://djvu.sourceforge.net/) command line utilities to be available.
Extraction with OCR requires the tesseract command line utility to be
available.

Usage: Extraction and adding contents to a document is done in 4 steps: 1
extraction 2 cleanup 3 adjust/correct pagenumbers 4 add TOC to document

1. Extraction Open some pdf or djvu file in Emacs (pdf-tools and djvu package
recommended). Find the pagenumbers for the TOC. Then type M-x
`toc-extract-pages', or M-x `toc-extract-pages-ocr' if doc has no text layer
or text layer is bad, and answer the subsequent prompts by entering the
pagenumbers for the first and the last page each followed by RET. For PDF
extraction with OCR, currently it is required to view all contents pages once
before extraction (toc-mode uses the cached file data). Also the languages
used for tesseract OCR can be customized via the `toc-ocr-languages'
variable. A buffer with the, somewhat cleaned up, extracted text will open in
TOC-cleanup mode. Prefix command with the universal argument (C-u) to omit
clean and get the raw text. If the extracted text is of too low quality you
either can hack/extend the `toc-extract-pages-ocr' definition, or
alternatively you can try to extract the text with the python
document-contents-extractor script (see URL
`https://pypi.org/project/document-contents-extractor/'), which is more
configurable (you are also welcome to hack and improve that script).

The documentation at URL
`https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html' might be
useful.

If you merely want to extract text without further processing then you can
use the command `toc-extract-only'.

2. TOC-Cleanup In this mode you can further cleanup the contents to create a
list where each line has the structure:

TITLE (SOME) PAGENUMBER

(If the initial TOC looks bad/unusable then try to use then universal
argument C-u before extraction in the previous step and/or try the ocr option
with or without the universal argument)
There can be any number of spaces between TITLE and PAGE. The correct
pagenumbers can be edited in the next step. A document outline supports
different levels and levels are automatically assigned in order of increasing
number of preceding spaces, i.e. the lines with the least amount of preceding
spaces are assigned level 0 etc., and lines with equal number of spaces get
assigned the same levels.

Contents   1
Chapter 1      2
Section 1 3
Section 1.1     4
Chapter 2      5

There are some handy functions to assist in the cleanup. C-c C-j jumps
automatically to the next line not ending with a number and joins it with the
next line. If the indentation structure of the different lines does not
correspond with the levels, then the levels can be set automatically from the
number of separatorss in the indices with M-x toc--cleanup-set-level-by-index.
The default separators is a . but a different separators can be entered by
preceding the function invocation with the universal argument (C-u). Some
documents contain a structure like

1 Chapter 1    1
Section 1      2

Here the indentation can be set with M-x replace-regexp ^[^0-9] -> \& (where
there is a space character before the \&).

Type C-c C-c when finished

3. TOC-tabular (adjust pagenumbers) This mode provides the functionality for
easy adjustment of pagenmumbers. The buffer can be navigated with the arrow
up/down keys. The left and right arrow keys will shift down/up all the page
numbers from the current line and below (combine with SHIFT for setting
individual pagenumbers).

The TAB key jumps to the pagenumber of the current line, while C-right/C-left
will shift all remaining page numbers up/down while jumping/scrolling to the
line its page in the document window. to the S-up/S-donw in the tablist
window will just scroll page up/down in the document window and, only for
pdf, C-up/C-down will scroll smoothly in that window.

Type C-c C-c when done.

4. TOC-mode (add outline to document) The text of this buffer should have the
right structure for adding the contents to (for pdf’s a copy of) the original
document. Final adjusments can be done but should not be necessary. Type C-c
C-c for adding the contents to the document.

By default, the TOC is simply added to the original file. ONLY FOR PDF’s, if
the (customizable) variable toc-replace-original-file is nil, then the TOC is
added to a copy of the original pdf file with the path as defined by the
variable toc-destination-file-name. Either a relative path to the original
file directory or an absolute path can be given.

Sometimes the `pdfoutline/djvused' application is not able to add the TOC to
the document. In that case you can either debug the problem by copying the
used terminal command from the `*messages*' buffer and run it manually in the
document's folder, or you can delete the outline source buffer and run
`toc--tablist-to-handyoutliner' from the tablist buffer to get an outline
source file that can be used with HandyOutliner (see URL
`http://handyoutlinerfo.sourceforge.net/') Unfortunately the handyoutliner
command does not take arguments, but if you customize the
`toc-handyoutliner-path' and `toc-file-browser-command' variables, then Emacs
will try to open HandyOutliner and the file browser so that you can drag the
files directly into HandyOutliner).

Finally, if you just want to extract some text

Keybindings
all-modes (i.e. all steps)
 Key Binding        Description
  ~C-c C-c~         dispatch (next step)

toc-cleanup-mode
 ~C-c C-j~          toc--join-next-unnumbered-lines

toc-mode (tablist)
 ~TAB~              preview/jump-to-page
 ~right/left~       toc-in/decrease-remaining
 ~C-right/C-left~   toc-in/decrease-remaining and view page
 ~S-right/S-left~   in/decrease pagenumber current entry
 ~C-down/C-up~      scroll document other window (if document buffer shown)
 ~S-down/S-up~      full page scroll document other window ( idem )

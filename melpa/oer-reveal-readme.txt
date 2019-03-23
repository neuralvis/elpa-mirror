Package `oer-reveal' bundles resources for the creation of
reveal.js presentations as Open Educational Resources (OER) from
Org source files.  This package builds upon `org-re-reveal' for
export from Org mode to HTML with reveal.js.  It provides help in
installing and configuring reveal.js and several of its plugins.

Notably, `oer-reveal' simplifies one traditionally cumbersome task
for OER creators, namely the re-use of figures under free licenses
that require proper attribution.  Towards that end, macros
`revealimg', `reveallicense', and `revealgrid' are defined and
documented in file "org/config.org".

* Usage
Variable `oer-reveal-dir' points to the directory of oer-reveal and
its embedded resources.  You may want to use that variable in your
own publication code, for which some pointers are provided in file
"oer-reveal-publish.el".  Note that subdirectory "title-slide"
contains some variants for title slides of presentations, and
subdirectory "css" contains sample CSS.  Subdirectory "org"
contains Org files to embed in presentations.  Please be warned
that included resources, in particular CSS files, may change in
incompatible ways.  You may want to work with your own copies.

Function `oer-reveal-setup-submodules' downloads and installs
reveal.js and some of its plugins into the directory
`oer-reveal-submodules-dir'.  Function
`oer-reveal-generate-include-files' generates Org files under
`oer-reveal-org-includes-dir', which include Org files coming with
`oer-reveal'; when installing `oer-reveal' from MELPA (with
changing directories upon updates) you can include those generated
files at stable locations in your own Org files.

* Customizable options
Variable `oer-reveal-script-files' lists JavaScript files to load
when initializing reveal.js.  If you use the version of reveal.js
coming with oer-reveal, changes should not be necessary.

Variable `oer-reveal-plugins' lists reveal.js plugins to be
activated.  Remove those that you do not need.  Function
`oer-reveal-setup-plugins' adds plugin initialization code to
`org-re-reveal-external-plugins'.

When generating image grids, `oer-reveal-export-dir' specifies
the directory into which to generate CSS code.  This should
probably be the directory into which you publish your HTML code.
I set this to "./" before exporting with `C-c C-e v b'.
The names of generated CSS files for image grids are determined by
`oer-reveal-css-filename-template'.

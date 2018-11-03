Eredis provides a programmatic API for accessing Redis (in-memory data structure store/database) using emacs lisp.
This software is released under the Gnu License v3. See http://www.gnu.org/licenses/gpl.txt

Usage:

Each redis connection creates a process and has an associated buffer which revieves data from the redis server

(setq redis-p1 (eredis-connect "localhost" "6379"))
(eredis-set "key" "value" redis-p1) "ok"
(eredis-get "key" redis-p1) "value"

Earlier versions of redis (pre 0.9) did not support multiple connections/processes. To preserve backwards compatibility you can omit the process argument from commands and an internal variable `eredis--current-process' will track the most recent connection to be used by default.

You can close a connection like so. The process buffer can be closed seperately.
(eredis-disconnect redis-p1)

0.9 Changes

Multiple connections to multiple redis servers supported
Buffer is used for all output from the process (Redis)
Github repo contains an ert test suite
Fix for multibyte characters
Support for LOLWUT (version 5.0 of Redis and later)

Github contributors

justinhj
pidu
crispy
darksun
lujun9972

Future TODO

TODO rethink error reporting... it currently is not distinguishable to the user from a normal response, perhaps return a tuple ...
response type (incomplete, complete, error)
and body
note that this will change the API though
simpler solution is to throw the error
TODO check all private function names have --
TODO check all functionas have eredis-
Everything here https://github.com/bbatsov/emacs-lisp-style-guide
heading comments three semi colons, otherwise two

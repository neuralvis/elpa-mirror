Eredis provides a programmatic API for accessing Redis (in-memory data structure store/database) using emacs lisp.

Usage:

Each redis connection creates a process and has an associated buffer which revieves data from the redis server

(setq redis-p1 (eredis-connect "localhost" "6379"))
(eredis-set "key" "value" redis-p1) "ok"
(eredis-get "key" redis-p1) "value"

Earlier versions of redis (pre 0.9) did not support multiple connections/processes. To preserve backwards compatibility you can omit the process argument from commands and an internal variable `eredis--current-process' will track the most recent connection to be used by default.

You can close a connection like so. The process buffer can be closed seperately.
(eredis-disconnect redis-p1)

0.9.5 Changes

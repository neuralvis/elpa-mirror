This package is designed to ease manipulation of dates, times, and timestamps in Emacs.

A struct `ts' is defined, which represents a timestamp.  All manipulation is done internally
using Unix timestamps.  Accessors are used to retrieve values such as month, day, year, etc. from
a timestamp, and these values are cached in the struct once accessed, to avoid repeatedly having
to call `format-time-string'.  If a slot is modified, the timestamp's internal Unix timestamp
should be updated with `ts-update'.

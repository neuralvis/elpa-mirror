A time tracker in Emacs with a nice interface

Largely modelled after the Android application, [A Time Tracker](https://github.com/netmackan/ATimeTracker)

* Benefits
  1. Extremely simple and efficient to use
  2. Displays useful information about your time usage
  3. Support for both mouse and keyboard
  4. Human errors in tracking are easily fixed by editing a plain text file
  5. Hooks to let you perform arbitrary actions when starting/stopping tasks

* Limitations
  1. No support (yet) for adding a task without clocking into it.
  2. No support for concurrent tasks.

## Comparisons
### timeclock.el
* Stores data in an s-expression format rather than a line-based one
* Supports attaching tags and arbitrary key-values to time intervals
* Has commands to shows useful summaries
* Has a more useful implementation of hooks (see [Hooks](#Hooks))

### Org time tracking
* Chronometrist is tailored towards long-term, rarely-changing, everyday tasks, rather than transient ones. You might think of it as a program to help balance your day, or to help you form habits.

For information on usage and customization, see https://github.com/contrapunctus-1/chronometrist/blob/master/README.md

## VARIABLES ##

processManager
==============

A Matlab class for launching and managing processes that run asynchronously from the main Matlab process. This can already be done with something like `system('dir &');` but processManager makes it easy to:

* easily launch and manage multiple processes
* peek to check on progress of running processes
* manage display of process `stdout` and `stderr` streams
* continue working in the main Matlab process

Dependencies
-------------------
processManager was developed and tested on OSX with Matlab 2012a, but should work on all platforms that Matlab supports, and running >=R2008a and JDK >=1.0.

Installing Steve Eddins's [linewrap](http://www.mathworks.com/matlabcentral/fileexchange/9909-line-wrap-a-string) function is useful for dealing with unwrapped messages.

Contact: [Brian Lau](mailto:brian.lau@upmc.fr)
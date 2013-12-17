# processManager

A Matlab class for launching and managing processes that run asynchronously from the main Matlab process. This can already be done with something like `system('dir &');` but processManager makes it easy to:

* easily launch and manage multiple processes
* peek to check on progress of running processes
* capture & display `stdout` and `stderr` streams of each process

while allowing you to continue working in the main Matlab process.

## Dependencies
processManager was developed and tested on OSX with Matlab 2012a, but should work on all platforms that Matlab supports, and running >=R2008a and JDK >=1.0.

Installing Steve Eddins's [linewrap](http://www.mathworks.com/matlabcentral/fileexchange/9909-line-wrap-a-string) function is useful for dealing with unwrapped messages.

##Issues
### Matlab is blocked
processManager relies on the ability to call Java functions from within Matlab. In particular, it uses the Java [Runtime object](http://docs.oracle.com/javase/6/docs/api/java/lang/Runtime.html) to create [subprocesses](http://docs.oracle.com/javase/6/docs/api/java/lang/Process.html). The docs note that,

>Because some native platforms only provide limited buffer size for standard input and output streams, failure to promptly write the input stream or read the output stream of the subprocess may cause the subprocess to block, and even deadlock.

processManager uses a timer to periodically drain the io streams. The interval of this timer is controlled by the property `pollInterval`. If you find your Matlab process blocking indefinitely, it may be that your process is particularly verbose, and you might try setting `pollInterval` to a lower value (default = 0.5 sec).

### Failure to cleanup timers
[Timers](http://www.mathworks.com/help/matlab/ref/timerclass.html) are used to drain the io streams, and since they are [user-managed](http://blogs.mathworks.com/loren/2008/07/29/understanding-object-cleanup/), it is possible to get into a situation where they are not properly cleaned up. This is due to the fact that the timer callbacks refer to the processManager object itself, which prevents the processManager destructor from getting called (the logical place to clean up the timers). For example, clearing a processManager object while a process is still running will remove it's name from the workspace, but it will continue to run because it is referenced by the timer. If you find yourself in this situation, find the problem timers:

`>> timers = timerfindall`

and delete those that with the name including `processManager-pollTimer`. Eg.,

`>> delete(timers)`

Useful info [here](http://stackoverflow.com/questions/10489996/matlab-objects-not-clearing-when-timers-are-involved) and
[here](http://stackoverflow.com/questions/9559849/matlab-object-destructor-not-running-when-listeners-are-involved).

Contributions & feedback
--------------------------------
Please feel from to fork and contribute!

Contact: [Brian Lau](mailto:brian.lau@upmc.fr)
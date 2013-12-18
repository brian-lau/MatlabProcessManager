# processManager

A Matlab class for launching and managing processes that run asynchronously from the main Matlab process. This can already be done with something like `system('dir &');` but processManager makes it easy to:

* launch and manage multiple processes
* peek to check on the progress of running processes
* capture & display `stdout` and `stderr` streams of each process

while allowing you to continue working in the main Matlab process.

## Installation & Examples
Download [processManager](https://github.com/brian-lau/MatlabProcessManager/archive/master.zip), add the m-file to your Matlab path, and you're ready to go.

processManager was developed and tested on OSX with Matlab 2012a, but should work on all platforms that Matlab supports, so long as it is running >=R2008a with JDK >=1.0.

Installing Steve Eddins's [linewrap](http://www.mathworks.com/matlabcentral/fileexchange/9909-line-wrap-a-string) function is useful for dealing with unwrapped messages.

###Examples

####Running a simple command
```
>> p = processManager('command','ls -la');
```

####Command with ongoing output
```
>> p = processManager('command','ping www.google.com');

% To keep the process running silently,
>> p.printStdout = false;

% ... Check back later
>> p.printStdout = true;

% Terminate
>> p.stop();
```

####Multiples processes using object arrays
```
>> p(1) = processManager('id','google','command','ping www.google.com','autoStart',false);
>> p(2) = processManager('id','yahoo','command','ping www.yahoo.com','autoStart',false);
>> p.start()

%Tired of hearing about second process
>> p(2).printStdout = false;

% ... if you want to hear back later,
>> p(2).printStdout = true;

% Terminate
>> p.stop();
```

##Issues
### Matlab is blocked
processManager relies on the ability to call Java functions from within Matlab. In particular, it uses the Java [Runtime object](http://docs.oracle.com/javase/6/docs/api/java/lang/Runtime.html) to create [subprocesses](http://docs.oracle.com/javase/6/docs/api/java/lang/Process.html). The docs note that,

>Because some native platforms only provide limited buffer size for standard input and output streams, failure to promptly write the input stream or read the output stream of the subprocess may cause the subprocess to block, and even deadlock.

processManager uses a timer to periodically drain the io streams. The interval of this timer is controlled by the property `pollInterval`. If you find your Matlab process blocking indefinitely, it may be that your process is particularly verbose or your buffers are particularly small, and you might try setting `pollInterval` to a lower value (default = 0.5 sec).

### Failure to cleanup timers
Because the [timers](http://www.mathworks.com/help/matlab/ref/timerclass.html) used to drain the io streams are [user-managed](http://blogs.mathworks.com/loren/2008/07/29/understanding-object-cleanup/), it is possible to get into a situation where they are not properly cleaned up. This is due to the fact that the each timer holds a reference to the processManager object itself, which prevents the processManager destructor from getting called (a seemingly logical place to clean up the timers). For example, if a processManager object goes out of scope (say you clear it from the workspace while a process is still running), its timer(s) will continue to run even though you can no longer get to the processManager object. If you find yourself in this situation, find the problem timers:
```
>> timers = timerfindall
```
and delete those that with the name including `processManager-pollTimer`. Eg.,
```
>> delete(timers)
```

To avoid orphaned timers, always call `processManager.stop()` before deleting a running process.

Useful info 
[here](http://stackoverflow.com/questions/10489996/matlab-objects-not-clearing-when-timers-are-involved),
[here](http://stackoverflow.com/questions/9559849/matlab-object-destructor-not-running-when-listeners-are-involved),
[here](http://stackoverflow.com/questions/7236649/matlab-run-object-destructor-when-using-clear),
[here](http://www.mathworks.com/matlabcentral/answers/39858-clearing-handle-subclasses-with-timer-objects), and
[here](http://www.mathworks.com/matlabcentral/newsreader/view_thread/306641).

Contributions & feedback
--------------------------------
Please feel from to fork and contribute!

Contact: [Brian Lau](mailto:brian.lau@upmc.fr)
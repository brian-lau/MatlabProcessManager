% PROCESSMANAGER - Launch and manage external processes
%
%     obj = processManager(varargin);
%
%     Class for launching and managing processes than run asynchronously
%     and in parallel to the main Matlab process. This could be done with 
%     something like 
%     
%     >> system('dir &');
%
%     but using processManager allows you to start and stop processes, peek
%     and check on the progress of running processes, all the while allowing 
%     you to continue working in the main Matlab process.
%
%     All inputs are passed in using name/value pairs. The name is a string
%     followed by the value (described below).
%     The only required input is the command.
%     The order of the pairs does not matter, nor does the case.
%
%     More information and can be found on GitHub:
%     https://github.com/brian-lau/MatlabProcessManager/wiki
%
% INPUTS
%     command      - string defining command to execute
%
% OPTIONAL
%     id           - string identifier for process, default ''
%     workingDir   - string defining working directory
%     envp         - not working yet
%     printStdout  - boolean to print stdout stream, default true
%     printStderr  - boolean to print stderr stream, default true
%     wrap         - number of columns for wrapping lines, default = 80
%     keepStdout   - boolean to keep stdout stream, default false
%     keepStderr   - boolean to keep stderr stream, default false
%     autoStart    - boolean to start process immediately, default true
%     pollInterval - double defining polling interval in sec, default 0.5
%                    Take care with this variable, if set too long, there is
%                    a risk of blocking Matlab when streams buffers not drained 
%                    fast enough
%                    If you don't want to see output, better to set
%                    printStdout and printStderr false
%
% METHODS
%     start        - start process(es)
%     stop         - stop process(es)
%     check        - check running process(es)
%     block        - block until done
%
% EXAMPLES
%     % 1) Running a simple command
%     p = processManager('command','ls -la');
%
%     % 2) Command with ongoing output
%     p = processManager('command','ping www.google.com');
%     % To keep the process running silently,
%     p.printStdout = false;
%     % ... Check back later
%     p.printStdout = true;
%     % Terminate
%     p.stop();
%
%     % 3) Multiples processes
%     p(1) = processManager('id','google','command','ping www.google.com','autoStart',false);
%     p(2) = processManager('id','yahoo','command','ping www.yahoo.com','autoStart',false);
%     p.start()
%     % Tired of hearing about second process
%     p(2).printStdout = false;
%     % ... if you want to hear back later,
%     p(2).printStdout = true;
%     p.stop();
% 
%     $ Copyright (C) 2013 Brian Lau http://www.subcortex.net/ $
%     Released under the BSD license. The license and most recent version
%     of the code can be found on GitHub:
%     https://github.com/brian-lau/MatlabProcessManager

% TODO
% store streams? maybe we need to buffer only last xxx
% setters to validate public props...
% store timer names and create kill method for orphans?
% Generate unique names for each timer. check using timerfindall, storename
% cprintf for colored output for each process?

% ISSUES
% Polling is a terrible hack. Worse, it seems that when the process exits, the
% io streams are closed. Since polling is relatively infrequent, this means that
% io can be lost if the process exits in between polls.
% Really seems like I need to wrap up a Java class with threading to deal with
% the streams

classdef processManager < handle
   properties(GetAccess = public, SetAccess = public)
      id
      command
      envp
      workingDir

      printStderr
      printStdout
      wrap
      keepStderr
      keepStdout
      autoStart

      pollInterval
   end
   properties(GetAccess = public, SetAccess = private)
      stderr = {};
      stdout = {};
   end
   properties(GetAccess = public, SetAccess = private, Dependent = true, Transient = true)
      running
      exitValue
   end
   properties(GetAccess = private, SetAccess = private)
      process
      stderrBuffer
      stdoutBuffer
      pollTimer
   end
   events
      exit
   end
   methods
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %% Constructor
      function self = processManager(varargin)
         % Constructor, arguments are taken as name/value pairs
         %
         % id           - string identifier for process, default ''
         % command      - string defining command to execute, required
         % workingDir   - string defining working directory
         % envp         - not working yet
         % printStdout  - boolean to print stdout stream, default true
         % printStderr  - boolean to print stderr stream, default true
         % autoStart    - boolean to start process immediately, default true
         % pollInterval - double defining polling interval in sec, default 0.5
         %                Take care with this variable, if set too long,
         %                runs the risk of blocking Matlab when streams buffers
         %                not drained fast enough
         %                If you don't want to see output, better to set 
         %                printStdout and printStderr false
         %
         if nargin == 0
            return;
         end
         p = inputParser;
         p.KeepUnmatched= false;
         p.FunctionName = 'processManager constructor';
         p.addParamValue('id','',@isstr);
         p.addParamValue('command','',@(x) isstr(x) || iscell(x) || isa(x,'java.lang.String[]'));
         p.addParamValue('workingDir','',@(x) exist(x,'dir')==7);
         p.addParamValue('envp','',@iscell);
         p.addParamValue('printStdout',true,@islogical);
         p.addParamValue('printStderr',true,@islogical);
         p.addParamValue('keepStdout',false,@islogical);
         p.addParamValue('keepStderr',false,@islogical);
         p.addParamValue('wrap',80,@(x) isnumeric(x) && (x>0));
         p.addParamValue('autoStart',true,@islogical);
         p.addParamValue('pollInterval',0.05,@(x) isnumeric(x) && (x>0));
         p.parse(varargin{:});
         
         self.id = p.Results.id;
         if iscell(p.Results.command)
            n = length(p.Results.command);
            command = javaArray('java.lang.String',n);
            for i = 1:n
               command(i) = java.lang.String(p.Results.command{i});
            end
            self.command = command;
         else
            self.command = p.Results.command;
         end
         if isempty(p.Results.workingDir);
            self.workingDir = pwd;
         else
            self.workingDir = p.Results.workingDir;
         end
         if isempty(p.Results.envp)
            self.envp = [];
         else
            self.envp = p.Results.envp;
         end
         self.printStdout = p.Results.printStdout;
         self.printStderr = p.Results.printStderr;
         self.wrap = p.Results.wrap;
         self.keepStdout = p.Results.keepStdout;
         self.keepStderr = p.Results.keepStderr;
         self.autoStart = p.Results.autoStart;
         self.pollInterval = p.Results.pollInterval;
                                  
         if self.autoStart
            self.start();
         end
      end
      
      function start(self)
         for i = 1:numel(self)
            runtime = java.lang.Runtime.getRuntime();
            self(i).process = runtime.exec(self(i).command,...
               self(i).envp,...
               java.io.File(self(i).workingDir));
            % StringTokenizer is used to parse the command based on spaces
            % this may not be what we want, there is an overload of exec() 
            % that allows passing in a String array.
            % http://www.mathworks.com/matlabcentral/newsreader/view_thread/308816
            
            % Process will block if streams not drained
            self(i).stdoutBuffer = java.io.BufferedReader(...
               java.io.InputStreamReader(...
               self(i).process.getInputStream() ...
               ) ...
               );
            self(i).stderrBuffer = java.io.BufferedReader(...
               java.io.InputStreamReader(...
               self(i).process.getErrorStream() ...
               ) ...
               );
            
            % Install timer to periodically drain streams
            % http://stackoverflow.com/questions/8595748/java-runtime-exec
            self(i).pollTimer = timer('ExecutionMode','FixedRate',...
               'Period',self(i).pollInterval,...
               'Name',[self(i).id '-processManager-pollTimer'],...
               'TimerFcn',{@processManager.poll self(i)});
            start(self(i).pollTimer);
         end
      end

      function stop(self,silent)
         if nargin < 2
            silent = false;
         end
         for i = 1:numel(self)
            if ~isempty(self(i).pollTimer) && isvalid(self(i).pollTimer)
               stop(self(i).pollTimer);
               delete(self(i).pollTimer);
               %fprintf('processManager uninstalling timer for process %s.\n',self(i).id)
            end
            if ~isempty(self(i).process)
               self(i).stdoutBuffer.close();
               self(i).stderrBuffer.close();
               self(i).process.destroy();
            end
            self(i).running; % This seems to force an update
            self(i).check(silent);
         end
      end

      function running = get.running(self)
         if isempty(self.process)
            running = false;
         else
            running = self.isRunning(self.process);
         end
      end
      
      function exitValue = get.exitValue(self)
         if isempty(self.process)
            exitValue = NaN;
         else
            [~,exitValue] = self.isRunning(self.process);
         end
      end

      % Does not work for object array...
%       function set.printStdout(self,bool)
%          for i = numel(self)
%             self(i).printStdout = bool;
%          end
%       end
      
      function check(self,silent)
         if nargin < 2
            silent = false;
         end
         for i = 1:numel(self)
            if ~self(i).running && isa(self(i).process,'java.lang.Process')
               % Remove timer here since the destructor isn't called correctly?
               % Must be because the timer callback references the object...
               % http://blogs.mathworks.com/loren/2013/07/23/deconstructing-destructors/
               if ~isempty(self(i).pollTimer) && isvalid(self(i).pollTimer)
                  if strcmp(self(i).pollTimer.Running,'on')
                     stop(self(i).pollTimer);
                  end
               end
               %keyboard
               notify(self,'exit'); % Broadcast termination
               delete(self(i).pollTimer);
               if ~silent
                  fprintf('Process %s finished with exit value %g.\n',self(i).id,self(i).exitValue);
               end
            else
               if ~silent
                  fprintf('Process %s is still running.\n',self(i).id);
               end
            end
         end
      end
      
      function block(self,t)
         % Avoid p.waitfor since it hangs with enough output, and
         % unfortunately, Matlab's waitfor does not work?
         % http://undocumentedmatlab.com/blog/waiting-for-asynchronous-events/
         if nargin < 2
            t = self.pollInterval;
         end
         while self.running
            % Matlab pause() has a memory leak
            % http://undocumentedmatlab.com/blog/pause-for-the-better/
            % http://matlabideas.wordpress.com/2013/05/18/take-a-break-have-a-pause/
            java.lang.Thread.sleep(t*1000);
         end
      end
      
      function delete(self)
         if ~isempty(self.process)
            self.process.destroy();
            self.stdoutBuffer.close();
            self.stderrBuffer.close();
         end
         if ~isempty(self.pollTimer)
            if isvalid(self.pollTimer)
               stop(self.pollTimer);
               %delete(self.pollTimer);
               fprintf('processManager uninstalling timer for process %s.\n',self.id)
            end
         end
      end
   end
   
   methods(Static)
      function poll(event,string_arg,obj)
         obj.check(true);
         try
            stderr = obj.readStream(obj.stderrBuffer);
            stdout = obj.readStream(obj.stdoutBuffer);
         catch err
            err.message
            any(strfind(err.message,'process hasn''t exited'))
            if any(strfind(err.message,'java.io.IOException: Stream closed'))
               % pass
               % delete timer?
               fprintf('projectManager timer is polling a closed stream!\n');
            else
               rethrow(err);
            end
         end

         if obj.printStderr
            stderr = obj.printStream(stderr,obj.id,obj.wrap);
         end
         if obj.printStdout
            stdout = obj.printStream(stdout,obj.id,obj.wrap);
         end
         
         if obj.keepStderr
            obj.stderr = cat(1,obj.stderr,stderr);
         end
         if obj.keepStdout
            obj.stdout = cat(1,obj.stdout,stdout);
         end
      end
      
      function lines = readStream(stream)
         % This is potentially fragile since ready() only checks whether
         % there is an element in the buffer, not a complete line.
         % Therefore, readLine() can block if the process doesn't terminate
         % all output with a carriage return...
         %
         % Alternatives inlcude:
         % 1) Implementing own low level read() and readLine()
         % 2) perhaps java.nio non-blocking methods
         % 3) Custom java class for spawning threads to manage streams
         lines = {};
         while true
            if stream.ready()
               line = stream.readLine();
               if isnumeric(line) && isempty(line)
                  % java null is empty double in matlab
                  % http://www.mathworks.com/help/matlab/matlab_external/passing-data-to-a-java-method.html
                  break;
               end
               c = char(line);
               lines = cat(1,lines,c);
            else
               break;
            end
         end
      end
      
      function str = printStream(c,prefix,wrap)
         if nargin < 2
            prefix = '';
         end
         if nargin < 3
            wrap = 80;
         end
         str = {};
         for i = 1:length(c)
            if exist('linewrap','file') == 2
               if isempty(prefix)
                  tempStr = linewrap(c{i},wrap);
               else
                  tempStr = linewrap([prefix ': ' c{i}],wrap);
               end
            else
               if isempty(prefix)
                  tempStr = c{i};
               else
                  tempStr = [prefix ': ' c{i}];
               end
            end
            str = cat(1,str,tempStr);
         end
         fprintf('%s\n',str{:});
      end
      
      function [bool,exitValue] = isRunning(process)
         try
            exitValue = process.exitValue();
            bool = false;
         catch err
            if any(strfind(err.message,'process hasn''t exited'))
               bool = true;
               exitValue = NaN;
            else
               rethrow(err);
            end
         end
      end
      
   end
end
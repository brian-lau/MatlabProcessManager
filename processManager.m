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
%     but using processManager allows you to start and stop processes, and
%     you to peek and check on progress of running processes, while
%     allowing you to continue working in the main Matlab process.
%
%     The only required input is the command.
%     The optional inputs are all name/value pairs. The name is a string
%     followed by the value (described below). The order of the pairs does
%     not matter, nor does the case.
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
%     autoStart    - boolean to start process immediately, default true
%     pollInterval - double defining polling interval in sec, default 0.5
%                    Take care with this variable, if set too long,
%                    runs the risk of blocking Matlab when streams buffers
%                    not drained fast enough
%                    If you don't want to see output, better to set
%                    printStdout and printStderr false
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
% 
%     $ Copyright (C) 2013 Brian Lau http://www.subcortex.net/ $

%
% TODO
% occasionally, the polling timer does not get destroyed properly, and gets
% left around, preventing us from reloading, eg., a changed processManager
% classdef. To get around,
% delete(timerfindall)
%
% envp not working?


classdef processManager < handle
   properties(GetAccess = public, SetAccess = public)
      id
      command
      envp
      workingDir

      printStderr
      printStdout
      autoStart

      pollInterval
   end
   properties(GetAccess = public, SetAccess = private, Dependent = true, Transient = true)
      running
      exitValue
   end
   properties(GetAccess = public, SetAccess = private)
      process
      stdout
      stderr
      pollTimer
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
         p.addParamValue('command','',@isstr);
         p.addParamValue('workingDir','',@(x) exist(x,'dir')==7);
         p.addParamValue('envp','',@iscell);
         p.addParamValue('printStdout',true,@islogical);
         p.addParamValue('printStderr',true,@islogical);
         p.addParamValue('autoStart',true,@islogical);
         p.addParamValue('pollInterval',0.5,@(x) isnumeric(x) && (x>0));
         p.parse(varargin{:});
         
         self.id = p.Results.id;
         self.command = p.Results.command;
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
            
            % Process will block if streams not drained
            self(i).stdout = java.io.BufferedReader(...
               java.io.InputStreamReader(...
               self(i).process.getInputStream() ...
               ) ...
               );
            self(i).stderr = java.io.BufferedReader(...
               java.io.InputStreamReader(...
               self(i).process.getErrorStream() ...
               ) ...
               );
            
            % Install timer to periodically drain streams
            % http://stackoverflow.com/questions/8595748/java-runtime-exec
            self(i).pollTimer = timer('ExecutionMode','FixedRate',...
               'Period',self(i).pollInterval,...
               'Name',[self(i).id 'processManager-pollTimer'],...
               'TimerFcn',{@processManager.poll self(i)});
            start(self(i).pollTimer);
         end
      end

      function stop(self)
         for i = 1:numel(self)
            if ~isempty(self(i).process)
               self(i).process.destroy();
               self(i).stdout.close();
               self(i).stderr.close();
            end
            if ~isempty(self(i).pollTimer)
               stop(self(i).pollTimer);
               delete(self(i).pollTimer);
               fprintf('processManager uninstalling timer for process %s.\n',self(i).id)
            end
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
      
      function check(self)
         if ~self.running && isa(self.process,'java.lang.Process')
            % Remove timer here since the destructor isn't called correctly?
            % Must be because the timer callback references the object...
            % http://blogs.mathworks.com/loren/2013/07/23/deconstructing-destructors/
            if strcmp(self.pollTimer.Running,'on')
               stop(self.pollTimer);
            end
            delete(self.pollTimer);
            self.pollTimer = [];
         end
      end
      
      function delete(self)
         if ~isempty(self.process)
            self.process.destroy();
            self.stdout.close();
            self.stderr.close();
         end
         if ~isempty(self.pollTimer)
            if isvalid(self.pollTimer)
               stop(self.pollTimer);
               delete(self.pollTimer);
               fprintf('processManager uninstalling timer for process %s.\n',self.id)
            end
         end
      end
   end
   
   methods(Static)
      function poll(event,string_arg,obj)
         obj.check();
         obj.readStream(obj.stderr,obj.printStderr,obj.id);
         obj.readStream(obj.stdout,obj.printStdout,obj.id);
      end
      
      function count = readStream(stream,printFlag,prefix)
         % This is potentially fragile since ready() only checks whether
         % there is an element in the buffer, not a complete line.
         % Therefore, readLine() can block if the process doesn't terminate
         % all output with a carriage return...
         %
         % Alternatives inlcude:
         % 1) Implementing own low level read() and readLine()
         % 2) perhaps java.nio non-blocking methods
         % 3) Custom java class for spawning threads to manage streams
         if nargin < 3
            prefix = '';
         end
         count = 1;
         while true
            if stream.ready()
               line = stream.readLine();
               if isnumeric(line) && isempty(line)
                  % java null is empty double in matlab
                  % http://www.mathworks.com/help/matlab/matlab_external/passing-data-to-a-java-method.html
                  fprintf('\n');
                  break;
               end
               if printFlag
                  c = char(line);
                  if ~isempty(c)
                     if exist('linewrap','file') == 2
                        if isempty(prefix)
                           str = linewrap(c);
                        else
                           str = linewrap([prefix ': ' c]);
                        end
                        fprintf('%s\n',str{:});
                     else
                        if isempty(prefix)
                           str = c;
                        else
                           str = [prefix ': ' c];
                        end
                        fprintf('%s\n',str);
                     end                        
                  end
               end
               count = count + 1;
            else
               break;
            end
         end
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
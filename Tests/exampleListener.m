% A processManager object issues a notification when its process finishes.
% Listening for this notification is as simple as attaching a listener and
% defining a callback for the event.
%
% http://www.mathworks.com/help/matlab/matlab_oop/learning-to-use-events-and-listeners.html
function exampleListener
   if ispc
      cmd = 'ping -n5 www.google.com';
   else
      cmd = 'ping -c5 www.google.com';
   end
   % Create an object and attach the listener
   p = processManager('id','ping','command',cmd);
   addlistener(p,'exit',@exitHandler);

   % Define the listener callback function
   function exitHandler(src,data)
      fprintf('\n');
      fprintf('Listener notified!\n');
      fprintf('Process %s exited with exitValue = %g\n',src.id,src.exitValue);
      fprintf('\n');
   end
end
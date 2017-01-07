% This command will be parsed
p = processManager('command','ls -la');

% This command will be passed without parsing
p = processManager('command',java.lang.String('ls -la'));

% Using an array allows spaces
command = javaArray('java.lang.String',2);
command(1) = java.lang.String('ls');
command(2) = java.lang.String('-la');
command(3) = java.lang.String('test space'); % Directory name with space
p = processManager('command',command);

% This can also be done using a shell command
command = javaArray('java.lang.String',2);
command(1) = java.lang.String('sh');
command(2) = java.lang.String('-c');
command(3) = java.lang.String('ls -la test\ space');
p = processManager('command',command);


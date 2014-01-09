id = 'chain 1';
command = './bernoulli sample num_samples=1000 data file=bernoulli.data.R output file=samples1.csv refresh=5000';
workingDir = '/Users/brian/Downloads/stan-2.0.1/src/models/basic_estimators/';

p(1) = processManager('id',id,'command',command,'workingDir',workingDir,'autoStart',true);

%p(1) = processManager('id',id,'command',command,'workingDir',workingDir,'autoStart',true);

id = 'chain 2';
command = './bernoulli sample num_samples=100000 data file=bernoulli.data.R output file=samples2.csv refresh=1000';
workingDir = '/Users/brian/Downloads/stan-2.0.1/src/models/basic_estimators/';

p(2) = processManager('id',id,'command',command,'workingDir',workingDir,'autoStart',true);

id = 'compile bernoulli';
command = 'make src/models/basic_estimators/bernoulli';
workingDir = '/Users/brian/Downloads/stan-2.0.1/';
p = processManager('id',id,'command',command,'workingDir',workingDir,'autoStart',true,'printStderr',false);


% id = 'test envp';
% command = 'stanc';
% envp = 'PATH=/Users/brian/Downloads/stan-2.0.1/:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin';
% p = processManager('id',id,'command',command,'envp',{envp},'autoStart',true,'printStderr',true);

%% Run all MATLAB unit tests in this repository

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'src'));

suite = testsuite(fileparts(mfilename('fullpath')), ...
    'IncludeSubfolders', true);
results = run(suite);
disp(results);
assert(all([results.Passed]), 'One or more tests failed.');

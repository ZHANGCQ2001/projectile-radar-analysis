function startup
%STARTUP Add repository folders to the MATLAB search path.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(rootDir, 'src'));
    addpath(fullfile(rootDir, 'configs'));
    addpath(fullfile(rootDir, 'scripts'));
    addpath(fullfile(rootDir, 'examples'));
    addpath(fullfile(rootDir, 'tests'));

    fprintf('Projectile Radar Data Analysis paths added.\n');
end

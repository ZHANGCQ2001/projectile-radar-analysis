%% Run one configured data case
close all;
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'src'));
addpath(fullfile(repoRoot, 'configs'));

caseId = "0725_123207";
dataFile = "";  % Leave empty to select a BIN file interactively.

switch caseId
    case "0725_123207"
        cfg = config_0725_123207();
    case "0725_135656"
        cfg = config_0725_135656();
    case "0725_143411"
        cfg = config_0725_143411();
    otherwise
        error('Unknown caseId: %s', caseId);
end

cfg.generateRawRdGif = true;
cfg.generateMeanRemovedRdGif = true;
cfg.generateEnhancedRdGif = true;

if strlength(dataFile) == 0
    [fileName, filePath] = uigetfile( ...
        {'*.bin', 'DCA1000 raw data (*.bin)'}, ...
        'Select the DCA1000 raw data file');
    if isequal(fileName, 0)
        error('No data file was selected.');
    end
    dataFile = fullfile(filePath, fileName);
end

cfg.outputDir = fullfile(repoRoot, 'results', caseId);
result = pradar.runAnalysis(cfg, dataFile); 

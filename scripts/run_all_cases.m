%% Run all configured cases
% Fill in the three local paths before running this script.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'src'));
addpath(fullfile(repoRoot, 'configs'));

caseTable = table( ...
    ["0725_123207"; "0725_135656"; "0725_143411"], ...
    [""; ""; ""], ...
    'VariableNames', {'CaseId', 'DataFile'});

for row = 1:height(caseTable)
    caseId = caseTable.CaseId(row);
    dataFile = caseTable.DataFile(row);

    if strlength(dataFile) == 0 || ~isfile(dataFile)
        warning('Skipping %s because DataFile is not configured.', caseId);
        continue;
    end

    switch caseId
        case "0725_123207"
            cfg = config_0725_123207();
        case "0725_135656"
            cfg = config_0725_135656();
        case "0725_143411"
            cfg = config_0725_143411();
        otherwise
            warning('Skipping unknown case %s.', caseId);
            continue;
    end

    cfg.outputDir = fullfile(repoRoot, 'results', caseId);
    pradar.runAnalysis(cfg, dataFile);
end

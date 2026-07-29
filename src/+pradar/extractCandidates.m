function candidateTable = extractCandidates( ...
        rangeTimeMapDb, aliasVelocityMap, targetData, rangeAxis, cfg)
%EXTRACTCANDIDATES Extract multiple distance candidates from every window.

    globalWindow = [];
    physicalFrame = [];
    windowInFrame = [];
    timeMs = [];
    rangeM = [];
    aliasedVelocity = [];
    relativeStrength = [];
    rangeBin = [];

    rangeGate = ...
        rangeAxis(:) >= cfg.candidateRangeMin ...
        & rangeAxis(:) <= cfg.candidateRangeMax;
    validBins = find(rangeGate);

    if numel(validBins) < 3
        error('pradar:RangeGateTooNarrow', ...
            'The candidate range gate contains fewer than three bins.');
    end

    innerBins = (validBins(1) + 1):(validBins(end) - 1);

    for windowIndex = 1:size(rangeTimeMapDb, 2)
        profile = double(rangeTimeMapDb(:, windowIndex));
        profileSmooth = movmean( ...
            profile, cfg.rangeSmoothBins, 'omitnan');
        profileSmooth(~rangeGate) = -Inf;

        isLocalPeak = false(numel(profileSmooth), 1);
        isLocalPeak(innerBins) = ...
            profileSmooth(innerBins) >= profileSmooth(innerBins - 1) ...
            & profileSmooth(innerBins) > profileSmooth(innerBins + 1);

        peakIndices = find( ...
            isLocalPeak ...
            & profileSmooth >= cfg.candidateThresholdDb);

        if isempty(peakIndices)
            continue;
        end

        [~, order] = sort(profileSmooth(peakIndices), 'descend');
        peakIndices = peakIndices(order);
        selectedIndices = [];

        for peakIndex = 1:numel(peakIndices)
            currentBin = peakIndices(peakIndex);
            currentRange = rangeAxis(currentBin);

            if isempty(selectedIndices)
                separated = true;
            else
                separated = all( ...
                    abs(rangeAxis(selectedIndices) - currentRange) ...
                    >= cfg.minCandidateSeparation);
            end

            if separated
                selectedIndices(end + 1) = currentBin; %#ok<AGROW>
                if numel(selectedIndices) >= cfg.maxCandidatesPerWindow
                    break;
                end
            end
        end

        for selectedIndex = 1:numel(selectedIndices)
            currentBin = selectedIndices(selectedIndex);
            currentVelocity = aliasVelocityMap(currentBin, windowIndex);

            if ~isfinite(currentVelocity)
                continue;
            end

            globalWindow(end + 1, 1) = windowIndex; %#ok<AGROW>
            physicalFrame(end + 1, 1) = ...
                targetData.windowPhysicalFrame(windowIndex); %#ok<AGROW>
            windowInFrame(end + 1, 1) = ...
                targetData.windowIndexInFrame(windowIndex); %#ok<AGROW>
            timeMs(end + 1, 1) = ...
                targetData.windowTimeMs(windowIndex); %#ok<AGROW>
            rangeM(end + 1, 1) = rangeAxis(currentBin); %#ok<AGROW>
            aliasedVelocity(end + 1, 1) = currentVelocity; %#ok<AGROW>
            relativeStrength(end + 1, 1) = ...
                profileSmooth(currentBin); %#ok<AGROW>
            rangeBin(end + 1, 1) = currentBin; %#ok<AGROW>
        end
    end

    candidateTable = table( ...
        globalWindow, physicalFrame, windowInFrame, timeMs, rangeM, ...
        aliasedVelocity, relativeStrength, rangeBin, ...
        'VariableNames', { ...
            'GlobalWindow', 'PhysicalFrame', 'WindowInFrame', ...
            'Time_ms', 'Range_m', 'AliasedVelocity_mps', ...
            'RelativeStrength_dB', 'RangeBin'});
end

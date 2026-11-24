function [targetMask, startFrame, endFrame, thresholdDb] = detectTargetFramesFromSnr(frameSnr, varargin)
%DETECTTARGETFRAMESFROMSNR 从每帧最大 SNR 曲线中检测目标帧区间
%   [targetMask, startFrame, endFrame, thresholdDb] = ...
%       radarui.detectTargetFramesFromSnr(frameSnr, ...)
%
%   方法：一维 OS-CFAR + 双阈值滞回 + 最短游程判决。
%   SNR 曲线本身是二维 CFAR 输出，无目标帧的 SNR 为正偏置（近似 Gumbel
%   分布），因此门限按"参考窗排序分位 + dB 域经验余量"构造，不使用
%   经典 CA-CFAR 的 alpha = N(Pfa^(-1/N)-1) 公式（该式假设单指数噪声）。
%
%   输入:
%     frameSnr - 每帧最大 SNR 向量 (dB)，NaN 表示该帧无有效点
%
%   可选参数 (名称-值):
%     'Guard'        : 检测单元两侧保护帧数 (默认 2)
%     'Ref'          : 每侧参考窗帧数 (默认 12)
%     'K'            : OS 排序分位 0~1 (默认 0.25，低分位代表噪声，抗目标污染)
%     'MarginDb'     : 超出背景的门限余量 dB (默认 5)
%     'HysteresisDb' : 退出回差 dB，进入门限减该值即退出门限 (默认 3)
%     'MinRun'       : 最短连续目标帧数 (默认 3)
%
%   输出:
%     targetMask  - 逻辑向量，true 表示该帧判为目标
%     startFrame  - 各目标段起始帧索引
%     endFrame    - 各目标段终止帧索引
%     thresholdDb - 各帧进入门限 (dB)，参考样本不足时为 NaN

    p = inputParser;
    p.addParameter('Guard', 2, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    p.addParameter('Ref', 12, @(v) isnumeric(v) && isscalar(v) && v >= 1);
    p.addParameter('K', 0.25, @(v) isnumeric(v) && isscalar(v) && v > 0 && v < 1);
    p.addParameter('MarginDb', 5, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    p.addParameter('HysteresisDb', 3, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    p.addParameter('MinRun', 3, @(v) isnumeric(v) && isscalar(v) && v >= 1);
    p.parse(varargin{:});

    guard = round(p.Results.Guard);
    refLen = round(p.Results.Ref);
    kFrac = p.Results.K;
    marginDb = p.Results.MarginDb;
    hystDb = p.Results.HysteresisDb;
    minRun = round(p.Results.MinRun);

    s = frameSnr(:);
    n = numel(s);
    targetMask = false(n, 1);
    startFrame = [];
    endFrame = [];
    thresholdDb = nan(n, 1);
    if n == 0
        return;
    end

    valid = isfinite(s);
    if ~any(valid)
        return;
    end

    % 全局背景兜底：低分位代表无目标帧的 SNR 水平，避免长目标把局部
    % 参考窗整体抬高后门限失效。用 sort 实现，不依赖 Statistics 工具箱。
    sv = sort(s(valid));
    globalBase = sv(max(1, ceil(0.30 * numel(sv))));

    % 逐帧 OS-CFAR 背景估计（保护带内样本不参与）
    for i = 1:n
        if ~valid(i)
            continue;
        end
        leftEnd = i - guard - 1;
        if leftEnd >= 1
            leftIdx = max(1, leftEnd - refLen + 1) : leftEnd;
        else
            leftIdx = [];
        end
        rightStart = i + guard + 1;
        if rightStart <= n
            rightIdx = rightStart : min(n, rightStart + refLen - 1);
        else
            rightIdx = [];
        end
        refSamples = s([leftIdx, rightIdx]);
        refSamples = refSamples(isfinite(refSamples));
        if numel(refSamples) < 3
            continue;
        end
        refSorted = sort(refSamples);
        kIdx = max(1, min(numel(refSorted), ceil(kFrac * numel(refSorted))));
        noiseLocal = refSorted(kIdx);
        % 参考窗若被目标能量整体抬高，回退到全局背景（上限留足余量）
        noiseEst = min(noiseLocal, globalBase + 3 * marginDb);
        thresholdDb(i) = noiseEst + marginDb;
    end

    % 双阈值滞回：未进入时用进入门限判进入，已进入后用退出门限判退出
    inTarget = false;
    rawMask = false(n, 1);
    for i = 1:n
        if ~valid(i) || isnan(thresholdDb(i))
            rawMask(i) = inTarget;
            continue;
        end
        if ~inTarget
            if s(i) > thresholdDb(i)
                inTarget = true;
            end
        elseif s(i) <= thresholdDb(i) - hystDb
            inTarget = false;
        end
        rawMask(i) = inTarget;
    end

    % 最短游程：剔除短于 MinRun 的孤立段（烟尘短峰）
    if any(rawMask)
        edges = diff([false; rawMask; false]);
        starts = find(edges == 1);
        stops  = find(edges == -1) - 1;
        keep = (stops - starts + 1) >= minRun;
        starts = starts(keep);
        stops  = stops(keep);
        for j = 1:numel(starts)
            targetMask(starts(j):stops(j)) = true;
        end
        startFrame = starts(:);
        endFrame = stops(:);
    end
end

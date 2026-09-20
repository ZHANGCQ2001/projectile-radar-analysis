classdef ProcessingController < handle
%PROCESSINGCONTROLLER Own one upper-machine processing run and cancellation.

    properties (SetAccess = private)
        IsRunning logical = false
        CancelRequested logical = false
        Result = []
        LastError = []
    end

    methods
        function result = run(obj, dataFile, cfg, progressFcn)
            if nargin < 4
                progressFcn = [];
            end

            if obj.IsRunning
                error('radarui:ProcessingAlreadyRunning', ...
                    'A processing run is already active.');
            end

            obj.IsRunning = true;
            obj.CancelRequested = false;
            obj.Result = [];
            obj.LastError = [];

            cleanupObject = onCleanup(@() obj.finishRun()); %#ok<NASGU>

            try
                result = pradar.runAnalysisCore( ...
                    cfg, ...
                    dataFile, ...
                    progressFcn, ...
                    @() obj.CancelRequested);

                obj.Result = result;
            catch ME
                obj.LastError = ME;
                rethrow(ME);
            end
        end

        function requestCancel(obj)
            if obj.IsRunning
                obj.CancelRequested = true;
            end
        end

        function reset(obj)
            if obj.IsRunning
                error('radarui:ProcessingBusy', ...
                    'Cannot reset while processing is active.');
            end

            obj.CancelRequested = false;
            obj.Result = [];
            obj.LastError = [];
        end
    end

    methods (Access = private)
        function finishRun(obj)
            obj.IsRunning = false;
        end
    end
end

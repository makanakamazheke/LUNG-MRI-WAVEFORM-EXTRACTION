% detect_abnormal_agreement.m
% Running RR outlier detection on manual, automated, and deformation waveforms,
% and computing pairwise agreement between methods (no ground truth assumed this time).

clear; close all;

%% 1. Defining paths
manualRoot = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\Waveform Outputs\Manual';
mlRoot     = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\Waveform Outputs\ML';
deformRoot = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\Waveform Outputs\Deformation';
outputDir  = "C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\abnormal";

if ~exist(outputDir,'dir'); mkdir(outputDir); end

%% 2. Getting all slice folders (using manual files as index)
manualFiles = dir(fullfile(manualRoot, '**', 'manual_waveform.mat'));
fprintf('Found %d manual waveform files.\n', length(manualFiles));

results = table();

for i = 1:length(manualFiles)
    % Extracting patient and slice
    [pathStr,~,~] = fileparts(manualFiles(i).folder);
    [~, sliceName] = fileparts(manualFiles(i).folder);
    [~, patientName] = fileparts(pathStr);
    
    fprintf('\nProcessing %s / %s...\n', patientName, sliceName);
    
    %% Loading all three waveforms
    % Manual
    manFile = fullfile(manualFiles(i).folder, manualFiles(i).name);
    manData = load(manFile, 'Signal', 'time', 'fs');
    if ~isfield(manData, 'Signal') || ~isfield(manData, 'time') || ~isfield(manData, 'fs')
        fprintf('  Manual waveform missing required fields. Skipping.\n');
        continue;
    end
    sig_man = manData.Signal(:);
    time = manData.time(:);
    fs = manData.fs;
    
    % Automated
    autoFile = fullfile(mlRoot, patientName, sliceName, 'automated_waveform.mat');
    if ~exist(autoFile, 'file')
        fprintf('  Automated waveform missing. Skipping.\n');
        continue;
    end
    autoData = load(autoFile, 'Signal');
    sig_auto = autoData.Signal(:);
    if length(sig_auto) ~= length(time)
        warning('  Auto signal length mismatch. Skipping.');
        continue;
    end
    
    % Deformation
    deformFile = fullfile(deformRoot, patientName, sliceName, 'deformation_waveform.mat');
    if ~exist(deformFile, 'file')
        fprintf('  Deformation waveform missing. Skipping.\n');
        continue;
    end
    deformData = load(deformFile, 'Signal');
    sig_deform = deformData.Signal(:);
    if length(sig_deform) ~= length(time)
        warning('  Deform signal length mismatch. Skipping.');
        continue;
    end
    
    %% Detecting EE times for each method
    [ee_man, ~] = detect_EE_EI(sig_man, time, fs);
    [ee_auto, ~] = detect_EE_EI(sig_auto, time, fs);
    [ee_deform, ~] = detect_EE_EI(sig_deform, time, fs);
    
    %% Getting abnormal intervals using RR outlier (threshold=2)
    [int_man, ~] = detect_abnormal_RR(ee_man, time, sig_man, fs, 'threshold', 2, 'plot', false);
    [int_auto, ~] = detect_abnormal_RR(ee_auto, time, sig_auto, fs, 'threshold', 2, 'plot', false);
    [int_deform, ~] = detect_abnormal_RR(ee_deform, time, sig_deform, fs, 'threshold', 2, 'plot', false);
    
    % Counting intervals per method
    n_man = size(int_man, 1);
    n_auto = size(int_auto, 1);
    n_deform = size(int_deform, 1);
    
    % Pairwise overlaps (so its symmetric: so, any overlap between any intervals)
    % Computing for each pair the number of intervals from method A that
    % have at least one overlapping interval from method B.
    
    % Helper function to compute matches
    match_man_auto = count_overlaps(int_man, int_auto);
    match_man_deform = count_overlaps(int_man, int_deform);
    match_auto_deform = count_overlaps(int_auto, int_deform);
    
    % Overlapping of all three: intervals from manual that overlap with at least one auto AND at least one deform
    if n_man > 0 && n_auto > 0 && n_deform > 0
        match_all = 0;
        for j = 1:n_man
            overlaps_auto = false;
            for k = 1:n_auto
                if intervals_overlap(int_man(j,:), int_auto(k,:))
                    overlaps_auto = true;
                    break;
                end
            end
            overlaps_deform = false;
            for k = 1:n_deform
                if intervals_overlap(int_man(j,:), int_deform(k,:))
                    overlaps_deform = true;
                    break;
                end
            end
            if overlaps_auto && overlaps_deform
                match_all = match_all + 1;
            end
        end
    else
        match_all = 0;
    end
    
    % Storing in results table
    newRow = table({patientName}, {sliceName}, n_man, n_auto, n_deform, ...
                   match_man_auto, match_man_deform, match_auto_deform, match_all, ...
                   'VariableNames', {'Patient','Slice','N_man','N_auto','N_deform', ...
                   'Match_man_auto','Match_man_deform','Match_auto_deform','Match_all'});
    results = [results; newRow];
end

%% Displaying summary
fprintf('\n--- Summary of Abnormal Interval Detection (all methods) ---\n');
disp(results);

% Saving results
writetable(results, fullfile(outputDir, 'abnormal_detection_agreement.csv'));
save(fullfile(outputDir, 'abnormal_detection_agreement.mat'), 'results');

%% Helper functions

function [ee_times, ei_times] = detect_EE_EI(signal, time, fs)
    [~, locs_peak] = findpeaks(signal, 'MinPeakDistance', round(2*fs));
    ee_times = time(locs_peak);
    [~, locs_trough] = findpeaks(-signal, 'MinPeakDistance', round(2*fs));
    ei_times = time(locs_trough);
end

function [intervals, fig] = detect_abnormal_RR(ee_times, time, signal, fs, varargin)
    p = inputParser;
    addParameter(p, 'threshold', 2, @(x) isnumeric(x) && x>0);
    addParameter(p, 'plot', false, @islogical);
    parse(p, varargin{:});
    thr = p.Results.threshold;
    doPlot = p.Results.plot;

    intervals = [];
    fig = [];

    if length(ee_times) < 2
        if doPlot
            warning('Less than two peaks detected – cannot compute RR.');
        end
        return;
    end

    breath_durations = diff(ee_times);
    rr_inst = 60 ./ breath_durations;

    med_rr = median(rr_inst);
    mad_rr = median(abs(rr_inst - med_rr));

    outlier_idx = abs(rr_inst - med_rr) > thr * mad_rr;

    if ~any(outlier_idx)
        return;
    end

    outlier_cycles = find(outlier_idx);
    intervals = [ee_times(outlier_cycles), ee_times(outlier_cycles+1)];

    if doPlot
        fig = figure;
        plot(time, signal, 'b-', 'LineWidth', 1); hold on;
        plot(ee_times, interp1(time, signal, ee_times), 'ko', 'MarkerSize', 6);
        yl = ylim;
        for k = 1:size(intervals,1)
            patch([intervals(k,1) intervals(k,2) intervals(k,2) intervals(k,1)], ...
                  [yl(1) yl(1) yl(2) yl(2)], 'r', ...
                  'FaceAlpha', 0.2, 'EdgeColor', 'none');
        end
        xlabel('Time (s)');
        ylabel('Signal');
        title(sprintf('RR outlier detection (threshold = %.1f × MAD)', thr));
        legend('Signal', 'Peaks', 'Abnormal cycles');
        grid on;
    end
end

function tf = intervals_overlap(A, B)
    % A and B are 1x2 vectors [start end]
    tf = (A(1) <= B(2)) && (A(2) >= B(1));
end

function matches = count_overlaps(intA, intB)
    % For each interval in A, count how many have any overlap with any interval in B.
    matches = 0;
    for i = 1:size(intA,1)
        for j = 1:size(intB,1)
            if intervals_overlap(intA(i,:), intB(j,:))
                matches = matches + 1;
                break;  % only count once per A interval
            end
        end
    end
end
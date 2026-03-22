% This script makes use of the variables saved during the extraction stages.

% Here, I am loading the manual and automated waveforms that I previously extracted.
% I am computing per‑slice and per‑patient metrics to compare the two methods.
% I am also generating overlay plots for each slice, displaying the waveforms and annotating them with the computed metrics.
% The main metrics I am computing are:
%   - Correlation (r) – measuring the linear agreement between the waveforms.
%   - Mean Absolute Error (MAE) – measuring the average absolute difference.
%   - Lag (in seconds) – measuring any time shift between the signals.
%   - Phase agreement – the proportion of time points where both waveforms
%     are moving in the same direction (increasing or decreasing).
%   - End‑Expiration (EE) and End‑Inspiration (EI) timing differences.
%   - Respiratory rate (RR) derived from the detected peaks.
% Additionally, I am evaluating robustness by computing metrics on automatically
% detected abnormal intervals (intervals_auto) that were marked in a previous step.
% All results are saved both as MATLAB .mat files and as CSV tables for easy inspection. 
% Figures are kept open so I can review them after the script finishes.

clear; close all;

%% 1. Defining paths

% I am organising all outputs into clearly named folders to avoid confusion.
% manualRoot points to the folder where all manual ROI waveforms are stored.
% mlRoot points to the folder where all automated (ML) waveforms are stored.
% deformRoot points to the folder where all deformation‑based waveforms will be stored.
% outputDir is where I will save the comparison results (tables, figures, etc.).

manualRoot = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\Waveform Outputs\Manual';
mlRoot     = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\Waveform Outputs\ML';
deformRoot = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\Waveform Outputs\Deformation';
outputDir  = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\comparison data all';

% Creating the output directory if it does not already exist.
if ~exist(outputDir,'dir'); mkdir(outputDir); end

%% 2. Finding all waveform files and building a unified table

% I am recursively searching for all manual_waveform.mat files under manualRoot,
% all automated_waveform.mat files under mlRoot, and all deformation_waveform.mat
% files under deformRoot. This gathers every waveform that was extracted.

manualFiles = dir(fullfile(manualRoot, '**', 'manual_waveform.mat'));
mlFiles     = dir(fullfile(mlRoot,     '**', 'automated_waveform.mat'));
deformFiles = dir(fullfile(deformRoot, '**', 'deformation_waveform.mat'));

% Initialising an empty table that will hold all waveforms together.
waveforms = table();

% Processing manual files 
% For each manual file, I need to extract the patient name and slice name from
% the folder structure. The expected path format is:
%   ...\Manual\HV_002\raw_IM_0019\manual_waveform.mat
% I use fileparts repeatedly to get the slice folder name and then the patient
% folder name from the parent directory.

for i = 1:length(manualFiles)
    [pathStr,~,~] = fileparts(manualFiles(i).folder);
    [~, sliceName] = fileparts(manualFiles(i).folder);
    [~, patientName] = fileparts(pathStr);
    data = load(fullfile(manualFiles(i).folder, manualFiles(i).name));
    % This is analogous to building a DataFrame in pandas: I am collecting
    % all relevant information into one table row. The Signal is stored as a
    % row vector, and I also store the time vector, TA, and fs.
    newRow = table({patientName}, {sliceName}, {'manual'}, ...
                   {data.Signal(:)'}, data.time(:)', data.TA, data.fs, ...
                   'VariableNames',{'Patient','Slice','Method','Signal','time','TA','fs'});
    waveforms = [waveforms; newRow];
end

% Processing automated (ML) files 
% The same logic applies for the automated waveforms; they follow a parallel
% folder structure under ...\ML\HV_002\raw_IM_0019\automated_waveform.mat.
for i = 1:length(mlFiles)
    [pathStr,~,~] = fileparts(mlFiles(i).folder);
    [~, sliceName] = fileparts(mlFiles(i).folder);
    [~, patientName] = fileparts(pathStr);
    data = load(fullfile(mlFiles(i).folder, mlFiles(i).name));
    newRow = table({patientName}, {sliceName}, {'automated'}, ...
                   {data.Signal(:)'}, data.time(:)', data.TA, data.fs, ...
                   'VariableNames',{'Patient','Slice','Method','Signal','time','TA','fs'});
    waveforms = [waveforms; newRow];
end

% Processing deformation files
% They are expected to be in ...\Deformation\HV_002\raw_IM_0019\deformation_waveform.mat
for i = 1:length(deformFiles)
    [pathStr,~,~] = fileparts(deformFiles(i).folder);
    [~, sliceName] = fileparts(deformFiles(i).folder);
    [~, patientName] = fileparts(pathStr);
    data = load(fullfile(deformFiles(i).folder, deformFiles(i).name));
    newRow = table({patientName}, {sliceName}, {'deformation'}, ...
                   {data.Signal(:)'}, data.time(:)', data.TA, data.fs, ...
                   'VariableNames',{'Patient','Slice','Method','Signal','time','TA','fs'});
    waveforms = [waveforms; newRow];
end

% Displaying the total number of waveforms loaded.
fprintf('Loaded %d waveforms.\n', height(waveforms));

%% 3. Helper functions for computing metrics

% These functions are defined inside the script for clarity; they could also be moved to separate files. 
% I am keeping them here to make the script self‑contained.

% pairwise_metrics: computes correlation, MAE, and lag between two signals.
%   Inputs: s1, s2 (the two signals), TA (time per frame in seconds).
%   Outputs: r (Pearson correlation), MAE (mean absolute error),
%            lag_s (time shift at maximum cross‑correlation, in seconds).

function [r, MAE, lag_s] = pairwise_metrics(s1, s2, TA)

    % Ensuring that both signals have the same length; if not, truncate.
    if length(s1) ~= length(s2)
        minLen = min(length(s1), length(s2));
        s1 = s1(1:minLen);
        s2 = s2(1:minLen);
    end

    % Pearson correlation coefficient from the correlation matrix.
    R = corrcoef(s1, s2);
    r = R(1,2);

    % Mean absolute error: average of absolute point‑wise differences.
    MAE = mean(abs(s1 - s2));

    % Cross‑correlation of mean‑centred signals (normalised to [‑1,1]).
    % The 'coeff' option gives normalised values so that autocorrelation at
    % zero lag is 1. lags are in samples.
    [xc, lags] = xcorr(s1 - mean(s1), s2 - mean(s2), 'coeff');

    % Finding the lag where the cross‑correlation is maximal.
    [~, idx] = max(xc);

    % Converting from samples to seconds by multiplying by TA.
    lag_s = lags(idx) * TA;
end

% detect_EE_EI: finds End‑Expiration (peaks) and End‑Inspiration (troughs)
% in a respiratory waveform. No smoothing is applied; I use the raw signal directly.

%   Inputs: signal (1‑D array), time (corresponding time vector), fs (Hz).
%   Outputs: ee_times (times of peaks), ei_times (times of troughs).

function [ee_times, ei_times] = detect_EE_EI(signal, time, fs)

    % Peaks are detected using findpeaks. I set a minimum distance of 2 seconds
    % between peaks to avoid detecting spurious fluctuations. This distance is
    % based on a typical minimum breath duration.

    [~, locs_peak] = findpeaks(signal, 'MinPeakDistance', round(3*fs));
    ee_times = time(locs_peak);
    
    % Troughs are found by inverting the signal (-signal) and then applying
    % the same peak‑finding logic. The same minimum distance is used.

    [~, locs_trough] = findpeaks(-signal, 'MinPeakDistance', round(2*fs));
    ei_times = time(locs_trough);
end

%% 4. Per‑slice comparison

% Here I iterate over every unique combination of patient and slice, extract
% the corresponding manual, automated, and deformation waveforms, and compute
% all pairwise metrics for the three methods. The results are stored in the
% perSlice table. I also initialise a separate table perSliceAbnormal to hold
% metrics computed only on the automatically marked abnormal intervals (if any exist).

fprintf('\n--- Per-slice comparison (now with three methods) ---\n');
slices = unique(waveforms(:,{'Patient','Slice'}), 'rows');
perSlice = table();
perSliceAbnormal = table();

for i = 1:height(slices)
    pat = slices.Patient{i};
    slc = slices.Slice{i};   % slc is a character vector (slice name)
    
    % Extracting the manual waveform row for this patient and slice.
    man = waveforms(strcmp(waveforms.Patient, pat) & ...
                    strcmp(waveforms.Slice, slc) & ...
                    strcmp(waveforms.Method, 'manual'), :);
    % Extracting the automated waveform row for the same patient and slice.
    auto = waveforms(strcmp(waveforms.Patient, pat) & ...
                     strcmp(waveforms.Slice, slc) & ...
                     strcmp(waveforms.Method, 'automated'), :);
    % Extracting the deformation waveform row.
    deform = waveforms(strcmp(waveforms.Patient, pat) & ...
                       strcmp(waveforms.Slice, slc) & ...
                       strcmp(waveforms.Method, 'deformation'), :);
    
    % If any of the three methods is missing for this slice, skip it.
    if isempty(man) || isempty(auto) || isempty(deform)
        continue;
    end
    
    % Retrieving the actual signal vectors and basic parameters.
    sig_man = man.Signal{1};
    sig_auto = auto.Signal{1};
    sig_deform = deform.Signal{1};
    time = man.time;            % time vector (assumed identical for all)
    fs = man.fs(1);             % sampling frequency
    TA = man.TA(1);              % time per frame
    
    % Compute pairwise metrics for each pair of methods.
    % Manual vs Automated
    [r_ma, MAE_ma, lag_ma] = pairwise_metrics(sig_man, sig_auto, TA);
    % Manual vs Deformation
    [r_md, MAE_md, lag_md] = pairwise_metrics(sig_man, sig_deform, TA);
    % Automated vs Deformation
    [r_ad, MAE_ad, lag_ad] = pairwise_metrics(sig_auto, sig_deform, TA);
    
    % Detect EE and EI points for all three methods.
    [ee_man, ei_man] = detect_EE_EI(sig_man, time, fs);
    [ee_auto, ei_auto] = detect_EE_EI(sig_auto, time, fs);
    [ee_deform, ei_deform] = detect_EE_EI(sig_deform, time, fs);
    
    % Number of detected cycles (using EE count as a proxy).
    n_man = length(ee_man);
    n_auto = length(ee_auto);
    n_deform = length(ee_deform);
    
    % Compute EE and EI timing differences for each pair.
    % Manual vs Auto
    n_ee_ma = min(n_man, n_auto);
    if n_ee_ma > 0
        ee_diff_ma = mean(abs(ee_man(1:n_ee_ma) - ee_auto(1:n_ee_ma)));
    else
        ee_diff_ma = NaN;
    end
    n_ei_ma = min(length(ei_man), length(ei_auto));
    if n_ei_ma > 0
        ei_diff_ma = mean(abs(ei_man(1:n_ei_ma) - ei_auto(1:n_ei_ma)));
    else
        ei_diff_ma = NaN;
    end
    
    % Manual vs Deformation
    n_ee_md = min(n_man, n_deform);
    if n_ee_md > 0
        ee_diff_md = mean(abs(ee_man(1:n_ee_md) - ee_deform(1:n_ee_md)));
    else
        ee_diff_md = NaN;
    end
    n_ei_md = min(length(ei_man), length(ei_deform));
    if n_ei_md > 0
        ei_diff_md = mean(abs(ei_man(1:n_ei_md) - ei_deform(1:n_ei_md)));
    else
        ei_diff_md = NaN;
    end
    
    % Auto vs Deformation
    n_ee_ad = min(n_auto, n_deform);
    if n_ee_ad > 0
        ee_diff_ad = mean(abs(ee_auto(1:n_ee_ad) - ee_deform(1:n_ee_ad)));
    else
        ee_diff_ad = NaN;
    end
    n_ei_ad = min(length(ei_auto), length(ei_deform));
    if n_ei_ad > 0
        ei_diff_ad = mean(abs(ei_auto(1:n_ei_ad) - ei_deform(1:n_ei_ad)));
    else
        ei_diff_ad = NaN;
    end
    
    % Phase agreement for each pair.
    dir_man = diff(sig_man) > 0;
    dir_auto = diff(sig_auto) > 0;
    dir_deform = diff(sig_deform) > 0;
    minLen = min([length(dir_man), length(dir_auto), length(dir_deform)]);
    phase_ma = mean(dir_man(1:minLen) == dir_auto(1:minLen));
    phase_md = mean(dir_man(1:minLen) == dir_deform(1:minLen));
    phase_ad = mean(dir_auto(1:minLen) == dir_deform(1:minLen));
    
    % Respiratory rate (breaths per minute) from EE times.
    if n_man >= 2
        rr_man = 60 / mean(diff(ee_man));
    else
        rr_man = NaN;
    end
    if n_auto >= 2
        rr_auto = 60 / mean(diff(ee_auto));
    else
        rr_auto = NaN;
    end
    if n_deform >= 2
        rr_deform = 60 / mean(diff(ee_deform));
    else
        rr_deform = NaN;
    end
    rr_diff_ma = abs(rr_man - rr_auto);
    rr_diff_md = abs(rr_man - rr_deform);
    rr_diff_ad = abs(rr_auto - rr_deform);
    
    % Wrapping the slice name in a cell array to avoid MATLAB interpreting it
    % as a table variable name. Adding the row to perSlice.
    % I now store all pairwise metrics, along with individual cycle counts and RR.
    newRow = table({pat}, {slc}, ...
                   r_ma, MAE_ma, lag_ma, ee_diff_ma, ei_diff_ma, phase_ma, ...
                   r_md, MAE_md, lag_md, ee_diff_md, ei_diff_md, phase_md, ...
                   r_ad, MAE_ad, lag_ad, ee_diff_ad, ei_diff_ad, phase_ad, ...
                   n_man, n_auto, n_deform, ...
                   rr_man, rr_auto, rr_deform, ...
                   rr_diff_ma, rr_diff_md, rr_diff_ad, ...
                   'VariableNames', ...
                   {'Patient','Slice', ...
                    'Corr_man_auto','MAE_man_auto','Lag_man_auto','EE_diff_man_auto','EI_diff_man_auto','PhaseAgree_man_auto', ...
                    'Corr_man_deform','MAE_man_deform','Lag_man_deform','EE_diff_man_deform','EI_diff_man_deform','PhaseAgree_man_deform', ...
                    'Corr_auto_deform','MAE_auto_deform','Lag_auto_deform','EE_diff_auto_deform','EI_diff_auto_deform','PhaseAgree_auto_deform', ...
                    'nCycles_man','nCycles_auto','nCycles_deform', ...
                    'RR_man','RR_auto','RR_deform', ...
                    'RR_diff_man_auto','RR_diff_man_deform','RR_diff_auto_deform'});
    perSlice = [perSlice; newRow];
    
    % Robustness: computing metrics on automatically detected abnormal intervals 
    % I look for the file manual_waveform.mat in the slice's output folder.
    % This part now also computes metrics for the deformation pairs.
    manFile = fullfile(manualRoot, pat, slc, 'manual_waveform.mat');
    if exist(manFile, 'file')
        mf = load(manFile);

        % If intervals_auto exists (from the robustness marking script), I use it.
        if isfield(mf, 'intervals_auto') && ~isempty(mf.intervals_auto)
            intervals_auto = mf.intervals_auto;  % Nx2 matrix [start, end] in seconds
            for k = 1:size(intervals_auto,1)

                % Finding the time indices that fall inside this interval.
                idx = time >= intervals_auto(k,1) & time <= intervals_auto(k,2);
                if sum(idx) < 2
                    warning('Interval [%.2f,%.2f] too short, skipping.', intervals_auto(k,1), intervals_auto(k,2));
                    continue;
                end

                % Computing metrics for all three pairs on this segment.
                [r_ma_seg, MAE_ma_seg, lag_ma_seg] = pairwise_metrics(sig_man(idx), sig_auto(idx), TA);
                [r_md_seg, MAE_md_seg, lag_md_seg] = pairwise_metrics(sig_man(idx), sig_deform(idx), TA);
                [r_ad_seg, MAE_ad_seg, lag_ad_seg] = pairwise_metrics(sig_auto(idx), sig_deform(idx), TA);
                
                % Count cycles within interval for each method
                ee_man_in = ee_man(ee_man >= intervals_auto(k,1) & ee_man <= intervals_auto(k,2));
                ee_auto_in = ee_auto(ee_auto >= intervals_auto(k,1) & ee_auto <= intervals_auto(k,2));
                ee_deform_in = ee_deform(ee_deform >= intervals_auto(k,1) & ee_deform <= intervals_auto(k,2));
                
                n_man_seg = length(ee_man_in);
                n_auto_seg = length(ee_auto_in);
                n_deform_seg = length(ee_deform_in);
                
                % RR within interval (if at least 2 EE points)
                if n_man_seg >= 2
                    rr_man_seg = 60 / mean(diff(ee_man_in));
                else
                    rr_man_seg = NaN;
                end
                if n_auto_seg >= 2
                    rr_auto_seg = 60 / mean(diff(ee_auto_in));
                else
                    rr_auto_seg = NaN;
                end
                if n_deform_seg >= 2
                    rr_deform_seg = 60 / mean(diff(ee_deform_in));
                else
                    rr_deform_seg = NaN;
                end
                
                % Phase agreement within interval
                dir_man_seg = diff(sig_man(idx)) > 0;
                dir_auto_seg = diff(sig_auto(idx)) > 0;
                dir_deform_seg = diff(sig_deform(idx)) > 0;
                minLen_seg = min([length(dir_man_seg), length(dir_auto_seg), length(dir_deform_seg)]);
                phase_ma_seg = mean(dir_man_seg(1:minLen_seg) == dir_auto_seg(1:minLen_seg));
                phase_md_seg = mean(dir_man_seg(1:minLen_seg) == dir_deform_seg(1:minLen_seg));
                phase_ad_seg = mean(dir_auto_seg(1:minLen_seg) == dir_deform_seg(1:minLen_seg));

                newRowAb = table({pat}, {slc}, k, intervals_auto(k,1), intervals_auto(k,2), ...
                                 r_ma_seg, MAE_ma_seg, lag_ma_seg, ...
                                 r_md_seg, MAE_md_seg, lag_md_seg, ...
                                 r_ad_seg, MAE_ad_seg, lag_ad_seg, ...
                                 n_man_seg, n_auto_seg, n_deform_seg, ...
                                 rr_man_seg, rr_auto_seg, rr_deform_seg, ...
                                 phase_ma_seg, phase_md_seg, phase_ad_seg, ...
                                 'VariableNames',{'Patient','Slice','SegmentID','Start_s','End_s', ...
                                                  'Corr_man_auto','MAE_man_auto','Lag_man_auto', ...
                                                  'Corr_man_deform','MAE_man_deform','Lag_man_deform', ...
                                                  'Corr_auto_deform','MAE_auto_deform','Lag_auto_deform', ...
                                                  'nCycles_man','nCycles_auto','nCycles_deform', ...
                                                  'RR_man','RR_auto','RR_deform', ...
                                                  'PhaseAgree_man_auto','PhaseAgree_man_deform','PhaseAgree_auto_deform'});
                perSliceAbnormal = [perSliceAbnormal; newRowAb];
            end
        end
    end
end
fprintf('Processed %d slices.\n', height(perSlice));
fprintf('Found %d abnormal segments.\n', height(perSliceAbnormal));

%% 5. Per‑patient comparison (averaging across slices)
% For each patient, I average the signals from all slices to obtain a single
% representative manual, automated, and deformation waveform. Then I compute the same
% pairwise metrics on these average signals. Additionally, I aggregate the
% per‑slice metrics by taking their mean (ignoring NaNs) to give a patient‑level
% summary.

fprintf('\n--- Per-patient comparison ---\n');
patients = unique(waveforms.Patient);
perPatient = table();

for p = 1:length(patients)
    pat = patients{p};
    patData = waveforms(strcmp(waveforms.Patient, pat), :);
    slices_pat = unique(patData.Slice);
    
    % Collecting signals from all slices for each method.
    man_signals = [];
    auto_signals = [];
    deform_signals = [];
    
    for s = 1:length(slices_pat)
        slc = slices_pat{s};
        manRow = patData(strcmp(patData.Method, 'manual') & strcmp(patData.Slice, slc), :);
        autoRow = patData(strcmp(patData.Method, 'automated') & strcmp(patData.Slice, slc), :);
        deformRow = patData(strcmp(patData.Method, 'deformation') & strcmp(patData.Slice, slc), :);
        if ~isempty(manRow)
            man_signals = [man_signals; manRow.Signal{1}];
        end
        if ~isempty(autoRow)
            auto_signals = [auto_signals; autoRow.Signal{1}];
        end
        if ~isempty(deformRow)
            deform_signals = [deform_signals; deformRow.Signal{1}];
        end
    end
    
    % If any method has no signals for this patient, skip.
    if isempty(man_signals) || isempty(auto_signals) || isempty(deform_signals)
        continue;
    end
    
    % Averaging across slices (row‑wise mean of the matrix of signals).
    avg_man = mean(man_signals, 1);
    avg_auto = mean(auto_signals, 1);
    avg_deform = mean(deform_signals, 1);
    TA = mean(patData.TA);   % TA should be the same for all slices; taking the mean.
    
    % Compute pairwise metrics on averaged signals.
    [r_ma, MAE_ma, lag_ma] = pairwise_metrics(avg_man, avg_auto, TA);
    [r_md, MAE_md, lag_md] = pairwise_metrics(avg_man, avg_deform, TA);
    [r_ad, MAE_ad, lag_ad] = pairwise_metrics(avg_auto, avg_deform, TA);
    
    % Aggregate per‑slice metrics (already computed) for this patient.
    patSliceMetrics = perSlice(strcmp(perSlice.Patient, pat), :);
    
    % For each metric, take mean across slices (ignoring NaNs).
    avg_r_ma          = nanmean(patSliceMetrics.Corr_man_auto);
    avg_MAE_ma        = nanmean(patSliceMetrics.MAE_man_auto);
    avg_lag_ma        = nanmean(patSliceMetrics.Lag_man_auto);
    avg_ee_diff_ma    = nanmean(patSliceMetrics.EE_diff_man_auto);
    avg_ei_diff_ma    = nanmean(patSliceMetrics.EI_diff_man_auto);
    avg_phase_ma      = nanmean(patSliceMetrics.PhaseAgree_man_auto);
    
    avg_r_md          = nanmean(patSliceMetrics.Corr_man_deform);
    avg_MAE_md        = nanmean(patSliceMetrics.MAE_man_deform);
    avg_lag_md        = nanmean(patSliceMetrics.Lag_man_deform);
    avg_ee_diff_md    = nanmean(patSliceMetrics.EE_diff_man_deform);
    avg_ei_diff_md    = nanmean(patSliceMetrics.EI_diff_man_deform);
    avg_phase_md      = nanmean(patSliceMetrics.PhaseAgree_man_deform);
    
    avg_r_ad          = nanmean(patSliceMetrics.Corr_auto_deform);
    avg_MAE_ad        = nanmean(patSliceMetrics.MAE_auto_deform);
    avg_lag_ad        = nanmean(patSliceMetrics.Lag_auto_deform);
    avg_ee_diff_ad    = nanmean(patSliceMetrics.EE_diff_auto_deform);
    avg_ei_diff_ad    = nanmean(patSliceMetrics.EI_diff_auto_deform);
    avg_phase_ad      = nanmean(patSliceMetrics.PhaseAgree_auto_deform);
    
    avg_n_man         = nanmean(patSliceMetrics.nCycles_man);
    avg_n_auto        = nanmean(patSliceMetrics.nCycles_auto);
    avg_n_deform      = nanmean(patSliceMetrics.nCycles_deform);
    
    avg_rr_man        = nanmean(patSliceMetrics.RR_man);
    avg_rr_auto       = nanmean(patSliceMetrics.RR_auto);
    avg_rr_deform     = nanmean(patSliceMetrics.RR_deform);
    
    avg_rr_diff_ma    = nanmean(patSliceMetrics.RR_diff_man_auto);
    avg_rr_diff_md    = nanmean(patSliceMetrics.RR_diff_man_deform);
    avg_rr_diff_ad    = nanmean(patSliceMetrics.RR_diff_auto_deform);
    
    newRow = table({pat}, ...
                   r_ma, MAE_ma, lag_ma, avg_ee_diff_ma, avg_ei_diff_ma, avg_phase_ma, ...
                   r_md, MAE_md, lag_md, avg_ee_diff_md, avg_ei_diff_md, avg_phase_md, ...
                   r_ad, MAE_ad, lag_ad, avg_ee_diff_ad, avg_ei_diff_ad, avg_phase_ad, ...
                   avg_n_man, avg_n_auto, avg_n_deform, ...
                   avg_rr_man, avg_rr_auto, avg_rr_deform, ...
                   avg_rr_diff_ma, avg_rr_diff_md, avg_rr_diff_ad, ...
                   'VariableNames', ...
                   {'Patient', ...
                    'Corr_man_auto','MAE_man_auto','Lag_man_auto','EE_diff_man_auto','EI_diff_man_auto','PhaseAgree_man_auto', ...
                    'Corr_man_deform','MAE_man_deform','Lag_man_deform','EE_diff_man_deform','EI_diff_man_deform','PhaseAgree_man_deform', ...
                    'Corr_auto_deform','MAE_auto_deform','Lag_auto_deform','EE_diff_auto_deform','EI_diff_auto_deform','PhaseAgree_auto_deform', ...
                    'nCycles_man','nCycles_auto','nCycles_deform', ...
                    'RR_man','RR_auto','RR_deform', ...
                    'RR_diff_man_auto','RR_diff_man_deform','RR_diff_auto_deform'});
    perPatient = [perPatient; newRow];
end
fprintf('Processed %d patients.\n', height(perPatient));

%% 6. Generating overlay plots for each slice
% For every slice that was successfully compared, I create a figure that shows
% the manual (black) and automated (red) waveforms overlaid. 
% I mark the EE and EI points on both curves. 
% If abnormal intervals were detected, I highlight them with a semi‑transparent yellow patch. All metrics for that slice are
% displayed in a text box outside the axes.
%  I save each figure as a PNG in a dedicated overlay folder, 
% and I keep the figures open so I can inspect them after the script finishes.

fprintf('\n--- Generating overlay plots for each slice ---\n');
overlayDir = fullfile(outputDir, 'slice_overlays');
if ~exist(overlayDir,'dir'); mkdir(overlayDir); end

for i = 1:height(perSlice)
    pat = perSlice.Patient{i};
    slc = perSlice.Slice{i};
    
    % Retrieving the manual and automated rows for this slice.
    manRow = waveforms(strcmp(waveforms.Patient, pat) & ...
                       strcmp(waveforms.Slice, slc) & ...
                       strcmp(waveforms.Method, 'manual'), :);
    autoRow = waveforms(strcmp(waveforms.Patient, pat) & ...
                        strcmp(waveforms.Slice, slc) & ...
                        strcmp(waveforms.Method, 'automated'), :);
    if isempty(manRow) || isempty(autoRow)
        continue;
    end
    sig_man = manRow.Signal{1};
    sig_auto = autoRow.Signal{1};
    time = manRow.time;            % time vector (numeric)
    fs = manRow.fs(1);
    
    % Getting the metrics for this slice (manual vs auto).
    r = perSlice.Corr_man_auto(i);
    mae = perSlice.MAE_man_auto(i);
    lag = perSlice.Lag_man_auto(i);
    ee_diff = perSlice.EE_diff_man_auto(i);
    ei_diff = perSlice.EI_diff_man_auto(i);
    phase_agree = perSlice.PhaseAgree_man_auto(i);
    n_man = perSlice.nCycles_man(i);
    n_auto = perSlice.nCycles_auto(i);
    rr_man = perSlice.RR_man(i);
    rr_auto = perSlice.RR_auto(i);
    
    % Re‑detecting EE and EI points for plotting (though they could be loaded,
    % recomputing is simpler).
    [ee_man, ei_man] = detect_EE_EI(sig_man, time, fs);
    [ee_auto, ei_auto] = detect_EE_EI(sig_auto, time, fs);
    
    % Creating the figure and adjusting its layout to leave room for annotation.
    fig = figure;
    set(fig, 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.6]);
    ax = gca;
    set(ax, 'Position', [0.1 0.15 0.7 0.75]); % [left bottom width height]
    
    % Plotting the waveforms.
    plot(time, sig_man, 'k-', 'LineWidth', 2); hold on;
    plot(time, sig_auto, 'r-', 'LineWidth', 1.5);
    
    % Marking EE (circles) and EI (squares).
    plot(ee_man, interp1(time, sig_man, ee_man), 'ko', 'MarkerSize', 8, 'LineWidth', 2);
    plot(ei_man, interp1(time, sig_man, ei_man), 'ks', 'MarkerSize', 8, 'LineWidth', 2);
    plot(ee_auto, interp1(time, sig_auto, ee_auto), 'ro', 'MarkerSize', 6, 'LineWidth', 1.5);
    plot(ei_auto, interp1(time, sig_auto, ei_auto), 'rs', 'MarkerSize', 6, 'LineWidth', 1.5);
    
    % Highlighting abnormal intervals (if any)
    manFile = fullfile(manualRoot, pat, slc, 'manual_waveform.mat');
    if exist(manFile, 'file')
        mf = load(manFile);
        if isfield(mf, 'intervals_auto') && ~isempty(mf.intervals_auto)
            intervals_auto = mf.intervals_auto;
            yl = ylim;
            for k = 1:size(intervals_auto,1)
                % Drawing a semi‑transparent yellow patch for each interval.
                patch([intervals_auto(k,1) intervals_auto(k,2) intervals_auto(k,2) intervals_auto(k,1)], ...
                      [yl(1) yl(1) yl(2) yl(2)], 'y', ...
                      'FaceAlpha', 0.2, 'EdgeColor', 'none');
            end
        end
    end
    
    xlabel('Time (s)');
    ylabel('Mean Intensity (normalized)');
    title(sprintf('Slice %s - %s', pat, slc));
    legend('Manual ROI', 'Automated Mask', 'Manual EE', 'Manual EI', 'Auto EE', 'Auto EI', ...
           'Location', 'best');
    
    % Annotating with all metrics – I place a text box outside the axes area.
    annotationText = sprintf(['r = %.3f\nMAE = %.3f\nLag = %.3f s\n' ...
                              'EE diff = %.3f s\nEI diff = %.3f s\n' ...
                              'Phase agree = %.2f\nCycles man/auto = %d/%d\n' ...
                              'RR man/auto = %.1f/%.1f bpm'], ...
                              r, mae, lag, ee_diff, ei_diff, phase_agree, n_man, n_auto, rr_man, rr_auto);
    annotation('textbox', [0.82 0.6 0.15 0.3], ...  % coordinates in normalized figure units
               'String', annotationText, ...
               'FontSize', 9, 'BackgroundColor', 'w', 'EdgeColor', 'k', 'Color', 'k', ...
               'VerticalAlignment', 'top', 'FitBoxToText', 'on');
    
    grid on;
    
    % Saving the figure; it remains open.
    filename = sprintf('slice_%s_%s.png', pat, slc);
    saveas(gcf, fullfile(overlayDir, filename));
end
fprintf('Overlay plots saved to %s\n', overlayDir);

%% 7. Saving results
% I save all the comparison tables both as MATLAB .mat files and as CSV files
% for easy sharing or loading into other software (e.g., Python, Excel).

save(fullfile(outputDir, 'perSlice_comparison.mat'), 'perSlice');
save(fullfile(outputDir, 'perPatient_comparison.mat'), 'perPatient');
save(fullfile(outputDir, 'perSlice_abnormal.mat'), 'perSliceAbnormal');
writetable(perSlice, fullfile(outputDir, 'perSlice_comparison.csv'));
writetable(perPatient, fullfile(outputDir, 'perPatient_comparison.csv'));
writetable(perSliceAbnormal, fullfile(outputDir, 'perSlice_abnormal.csv'));
fprintf('\nResults saved to %s\n', outputDir);

%% 8. Per‑patient combined metric plots

% For each patient, I create a single figure with multiple subplots showing how each metric varies across slices. This gives a quick overview of the
% method's performance per patient and can reveal slices that behave  differently (e.g., outliers).

fprintf('\n--- Generating per-patient combined metric plots ---\n');
combinedDir = fullfile(outputDir, 'patient_combined_metrics');
if ~exist(combinedDir,'dir'); mkdir(combinedDir); end

patients = unique(perSlice.Patient);
for p = 1:length(patients)
    pat = patients{p};
    patData = perSlice(strcmp(perSlice.Patient, pat), :);
    if isempty(patData)
        continue;
    end
    % Sorting the rows by slice name so that the x‑axis follows a natural order.
    patData = sortrows(patData, 'Slice');
    slices = patData.Slice;
    x = 1:length(slices);
    
    % Creating a figure with a 2×3 grid of subplots (still showing manual vs auto metrics).
    figure('Position', [100 100 1200 600]);
    
    % Subplot 1: Correlation (r) – manual vs auto
    subplot(2,3,1);
    plot(x, patData.Corr_man_auto, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
    set(gca, 'XTick', x, 'XTickLabel', slices);
    xlabel('Slice');
    ylabel('Correlation (r)');
    title('Correlation (man vs auto)');
    ylim([0 1]);
    grid on;
    
    % Subplot 2: Mean Absolute Error (MAE) – manual vs auto
    subplot(2,3,2);
    plot(x, patData.MAE_man_auto, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
    set(gca, 'XTick', x, 'XTickLabel', slices);
    xlabel('Slice');
    ylabel('MAE (raw)');
    title('Mean Absolute Error (man vs auto)');
    grid on;
    
    % Subplot 3: Lag (seconds) – manual vs auto
    subplot(2,3,3);
    plot(x, patData.Lag_man_auto, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
    set(gca, 'XTick', x, 'XTickLabel', slices);
    xlabel('Slice');
    ylabel('Lag (s)');
    title('Lag (man vs auto)');
    grid on;
    
    % Subplot 4: EE time difference – manual vs auto
    subplot(2,3,4);
    plot(x, patData.EE_diff_man_auto, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
    set(gca, 'XTick', x, 'XTickLabel', slices);
    xlabel('Slice');
    ylabel('EE diff (s)');
    title('EE Time Difference (man vs auto)');
    grid on;
    
    % Subplot 5: EI time difference – manual vs auto
    subplot(2,3,5);
    plot(x, patData.EI_diff_man_auto, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
    set(gca, 'XTick', x, 'XTickLabel', slices);
    xlabel('Slice');
    ylabel('EI diff (s)');
    title('EI Time Difference (man vs auto)');
    grid on;
    
    % Subplot 6: Phase agreement – manual vs auto
    subplot(2,3,6);
    plot(x, patData.PhaseAgree_man_auto, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
    set(gca, 'XTick', x, 'XTickLabel', slices);
    xlabel('Slice');
    ylabel('Phase Agreement');
    title('Phase Agreement (man vs auto)');
    ylim([0 1]);
    grid on;
    
    % Overall title for the figure.
    sgtitle(sprintf('Manual vs Automated Metrics for %s', pat));
    
    % Saving the figure.
    filename = fullfile(combinedDir, sprintf('%s_combined_metrics.png', pat));
    saveas(gcf, filename);
end
fprintf('Per-patient combined metric plots saved to %s\n', combinedDir);
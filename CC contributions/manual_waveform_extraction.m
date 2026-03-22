% Loading nnU-Net NIfTI frames and extracting respiratory waveform (manual ROI)
% Batch version with ONE ROI per slice (right hemidiaphragm) as per Sun et al.
% Includes three modes:
%   - Global auto-accept: no prompts or figures. Uses existing slice ROIs.
%   - Per-patient auto-accept: after ROI, auto-process all slices for that patient.
%   - Manual: interactive per-slice overlay and waveform approval.
%
% Added feature: I can specify a list of patient IDs to handle manually;
%   All others will be processed automatically (if they have an existing ROI).
%   I can type 'all' to review all patients manually.
%   Patient IDs can be entered with or without underscores (e.g., HV002 matches HV_002).
%   All inputs are case-insensitive.
% This helps with reproducibility because I can set one slice ROI once and reuse it each time.

close all;
clearvars;
tic; % Start the timer

% Setting base directories
% Defining the root folder containing patient data and the folder where output waveforms will be stored
patientDataRoot = 'C:\Users\makan\Downloads\ben_mina\Patient Data';
outputBase = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform\Waveform Outputs\Manual';

% Adding current folder to path (for natsortfiles if needed)
% This ensures that any custom functions in subfolders (like natsortfiles) are accessible
addpath(genpath(pwd));

% Helper to normalise patient IDs for comparison (remove underscores) 
% Creating an anonymous function that strips underscores and converts to lowercase for robust matching
normaliseID = @(id) strrep(strtrim(lower(id)), '_', '');

% Asking for global auto-accept mode 
globalAuto = false;
reply = input('Run in global auto-accept mode? (y/n): ', 's');
if strcmpi(reply, 'y')
    globalAuto = true;
    fprintf('Global auto-accept mode ON, so no prompts (or figures).\n');
else
    fprintf('Manual mode – you will be prompted per patient and per slice.\n');
end
%% This section is for patient list processing

% Asking for manual patient list (this is ignored if globalAuto) 
manualList = {};
if ~globalAuto
    listStr = input('Enter patient IDs for manual review (comma-separated, e.g., HV_002,HV_005, or ''all'' for all patients): ', 's');
    listStr = strtrim(listStr);
    if ~isempty(listStr)
        if strcmpi(listStr, 'all')
            % Getting all patient folder names by listing directories that start with 'HV_'
            allPatientFolders = dir(fullfile(patientDataRoot, 'HV_*'));
            allPatientFolders = allPatientFolders([allPatientFolders.isdir]);
            manualList = {allPatientFolders.name};
            fprintf('Manual review will be performed for ALL patients.\n');
        else
            % Splitting comma-separated list and trimming each entry, just
            % in case of mistakes
            rawList = strtrim(strsplit(listStr, ','));
            % Keeping non-empty entries after splitting
            manualList = rawList(~cellfun(@isempty, rawList));
            % Displaying as entered (original case/spacing may be messy, but I'll match later)
            fprintf('Manual review will be performed for: %s\n', strjoin(manualList, ', '));
        end
    end
end

% Getting list of patient folders
% Scanning the patient data root for folders that match the pattern 'HV_*' (e.g., HV_002, HV_003)
patientFolders = dir(fullfile(patientDataRoot, 'HV_*')); % adjust pattern if needed, but so far thats the syntax of the folders
patientFolders = patientFolders([patientFolders.isdir]);

%% Initialise table for normalisation check
normCheckManual = table();

%% I set the outer loop for patients in this section
for p = 1:length(patientFolders)
    patientName = patientFolders(p).name;
    patientPath = fullfile(patientDataRoot, patientName);

    % Determining if the patient is in the manual list (case-insensitive, ignoring underscores)
    normPatient = normaliseID(patientName);
    isManual = false;
    for j = 1:length(manualList)
        if strcmp(normPatient, normaliseID(manualList{j}))
            isManual = true;
            break;
        end
    end

    %  Determining per‑patient auto-accept mode 
    if globalAuto
        patientAuto = true;   % global mode overrides everything
    elseif isManual
        reply = input(sprintf('Auto-accept all slices for patient %s? (y/n): ', patientName), 's');
        patientAuto = strcmpi(reply, 'y');
    else
        % Auto patient (not manual): automatically accept all slices
        patientAuto = true;
    end

%% I set the inner loop for the slices in this section

    % Processing each slice 
    % Getting all slice folders inside the current patient folder (they are named 'raw_IM_*')
    sliceFolders = dir(fullfile(patientPath, 'raw_IM_*'));
    sliceFolders = sliceFolders([sliceFolders.isdir]);

    for s = 1:length(sliceFolders)
        sliceName = sliceFolders(s).name;
        Hpath = fullfile(patientPath, sliceName);

        % Building the expected output file path for this slice
        sliceOutputFile = fullfile(outputBase, patientName, sliceName, 'manual_waveform.mat');

        % Pre‑computing output directory for this slice
        outputDir = fullfile(outputBase, patientName, sliceName);
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end

        % Defining the file name for saving the ROI overlay image
        overlayFile = fullfile(outputDir, 'roi_overlay.png');

        if ~globalAuto
            fprintf('\n--- Processing %s / %s ---\n', patientName, sliceName);
        end

        % Getting a naturally sorted list of NIfTI frame files in the current slice folder
        Hfiles = natsortfiles(dir(fullfile(Hpath, '*.nii*')));
        if isempty(Hfiles)
            warning('No NIfTI files found in %s, skipping.', Hpath);
            continue;
        end

        HNum = numel(Hfiles);

        % Reading the first frame to determine image dimensions
        tmp = read_nii_gz(fullfile(Hpath, Hfiles(1).name));
        tmp = squeeze(double(tmp));
        dimx = size(tmp,1); dimy = size(tmp,2);

% As per old code from Ben
        % Preallocating a 3D array (height, width, number of frames) and loading all frames
        Proton = zeros(dimx, dimy, HNum);
        for k = 1:HNum
            I = read_nii_gz(fullfile(Hpath, Hfiles(k).name));
            I = squeeze(double(I));
            Proton(:,:,k) = I;
        end

        % Capturing the global maximum before normalisation
        preMax = max(Proton(:));
        fprintf('  For %s / %s, maximum value before normalisation is %f\n', patientName, sliceName, preMax);

        % Normalizing the entire image stack by the single brightest pixel across all frames
        Proton = Proton./max(Proton(:) + eps); % added eps to avoid division by 0, very very small number

        postMax = max(Proton(:));
        fprintf('  For %s / %s, maximum value after normalisation is %f\n', patientName, sliceName, postMax);
        
        % Setting timing parameters using a fixed acquisition duration (70.157 seconds)
        AcqDur = 70.157;
        TA = AcqDur / HNum;
        fs = 1/TA;

        % Applying a 3x3 minimum filter to each normalized frame to reduce blood signal
        ProtonFilt = zeros(size(Proton));
        for k = 1:size(Proton,3)
            temp = Proton(:,:,k);
            ProtonFilt(:,:,k) = ordfilt2(temp, 1, ones(3,3));
        end

%% ROI handling in this section : Either I draw or reuse existing

        % Handle ROI for this slice
        if patientAuto
            % Auto mode: use existing slice ROI if available
            if exist(sliceOutputFile, 'file')
                % Loading the previously saved ROI from the slice's output file
                loaded = load(sliceOutputFile, 'ROI_lung');
                if isfield(loaded, 'ROI_lung')
                    ROI_lung = loaded.ROI_lung;
                    fprintf('  Using existing ROI from %s\n', sliceOutputFile);
                else
                    warning('  No ROI found in %s. Skipping slice.', sliceOutputFile);
                    continue;
                end
            else
                warning('  No existing waveform file for %s / %s. Skipping.', patientName, sliceName);
                continue;
            end
        else

            % Manual mode: interactive ROI drawing (may reuse existing)
            ROI_lung = [];  % start empty

            % If a previous file exists, here I'm loading the old ROI to start with
            if exist(sliceOutputFile, 'file')
                loaded = load(sliceOutputFile, 'ROI_lung');
                if isfield(loaded, 'ROI_lung')
                    ROI_lung = loaded.ROI_lung;
                    fprintf('  Loaded previous ROI for this slice.\n');
                end
            end

            while true
                if isempty(ROI_lung)
                    % No ROI yet, draw a new one
                    frameShow = min(30, size(ProtonFilt,3));
                    figure();
                    imshow(ProtonFilt(:,:,frameShow), []);
                    title(sprintf('Draw ROI for %s / %s (frame %d)', patientName, sliceName, frameShow));
                    ROI_lung = roipoly();  % interactively drawing a polygon ROI
                    close;
                else

                    % Showing overlay and asking to keep/redraw, kinda helps to see whats going on
                    frameShow = min(30, size(ProtonFilt,3));
                    figure('Name', 'ROI Overlay Check');
                    imshow(ProtonFilt(:,:,frameShow), []); hold on;
                    contour(ROI_lung, [1 1], 'g', 'LineWidth', 2);
                    title(sprintf('Manual ROI overlay on %s / %s (frame %d)', patientName, sliceName, frameShow));
                    drawnow();
                    keepROI = input('Keep this ROI for this slice? (y/n): ', 's');
                    close(gcf);
                    if strcmpi(keepROI, 'y')
                        break;   % proceeding with current ROI
                    else
                        % Redrawing new ROI
                        fprintf('Redrawing ROI for slice %s...\n', sliceName);
                        figure();
                        imshow(ProtonFilt(:,:,frameShow), []);
                        title(sprintf('Draw new ROI for %s / %s (frame %d)', patientName, sliceName, frameShow));
                        ROI_lung = roipoly();  % drawing a new polygon
                        close;
                        % Now looping again to show overlay of the new ROI
                    end
                end
            end
        end

        % Save ROI overlay image (always, regardless of mode), I need to see what it looks like
        frameShow = min(30, size(ProtonFilt,3));
        f = figure('Visible', 'off');  % creating an invisible figure to avoid screen clutter
        imshow(ProtonFilt(:,:,frameShow), []); hold on;
        contour(ROI_lung, [1 1], 'g', 'LineWidth', 2);
        title(sprintf('ROI on %s / %s (frame %d)', patientName, sliceName, frameShow));
        saveas(f, overlayFile);  % saving the overlay image to the slice folder
        close(f);
        
%% ROI stuff done, now using the ROI to compute the signal and extract the waveform(and save it too)

        % Computing signal using the accepted ROI (normalized and filtered)
        Signal = zeros(1, size(ProtonFilt,3));
        for k = 1:size(ProtonFilt,3)
            Prtf = ProtonFilt(:,:,k);
            % Taking the mean of filtered, normalized pixels inside the ROI for each frame
            Signal(k) = mean(Prtf(ROI_lung == 1));
        end

        % Computing raw (unnormalized) signal for outlier detection
        Signal_raw = zeros(1, HNum);
        for k = 1:HNum
            % Re‑reading the original frame (no normalization or filtering) to get raw intensities
            I_raw = read_nii_gz(fullfile(Hpath, Hfiles(k).name));
            I_raw = squeeze(double(I_raw));
            Signal_raw(k) = mean(I_raw(ROI_lung == 1));  % mean of raw pixels inside the ROI
        end

        % Creating a time axis based on the frame index and TA (seconds per frame)
        time = (0:length(Signal)-1) * TA;

        % Waveform plot and acceptance (only in manual mode) 
        if ~patientAuto && ~globalAuto
            figure('Color','white');
            set(gcf, 'Position', [100, 100, 1200, 600]);  % wider figure for better visibility
            plot(time, Signal, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
            xlabel('Time (s)');
            ylabel('Average Signal in ROI');
            title(sprintf('Respiratory Waveform (Manual) - %s / %s', patientName, sliceName));
            set(gca, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 2, ...
                     'YMinorTick', 'on', 'Box', 'off', 'Color', 'white', ...
                     'XColor', 'k', 'YColor', 'k');
            set(get(gca, 'Title'), 'Color', 'k', 'FontWeight', 'bold');
            set(get(gca, 'XLabel'), 'Color', 'k');
            set(get(gca, 'YLabel'), 'Color', 'k');
            drawnow();

            % Save the waveform figure as PNG
            waveformFigFile = fullfile(outputDir, 'manual_waveform.png');
            exportgraphics(gcf, waveformFigFile, 'Resolution', 150);
            fprintf('  Waveform figure saved to %s\n', waveformFigFile);

            qualityc = input('Accept this slice? (y/n): ', 's');
            if ~strcmpi(qualityc, 'y')
                fprintf('Slice %s skipped.\n', sliceName);
                close(gcf);
                continue;
            end
            close(gcf);
        else
            % In auto mode, save the waveform figure without displaying
            waveformFig = figure('Visible', 'off', 'Position', [100, 100, 1200, 600]);
            plot(time, Signal, 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
            xlabel('Time (s)');
            ylabel('Average Signal in ROI');
            title(sprintf('Respiratory Waveform (Manual) - %s / %s', patientName, sliceName));
            set(gca, 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 2, ...
                     'YMinorTick', 'on', 'Box', 'off', 'Color', 'white', ...
                     'XColor', 'k', 'YColor', 'k');
            set(get(gca, 'Title'), 'Color', 'k', 'FontWeight', 'bold');
            set(get(gca, 'XLabel'), 'Color', 'k');
            set(get(gca, 'YLabel'), 'Color', 'k');
            grid on;
            waveformFigFile = fullfile(outputDir, 'manual_waveform.png');
            exportgraphics(waveformFig, waveformFigFile, 'Resolution', 150);
            close(waveformFig);
            fprintf('  Waveform figure saved to %s\n', waveformFigFile);
        end

        % Record normalisation check for this slice
        newRowNorm = table({patientName}, {sliceName}, preMax, postMax, ...
            'VariableNames',{'Patient','Slice','PreMax','PostMax'});
        normCheckManual = [normCheckManual; newRowNorm];

        % Saving waveform (with the slice-specific ROI)
        % Storing all relevant variables in the slice's output .mat file
        save(fullfile(outputDir, 'manual_waveform.mat'), 'Signal', 'Signal_raw', 'time', 'TA', 'fs', 'ROI_lung');
        if ~globalAuto
            fprintf('Waveform saved to %s\n', fullfile(outputDir, 'manual_waveform.mat'));
        end
    end
end

% Save normalisation check table
normFile = fullfile(outputBase, 'normalisation_check_manual.csv');
writetable(normCheckManual, normFile);
fprintf('Normalisation check saved to %s\n', normFile);

fprintf('\nAll processing complete.\n');
%% Nifti files helper
% Helper function: reading a NIfTI file (supports both .nii and .nii.gz)
function V = read_nii_gz(fname)
    try
        % First attempt to read the file directly with niftiread (handles .nii and .nii.gz if supported)
        V = niftiread(fname);
    catch
        % If that fails and the file is gzipped, manually unzip to a temporary folder
        if endsWith(fname, ".gz")
            tmpDir = fullfile(tempdir, "prefu_tmp");
            if ~exist(tmpDir, "dir"), mkdir(tmpDir); end
            gunzip(fname, tmpDir);
            % Building the path to the unzipped file (removing the .gz extension)
            unz = fullfile(tmpDir, erase(string(fname), ".gz"));
            V = niftiread(unz);
            delete(unz);  % cleaning up the temporary file
        else
            % Re‑throw the original error if it's not a .gz file
            rethrow(lasterror);
        end
    end
end

elapsedTime = toc; % Read the elapsed time
fprintf('Elapsed time: %.2f seconds\n', elapsedTime);
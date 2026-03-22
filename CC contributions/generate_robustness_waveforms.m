% generate_robustness_waveforms.m
% Generates CSV files for manual ROI and automated mask waveforms
% across different noise and blur levels for a single slice.
% I'm told this patient is HV002 and slice 25
% This is to help BB with his robustness bit

clear; close all;

%% 1. Defining paths
baseFolder   = 'C:\Users\makan\Downloads\ben_mina\MATLAB Respiratory Waveform';
riceFolder   = fullfile(baseFolder, 'rice_updated');
blurFolder   = fullfile(baseFolder, 'blur_9');
outputFolder = fullfile(baseFolder, 'robustness');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Adding path for natsortfiles (if not already)
addpath(genpath(baseFolder));

%% 2. Defining masks for the specific slice - I had this already from my pipeline
patient = 'HV_002';
slice   = 'raw_IM_0025';

% Manual ROI: loading from existing manual_waveform.mat
manualFile = fullfile(baseFolder, 'Waveform Outputs', 'Manual', patient, slice, 'manual_waveform.mat');
if ~exist(manualFile, 'file')
    error('Manual waveform file not found: %s', manualFile);
end
manualData = load(manualFile, 'ROI_lung');
if ~isfield(manualData, 'ROI_lung')
    error('ROI_lung not found in manual file');
end
manualMask = logical(manualData.ROI_lung);

% Automated mask: loading a representative mask from the clean dataset (first frame)
maskRoot = 'C:\Users\makan\Downloads\ben_mina\masks';
maskSliceFolder = fullfile(maskRoot, patient, slice);
maskFiles = natsortfiles(dir(fullfile(maskSliceFolder, '*.nii*')));
if isempty(maskFiles)
    error('No mask files found in %s', maskSliceFolder);
end
firstMaskFile = fullfile(maskSliceFolder, maskFiles(1).name);
maskImg = read_nii_gz(firstMaskFile);
autoMask = logical(maskImg);

%% 3. Helper function to process one corruption type
function processCorruption(corruptionFolder, corruptionName, mask, outputFolder)
    % corruptionFolder: root folder containing sigma subfolders (e.g., rice_9)
    % corruptionName: string for naming the output CSV (e.g., 'noise_manual')
    % mask: logical matrix (same size as one frame)
    % outputFolder: where to save CSV

    % Getting list of sigma subfolders - should be inside each folder
    subDirs = dir(fullfile(corruptionFolder, '*_sigma_*'));
    subDirs = subDirs([subDirs.isdir]);
    if isempty(subDirs)
        error('No sigma subfolders found in %s', corruptionFolder);
    end

    % Extracting sigma values and sort
    sigmaVals = zeros(length(subDirs), 1);
    for i = 1:length(subDirs)
        folderName = subDirs(i).name;
        tokens = regexp(folderName, '_sigma_([\d\.]+)$', 'tokens');
        if isempty(tokens)
            error('Could not parse sigma from folder name: %s', folderName);
        end
        sigmaVals(i) = str2double(tokens{1}{1});
    end
    [sigmaVals, sortIdx] = sort(sigmaVals);
    subDirs = subDirs(sortIdx);

    % Determining number of frames from the first subfolder (clean)
    firstSub = fullfile(corruptionFolder, subDirs(1).name);
    firstFiles = natsortfiles(dir(fullfile(firstSub, '*.nii*')));
    numFrames = length(firstFiles);
    if numFrames == 0
        error('No NIfTI files in %s', firstSub);
    end

    % Preallocate matrix: rows = frames, columns = sigma levels
    waveformMatrix = zeros(numFrames, length(subDirs));

    % Processing each sigma level
    for s = 1:length(subDirs)
        sigmaFolder = fullfile(corruptionFolder, subDirs(s).name);
        fprintf('Processing %s: %s\n', corruptionName, subDirs(s).name);

        % Getting list of nii files, sorted naturally
        niiFiles = natsortfiles(dir(fullfile(sigmaFolder, '*.nii*')));
        if length(niiFiles) ~= numFrames
            warning('Number of files in %s (%d) differs from clean (%d). Using min.', ...
                    sigmaFolder, length(niiFiles), numFrames);
            niiFiles = niiFiles(1:min(length(niiFiles), numFrames));
        end

        % Loading all frames
        tmp = read_nii_gz(fullfile(sigmaFolder, niiFiles(1).name));
        tmp = squeeze(double(tmp));
        [dimx, dimy] = size(tmp);
        numLoad = length(niiFiles);

        Proton = zeros(dimx, dimy, numLoad);
        for k = 1:numLoad
            I = read_nii_gz(fullfile(sigmaFolder, niiFiles(k).name));
            I = squeeze(double(I));
            Proton(:,:,k) = I;
        end

        % Normalising by global max of the entire stack
        globalMax = max(Proton(:));
        if globalMax == 0; globalMax = eps; end
        Proton = Proton / globalMax;

        % Applying 3x3 minimum filter to each frame
        ProtonFilt = zeros(size(Proton));
        for k = 1:size(Proton,3)
            temp = Proton(:,:,k);
            ProtonFilt(:,:,k) = ordfilt2(temp, 1, ones(3,3));
        end

        % Computing mean intensity inside mask for each frame
        signal = zeros(1, numLoad);
        for k = 1:numLoad
            frame = ProtonFilt(:,:,k);
            signal(k) = mean(frame(mask));
        end

        % Storing column
        if numLoad == numFrames
            waveformMatrix(:, s) = signal';
        else
            waveformMatrix(1:numLoad, s) = signal';
        end
    end

    % Building table with frame index and sigma columns
    colNames = cell(1, length(subDirs));
    for s = 1:length(subDirs)
        folderName = subDirs(s).name;
        tokens = regexp(folderName, '_sigma_([\d\.]+)$', 'tokens');
        if ~isempty(tokens)
            sigmaStr = tokens{1}{1};
            if strcmp(sigmaStr, '0')
                colNames{s} = 'clean';
            else
                colNames{s} = ['sigma_' sigmaStr];
            end
        else
            colNames{s} = folderName;
        end
    end

    T = array2table(waveformMatrix, 'VariableNames', colNames);
    T.Frame = (1:numFrames)';
    T = T(:, [end, 1:end-1]);

    outputFile = fullfile(outputFolder, sprintf('%s_waveforms.csv', corruptionName));
    writetable(T, outputFile);
    fprintf('Saved %s\n', outputFile);
end

%% 4. Processing noise (rice) and blur with separate output names
% So that I know what goes where
processCorruption(riceFolder, 'noise_manual', manualMask, outputFolder);
processCorruption(riceFolder, 'noise_auto',   autoMask,   outputFolder);
processCorruption(blurFolder, 'blur_manual',  manualMask, outputFolder);
processCorruption(blurFolder, 'blur_auto',    autoMask,   outputFolder);

fprintf('\nAll done. Results saved in %s\n', outputFolder);

%% Helper function to read NIfTI (as in my manual and ML extraction scripts)
function V = read_nii_gz(fname)
    try
        V = niftiread(fname);
    catch
        if endsWith(fname, ".gz")
            tmpDir = fullfile(tempdir, "prefu_tmp");
            if ~exist(tmpDir, "dir"); mkdir(tmpDir); end
            gunzip(fname, tmpDir);
            unz = fullfile(tmpDir, erase(string(fname), ".gz"));
            V = niftiread(unz);
            delete(unz);
        else
            rethrow(lasterror);
        end
    end
    V = squeeze(double(V));
end
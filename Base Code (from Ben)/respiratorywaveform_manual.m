%Load nnU-Net NIfTI frames + extract respiratory waveform (manual ROI)

close all;
clearvars;

% INPUT (NIfTI nnU-Net style frames) (change this)
path = "C:\Users\User\Desktop\masters\MSc research project\Scripts\nnunet_project\test_folder";

Hpath = [uigetdir(path, 'Select folder with PREFUL NIfTI frames (case_XXXX_0000.nii.gz):') filesep];

addpath(genpath(pwd));

% Get sorted list of frames 
Hfiles = natsortfiles(dir(fullfile(Hpath,'case_*_0000.nii.gz')));
if isempty(Hfiles)
    Hfiles = natsortfiles(dir(fullfile(Hpath,'case_*_0000.nii')));
end
if isempty(Hfiles)
    Hfiles = natsortfiles(dir(fullfile(Hpath,'*.nii*'))); % fallback
end

HNum = numel(Hfiles);
if HNum == 0
    error('No NIfTI frames found in: %s', Hpath);
end

%  Read first frame for size 
tmp = read_nii_gz(fullfile(Hpath, Hfiles(1).name));
tmp = squeeze(double(tmp));
dimx = size(tmp,1); dimy = size(tmp,2);

%  Load all frames into Proton(x,y,t) 
Proton = zeros(dimx, dimy, HNum);
for k = 1:HNum
    I = read_nii_gz(fullfile(Hpath, Hfiles(k).name));
    I = squeeze(double(I));
    Proton(:,:,k) = I;
end

% ---- Normalize (same as old code) ----
Proton = Proton./max(Proton(:) + eps);

%  Timing (DICOM had AcquisitionDuration; NIfTI usually doesn't) 
AcqDur = 70.157;  % seconds  <-- CHANGE to match dataset (dont change I already adjusted it)
% AcqDur = input('Enter total acquisition duration AcqDur (seconds): ');

TA  = AcqDur / HNum;
fs  = 1/TA;

% Print info 
disp('--- Loaded PREFUL series info (NIfTI frames) ---');
disp(['Hpath   = ' char(Hpath)]);
disp(['HNum    = ' num2str(HNum)]);
disp(['AcqDur  = ' num2str(AcqDur) ' s']);
disp(['TA      = ' num2str(TA) ' s/frame']);
disp(['fs      = ' num2str(fs) ' Hz']);
disp(['Nyquist = ' num2str(fs/2) ' Hz']);

% View the image set
figure(); imshow3D(Proton);

%% Step 1) Extract respiratory motion waveform (MANUAL ROI) + display it

% Apply a Median Filter to limit the blood signal in the respiratory
% waveform
ProtonFilt = zeros(size(Proton));
for k = 1:size(Proton,3)
    temp = Proton(:,:,k);
    ProtonFilt(:,:,k) = ordfilt2(temp,1,ones(3,3));
end

while true
    % pick a safe frame index to display
    frameShow = min(30, size(ProtonFilt,3));

    figure();
    imshow(ProtonFilt(:,:,frameShow),[])
    title('Draw a ROI enclosing the lung and bottom of the diaphram')
    ROI_lung = roipoly();
    close;

    Signal = zeros(1,size(ProtonFilt,3));
    for k = 1:size(ProtonFilt,3)
        Prtf = ProtonFilt(:,:,k);
        Signal(k) = mean(Prtf(ROI_lung==1));
    end

    d = 1:length(Signal);
    figure();
    plot(d,Signal,'k-','LineWidth',2)
    xlabel('Image Number')
    ylabel('Average Signal in the ROI')
    title('Respiratory Waveform (per Image)')
    set(gca,'FontName','Arial','FontSize',14,'LineWidth',2,'YMinorTick','on','Box','off')
    drawnow();

    qualityc = input('Is the respiratory waveform okay (y/n) ','s');
    if qualityc == 'y'
        break;
    end
end

%  Helper: read .nii or .nii.gz
function V = read_nii_gz(fname)

    try
        V = niftiread(fname);
    catch
        if endsWith(fname,".gz")
            tmpDir = fullfile(tempdir,"prefu_tmp");
            if ~exist(tmpDir,"dir"), mkdir(tmpDir); end
            gunzip(fname,tmpDir);
            unz = fullfile(tmpDir, erase(string(fname), ".gz"));
            V = niftiread(unz);
            delete(unz);
        else
            rethrow(lasterror);
        end
    end
end

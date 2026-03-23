import os
import glob
import time
import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import PolygonSelector
from scipy.ndimage import minimum_filter
from tkinter import filedialog, Tk

def select_folder():
    """Opens a dialog to select the data folder."""
    root = Tk()
    root.withdraw()  # Hide the main tkinter window
    folder_selected = filedialog.askdirectory(title="Select folder containing NIfTI frames")
    root.destroy()
    return folder_selected

def load_nifti_frames(folder_path):
    """Search and load NIfTI frames (nnU-Net style)."""
    patterns = ['case_*_0000.nii.gz', 'case_*_0000.nii', '*.nii*']
    files = []
    for p in patterns:
        files = sorted(glob.glob(os.path.join(folder_path, p)))
        if files: break
    
    if not files:
        raise FileNotFoundError(f"No NIfTI files found in: {folder_path}")
    
    print(f"Found {len(files)} frames. Loading data...")
    first_img = nib.load(files[0]).get_fdata()
    dim_x, dim_y = np.squeeze(first_img).shape
    
    proton = np.zeros((dim_x, dim_y, len(files)))
    for i, f in enumerate(files):
        img_data = nib.load(f).get_fdata()
        proton[:, :, i] = np.squeeze(img_data)
        
    return proton, len(files)

class ROIExtractor:
    """Interactive tool for manual ROI selection."""
    def __init__(self, data):
        self.data = data
        self.roi_mask = None
        self.fig, self.ax = plt.subplots(figsize=(8, 8))
        frame_idx = min(29, data.shape[2] - 1)
        self.ax.imshow(data[:, :, frame_idx], cmap='gray')
        self.ax.set_title("INSTRUCTION:\n1. Click to draw ROI around lung/diaphragm\n2. Close window to finish")
        self.poly = PolygonSelector(self.ax, self.onselect)

    def onselect(self, verts):
        from matplotlib.path import Path
        ny, nx, nt = self.data.shape
        x, y = np.meshgrid(np.arange(nx), np.arange(ny))
        pix = np.vstack((x.flatten(), y.flatten())).T
        path = Path(verts)
        self.roi_mask = path.contains_points(pix).reshape(ny, nx)

def main():
    # --- Start Timer ---
    start_time = time.time()

    # 1. Select Folder
    h_path = select_folder()
    if not h_path:
        print("Folder selection cancelled.")
        return

    # 2. Load Data
    try:
        proton, h_num = load_nifti_frames(h_path)
    except Exception as e:
        print(f"Error: {e}")
        return

    # 3. Processing
    acq_dur = 70.157 
    proton = proton / (np.max(proton) + 1e-10)
    
    print("Applying minimum filter...")
    proton_filt = np.zeros_like(proton)
    for k in range(h_num):
        proton_filt[:, :, k] = minimum_filter(proton[:, :, k], size=3)

    # 4. ROI Selection Loop
    while True:
        roi_tool = ROIExtractor(proton_filt)
        plt.show()
        
        if roi_tool.roi_mask is None:
            print("No ROI selected. Please try again.")
            continue
            
        # Calculate signal
        signal = [np.mean(proton_filt[:, :, k][roi_tool.roi_mask]) for k in range(h_num)]
        
        # Plot
        plt.figure(figsize=(10, 4))
        plt.plot(signal, 'k-')
        plt.title('Extracted Respiratory Waveform')
        plt.show()
        
        quality = input("Is the waveform okay? (y/n): ")
        if quality.lower() == 'y':
            # 5. Save to CSV
            csv_name = "respiratory_waveform.csv"
            save_path = os.path.join(h_path, csv_name)
            np.savetxt(save_path, signal, delimiter=",", header="ROI_Average_Signal")
            
            # --- End Timer ---
            total_time = time.time() - start_time
            print(f"\n--- Success ---")
            print(f"Waveform saved to: {save_path}")
            print(f"Total Execution Time: {total_time:.2f} seconds")
            break

if __name__ == "__main__":
    main()
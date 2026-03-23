import os
import glob
import time
import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import median_filter
from tkinter import filedialog, Tk

def select_folder(title_text):
    """Opens a dialog to select a folder starting from a specific directory."""
    # --- FIXED START PATH ---
    default_base = r"D:\groupproject2"
    
    root = Tk()
    root.withdraw()
    # Check if the default path exists, if not, use current directory
    initial_dir = default_base if os.path.exists(default_base) else os.getcwd()
    
    folder_selected = filedialog.askdirectory(
        title=title_text, 
        initialdir=initial_dir
    )
    root.destroy()
    return folder_selected

def load_nifti_from_folder(folder_path):
    """Helper to load all NIfTI files from a folder and stack them."""
    # Search patterns for images and masks
    patterns = ['case_*_0000.nii.gz', 'case_*.nii.gz', 'case_*.nii', '*.nii*']
    files = []
    for p in patterns:
        files = sorted(glob.glob(os.path.join(folder_path, p)))
        if files: break
    
    if not files:
        raise FileNotFoundError(f"No NIfTI files found in: {folder_path}")
    
    print(f"Loading {len(files)} files from {os.path.basename(folder_path)}...")
    data_list = []
    for f in files:
        img = nib.load(f).get_fdata()
        data_list.append(np.squeeze(img))
    
    return np.stack(data_list, axis=-1), files

def main():
    # --- Start Timer ---
    start_global = time.time()

    # 1. Select Folders (Starting from D:\groupproject2\patientdata)
    print("Step 1: Select the IMAGE folder (e.g., raw_IM_xxxx)...")
    h_path = select_folder("Select IMAGE folder (starting from patientdata)")
    if not h_path: 
        print("Cancelled."); return

    print("Step 2: Select the MASK folder (e.g., seg_IM_xxxx)...")
    m_path = select_folder("Select MASK folder (starting from patientdata)")
    if not m_path: 
        print("Cancelled."); return

    # 2. Load Data
    try:
        proton, h_files = load_nifti_from_folder(h_path)
        masks, m_files = load_nifti_from_folder(m_path)
    except Exception as e:
        print(f"Error: {e}"); return

    h_num = proton.shape[2]
    m_num = masks.shape[2]
    
    # Synchronization check
    if h_num != m_num:
        print(f"Warning: Frames mismatch (Img:{h_num}, Mask:{m_num}). Using minimum.")
        h_num = min(h_num, m_num)
        proton = proton[:, :, :h_num]
        masks = masks[:, :, :h_num]

    # 3. Processing
    print("Processing images (Normalization & Median Filtering)...")
    proton = proton / (np.max(proton) + 1e-10)
    proton_filt = np.zeros_like(proton)
    for k in range(h_num):
        proton_filt[:, :, k] = median_filter(proton[:, :, k], size=3)

    # 4. Visualization & Extraction
    while True:
        # Show overlay for verification
        check_idx = min(29, h_num - 1)
        plt.figure(figsize=(8, 8))
        plt.imshow(proton_filt[:, :, check_idx], cmap='gray')
        plt.contour(masks[:, :, check_idx], levels=[0.5], colors='lime', linewidths=1.5)
        plt.title(f"Overlay Check (Frame {check_idx})\nClose to extract waveform")
        plt.show()

        print("Extracting waveform...")
        signal = []
        for k in range(h_num):
            frame_data = proton_filt[:, :, k]
            frame_mask = masks[:, :, k]
            # Mean signal within the lung mask (mask > 0.5)
            if np.any(frame_mask > 0.5):
                signal.append(np.mean(frame_data[frame_mask > 0.5]))
            else:
                signal.append(0)

        # 5. Plot Waveform
        plt.figure(figsize=(10, 4))
        plt.plot(signal, color='blue', linewidth=1.5)
        plt.title('Automated Respiratory Waveform')
        plt.xlabel('Frame Number')
        plt.ylabel('Signal Intensity')
        plt.grid(True, linestyle='--', alpha=0.6)
        plt.show()

        # 6. Final Acceptance and CSV Export
        quality = input("Is the waveform okay? (y/n): ")
        if quality.lower() == 'y':
            # Save to CSV in the Image folder
            csv_output = os.path.join(h_path, "respiratory_waveform_auto.csv")
            np.savetxt(csv_output, signal, delimiter=",", header="Auto_ROI_Signal")
            
            end_time = time.time() - start_global
            print(f"\n--- DONE ---")
            print(f"CSV Saved: {csv_output}")
            print(f"Total Time: {end_time:.2f} seconds")
            break
        else:
            print("Operation aborted by user.")
            break

if __name__ == "__main__":
    main()
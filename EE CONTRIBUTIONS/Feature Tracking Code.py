#!/usr/bin/env python
# coding: utf-8

# In[4]:


import os
import time
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from IPython.display import clear_output

folder = os.path.expanduser("~/Desktop/raw images")

if not os.path.exists(folder):
    raise FileNotFoundError(f"Folder not found: {folder}")

files = sorted([f for f in os.listdir(folder) if f.endswith(".nii.gz")])

print("Number of frames:", len(files))
print("First 5 files:", files[:5])

if len(files) == 0:
    raise ValueError("No .nii.gz files found in the folder.")

for t in range(0, len(files), 5):   # change 5 to 1 if you want every frame
    clear_output(wait=True)

    img = nib.load(os.path.join(folder, files[t])).get_fdata()

    # If image is 3D, show the middle slice
    if img.ndim == 3:
        img = img[:, :, img.shape[2] // 2]

    # If image is 4D, show middle slice of first volume
    elif img.ndim == 4:
        img = img[:, :, img.shape[2] // 2, 0]

    img = np.rot90(img, 1)

    plt.figure(figsize=(6, 6))
    plt.imshow(img, cmap="gray")
    plt.axis("off")
    plt.title(f"{files[t]}  (frame {t+1}/{len(files)})")
    plt.show()

    time.sleep(0.1)


# In[ ]:


import sys
get_ipython().system('{sys.executable} -m pip install nibabel numpy matplotlib opencv-python')


# In[ ]:


import os
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt

# --------------------------------------------------
# 1. LOAD FILES
# --------------------------------------------------
folder = os.path.expanduser("~/Desktop/raw images")

if not os.path.exists(folder):
    raise FileNotFoundError(f"Folder not found: {folder}")

files = sorted([f for f in os.listdir(folder) if f.endswith(".nii.gz") or f.endswith(".nii")])

if len(files) == 0:
    raise ValueError("No .nii or .nii.gz files found in the folder.")

print("Number of frames:", len(files))
print("First 5 files:", files[:5])

# --------------------------------------------------
# 2. READ ALL FRAMES AS 2D IMAGES
# --------------------------------------------------
frames = []

for f in files:
    img = nib.load(os.path.join(folder, f)).get_fdata()

    if img.ndim == 3:
        img2d = img[:, :, img.shape[2] // 2]
    elif img.ndim == 4:
        img2d = img[:, :, img.shape[2] // 2, 0]
    elif img.ndim == 2:
        img2d = img
    else:
        raise ValueError(f"Unsupported dimensions {img.ndim} in {f}")

    img2d = np.rot90(img2d, 1)
    img2d = img2d.astype(np.float32)

    # normalise each frame
    img2d = img2d - np.min(img2d)
    if np.max(img2d) > 0:
        img2d = img2d / np.max(img2d)

    frames.append(img2d)

print("Loaded all frames.")
print("Frame shape:", frames[0].shape)

# --------------------------------------------------
# 3. CLICK ONE FEATURE TO TRACK
# --------------------------------------------------
first_frame = frames[0]

plt.figure(figsize=(7,7))
plt.imshow(first_frame, cmap="gray")
plt.title("Click one lung feature to track, then close the figure")
plt.axis("off")
clicked = plt.ginput(1)
plt.show()

if len(clicked) == 0:
    raise ValueError("No point clicked.")

x0, y0 = clicked[0]
x0, y0 = int(round(x0)), int(round(y0))

print(f"Chosen feature point: x={x0}, y={y0}")

# --------------------------------------------------
# 4. TEMPLATE SETTINGS
# --------------------------------------------------
patch_half_size = 7      # patch size = 15x15
search_radius = 10       # search nearby in next frame

def get_patch(img, x, y, half_size):
    """
    Extract square patch centered at (x, y).
    Returns None if patch would go out of bounds.
    """
    h, w = img.shape
    if (x - half_size < 0 or x + half_size >= w or
        y - half_size < 0 or y + half_size >= h):
        return None
    return img[y-half_size:y+half_size+1, x-half_size:x+half_size+1]

def patch_score(template, candidate):
    """
    Mean squared difference between two same-size patches.
    Lower score = better match.
    """
    return np.mean((template - candidate) ** 2)

# --------------------------------------------------
# 5. INITIAL TEMPLATE
# --------------------------------------------------
template = get_patch(first_frame, x0, y0, patch_half_size)
if template is None:
    raise ValueError("Chosen point is too close to the edge. Click more centrally.")

positions = [(x0, y0)]

# --------------------------------------------------
# 6. TRACK THROUGH ALL FRAMES
# --------------------------------------------------
x_prev, y_prev = x0, y0

for t in range(1, len(frames)):
    prev_frame = frames[t - 1]
    curr_frame = frames[t]

    best_score = np.inf
    best_x, best_y = x_prev, y_prev

    # search near previous position
    for dy in range(-search_radius, search_radius + 1):
        for dx in range(-search_radius, search_radius + 1):
            x_try = x_prev + dx
            y_try = y_prev + dy

            candidate = get_patch(curr_frame, x_try, y_try, patch_half_size)
            if candidate is None:
                continue

            score = patch_score(template, candidate)

            if score < best_score:
                best_score = score
                best_x, best_y = x_try, y_try

    positions.append((best_x, best_y))
    x_prev, y_prev = best_x, best_y

    # update template slightly so it adapts over time
    new_template = get_patch(curr_frame, best_x, best_y, patch_half_size)
    if new_template is not None:
        template = 0.8 * template + 0.2 * new_template

print("Tracking complete.")

# --------------------------------------------------
# 7. EXTRACT WAVEFORM
# --------------------------------------------------
positions = np.array(positions)
x_positions = positions[:, 0]
y_positions = positions[:, 1]

# displacement relative to first frame
x_disp = x_positions - x_positions[0]
y_disp = y_positions - y_positions[0]

# usually breathing motion is mostly vertical in image
waveform = y_disp

# simple smoothing
if len(waveform) >= 5:
    kernel = np.ones(5) / 5
    waveform_smooth = np.convolve(waveform, kernel, mode="same")
else:
    waveform_smooth = waveform.copy()

# --------------------------------------------------
# 8. SHOW TRACK ON FIRST AND LAST FRAME
# --------------------------------------------------
plt.figure(figsize=(14,6))

plt.subplot(1,2,1)
plt.imshow(frames[0], cmap="gray")
plt.scatter([x_positions[0]], [y_positions[0]], c="red", s=50)
plt.title("First frame: chosen feature")
plt.axis("off")

plt.subplot(1,2,2)
plt.imshow(frames[-1], cmap="gray")
plt.scatter([x_positions[-1]], [y_positions[-1]], c="lime", s=50)
plt.title("Last frame: tracked feature")
plt.axis("off")

plt.show()

# --------------------------------------------------
# 9. SHOW TRACKED PATH
# --------------------------------------------------
plt.figure(figsize=(7,7))
plt.imshow(frames[0], cmap="gray")
plt.plot(x_positions, y_positions, 'r-', linewidth=2)
plt.scatter([x_positions[0]], [y_positions[0]], c="yellow", s=50, label="Start")
plt.scatter([x_positions[-1]], [y_positions[-1]], c="cyan", s=50, label="End")
plt.title("Tracked feature path")
plt.legend()
plt.axis("off")
plt.show()

# --------------------------------------------------
# 10. PLOT WAVEFORM
# --------------------------------------------------
plt.figure(figsize=(12,4))
plt.plot(waveform, label="Raw displacement")
plt.plot(waveform_smooth, linewidth=2, label="Smoothed displacement")
plt.xlabel("Frame number")
plt.ylabel("Vertical displacement (pixels)")
plt.title("Single-feature respiratory waveform")
plt.grid(True)
plt.legend()
plt.show()

# --------------------------------------------------
# 11. SAVE WAVEFORM
# --------------------------------------------------
out_csv = os.path.expanduser("~/Desktop/single_feature_waveform.csv")
np.savetxt(out_csv, np.column_stack([x_positions, y_positions, waveform_smooth]),
           delimiter=",",
           header="x_position,y_position,smoothed_vertical_displacement",
           comments="")

print("Waveform saved to:", out_csv)


# In[3]:



'''
import os
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt
from scipy.signal import correlate2d

folder = os.path.expanduser("~/Desktop/raw images")

if not os.path.exists(folder):
    raise FileNotFoundError(f"Folder not found: {folder}")

files = sorted([f for f in os.listdir(folder) if f.endswith(".nii.gz")])

print("Number of frames:", len(files))
print("First 5 files:", files[:5])

if len(files) == 0:
    raise ValueError("No .nii.gz files found in the folder.")

# ---------------------------------------------------
# 1. LOAD FRAMES
# ---------------------------------------------------
frames = []
for file in files:
    img = nib.load(os.path.join(folder, file)).get_fdata()

    if img.ndim == 3:
        img = img[:, :, img.shape[2] // 2]
    elif img.ndim == 4:
        img = img[:, :, img.shape[2] // 2, 0]

    img = np.rot90(img, 1)
    frames.append(img)

frames = np.array(frames, dtype=np.float32)
print("Frames shape:", frames.shape)

# ---------------------------------------------------
# 2. NORMALISE
# ---------------------------------------------------
norm_frames = []
for f in frames:
    f = f - np.min(f)
    if np.max(f) > 0:
        f = f / np.max(f)
    norm_frames.append(f)

norm_frames = np.array(norm_frames, dtype=np.float32)

h, w = norm_frames[0].shape

# ---------------------------------------------------
# 3. CHOOSE PATCH TO TRACK
# ---------------------------------------------------
# You can adjust these if needed
x = int(w * 0.35)
y = int(h * 0.60)
patch_w = int(w * 0.12)
patch_h = int(h * 0.12)

template = norm_frames[0][y:y+patch_h, x:x+patch_w]

if template.size == 0:
    raise ValueError("Template patch is empty. Adjust x, y, patch_w, patch_h.")

print("Initial tracked patch:")
print("x =", x, "y =", y, "width =", patch_w, "height =", patch_h)

# ---------------------------------------------------
# 4. TRACK PATCH THROUGH FRAMES
# ---------------------------------------------------
# Search window around previous location
search_margin = 12

tracked_x = [x]
tracked_y = [y]

curr_x, curr_y = x, y

for i in range(1, len(norm_frames)):
    frame = norm_frames[i]

    x_min = max(0, curr_x - search_margin)
    x_max = min(w - patch_w, curr_x + search_margin)
    y_min = max(0, curr_y - search_margin)
    y_max = min(h - patch_h, curr_y + search_margin)

    search_region = frame[y_min:y_max+patch_h, x_min:x_max+patch_w]

    if search_region.shape[0] < patch_h or search_region.shape[1] < patch_w:
        tracked_x.append(curr_x)
        tracked_y.append(curr_y)
        continue

    # Normalised template matching by correlation
    corr = correlate2d(search_region, template, mode="valid")

    best_idx = np.unravel_index(np.argmax(corr), corr.shape)
    best_y, best_x = best_idx

    curr_x = x_min + best_x
    curr_y = y_min + best_y

    tracked_x.append(curr_x)
    tracked_y.append(curr_y)

tracked_x = np.array(tracked_x)
tracked_y = np.array(tracked_y)

# ---------------------------------------------------
# 5. CREATE WAVEFORM FROM VERTICAL MOTION
# ---------------------------------------------------
waveform = -(tracked_y - tracked_y[0])

# Smooth slightly
window = 7
kernel = np.ones(window) / window
waveform_smooth = np.convolve(waveform, kernel, mode="same")

# ---------------------------------------------------
# 6. SHOW FIRST FRAME WITH TRACKED PATCH
# ---------------------------------------------------
plt.figure(figsize=(7,7))
plt.imshow(frames[0], cmap="gray")
plt.gca().add_patch(
    plt.Rectangle((x, y), patch_w, patch_h, edgecolor="red", facecolor="none", linewidth=2)
)
plt.title("Initial tracked lung patch")
plt.axis("off")
plt.show()

# ---------------------------------------------------
# 7. SHOW LATER FRAME WITH TRACKED PATCH
# ---------------------------------------------------
example_idx = len(frames) // 2

plt.figure(figsize=(7,7))
plt.imshow(frames[example_idx], cmap="gray")
plt.gca().add_patch(
    plt.Rectangle((tracked_x[example_idx], tracked_y[example_idx]),
                  patch_w, patch_h, edgecolor="lime", facecolor="none", linewidth=2)
)
plt.title(f"Tracked patch on frame {example_idx}")
plt.axis("off")
plt.show()

# ---------------------------------------------------
# 8. SHOW TRAJECTORY
# ---------------------------------------------------
plt.figure(figsize=(7,7))
plt.imshow(frames[0], cmap="gray")
plt.plot(tracked_x + patch_w/2, tracked_y + patch_h/2, '-o', markersize=2)
plt.title("Tracked patch path")
plt.axis("off")
plt.show()

# ---------------------------------------------------
# 9. SHOW WAVEFORM
# ---------------------------------------------------
plt.figure(figsize=(12,4))
plt.plot(waveform_smooth, linewidth=2)
plt.xlabel("Frame number")
plt.ylabel("Relative vertical motion")
plt.title("Respiratory waveform from feature tracking")
plt.grid(True)
plt.show()

'''


# In[ ]:





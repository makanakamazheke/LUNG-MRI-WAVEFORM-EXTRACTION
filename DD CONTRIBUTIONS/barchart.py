import matplotlib.pyplot as plt
import numpy as np

# -----------------------
# Data
# -----------------------
metrics = [r"$S_T$", r"$S_S$", r"$S_R$", r"$S_C$", r"Final $U_i$"]
manual = [0.85, 0.74, 0.957, 0.83, 0.855]
ml = [0.56, 0.40, 0.981, 0.42, 0.626]
jacobian = [0.00, 0.78, 1.000, 0.58, 0.572]

data = np.array([manual, ml, jacobian])
method_short = ["M", "ML", "J"]
colors = ["#e8c9f2", "#aa9ee1", "#90b9ee"]

# -----------------------
# Plot
# -----------------------
x = np.arange(len(metrics))
width = 0.22

fig, ax = plt.subplots(figsize=(9, 5.8))

bars1 = ax.bar(x - width, manual, width, label="Manual ROI",
               color=colors[0], edgecolor="black", linewidth=1)
bars2 = ax.bar(x, ml, width, label="Automated ML (GPU)",
               color=colors[1], edgecolor="black", linewidth=1)
bars3 = ax.bar(x + width, jacobian, width, label="Jacobian-based",
               color=colors[2], edgecolor="black", linewidth=1)

bar_groups = [bars1, bars2, bars3]

# Highlight Final Ui background
ax.axvspan(3.5, 4.5, color="gray", alpha=0.08)

# -----------------------
# Highlight best bar in each metric
# -----------------------
for i in range(len(metrics)):
    col = data[:, i]
    max_val = np.max(col)

    for method_idx, bars in enumerate(bar_groups):
        if np.isclose(data[method_idx, i], max_val):
            bars[i].set_edgecolor("red")
            bars[i].set_linewidth(2)

            ax.text(
                bars[i].get_x() + bars[i].get_width()/2,
                bars[i].get_height() + 0.06,
                "*",
                color="red",
                ha="center",
                va="bottom",
                fontsize=13,
                fontweight="bold"
            )

# -----------------------
# Add labels
# -----------------------
for group_idx, bars in enumerate(bar_groups):
    for bar in bars:
        h = bar.get_height()
        x_pos = bar.get_x() + bar.get_width()/2

        # value label above bar
        ax.text(
            x_pos,
            h + 0.012,
            f"{h:.3f}" if h >= 0.95 else f"{h:.2f}",
            ha='center',
            va='bottom',
            fontsize=8
        )

        # method label INSIDE or just above very short bars
        if h > 0.12:
            ax.text(
                x_pos,
                0.03,
                method_short[group_idx],
                ha='center',
                va='bottom',
                fontsize=8,
                fontweight='bold',
                color='black'
            )
        else:
            ax.text(
                x_pos,
                h + 0.035,
                method_short[group_idx],
                ha='center',
                va='bottom',
                fontsize=8,
                fontweight='bold',
                color='black'
            )

# -----------------------
# Formatting
# -----------------------
ax.set_ylabel("Score", fontsize=11)
ax.set_title("Comparison of Usability Scores by Metric", fontsize=13)
ax.set_xticks(x)
ax.set_xticklabels(metrics, fontsize=12)
ax.set_ylim(0, 1.12)

ax.legend(frameon=False, loc="upper left", fontsize=9)
ax.grid(axis='y', linestyle='--', alpha=0.5)

# Remove extra bottom clutter
plt.tight_layout()
plt.show()
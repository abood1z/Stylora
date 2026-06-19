import pandas as pd

# =========================
# Files
# =========================
ORIGINAL_CSV = "train_balanced_cleaned.csv"
EXTRA_CSV = "extra_dataset.csv"

OUTPUT_CSV = "train_boosted.csv"

# =========================
# إعدادات
# =========================
MAX_EXTRA_PER_COLOR = 700

# =========================
# Load
# =========================
print("Loading original dataset...")
original_df = pd.read_csv(ORIGINAL_CSV)

print("Loading extra dataset...")
extra_df = pd.read_csv(EXTRA_CSV)

print("\nOriginal distribution:")
print(original_df["color"].value_counts())

print("\nExtra distribution BEFORE balancing:")
print(extra_df["color"].value_counts())

# =========================
# تنظيف أسماء الألوان
# =========================
original_df["color"] = original_df["color"].str.strip()
extra_df["color"] = extra_df["color"].str.strip()

# =========================
# فقط الألوان المشتركة
# =========================
valid_colors = set(original_df["color"].unique())

extra_df = extra_df[
    extra_df["color"].isin(valid_colors)
]

print("\nExtra distribution AFTER filtering:")
print(extra_df["color"].value_counts())

# =========================
# أخذ عدد محدود من كل لون
# =========================
balanced_extra = []

for color in sorted(extra_df["color"].unique()):

    color_df = extra_df[
        extra_df["color"] == color
    ]

    sampled_df = color_df.sample(
        n=min(MAX_EXTRA_PER_COLOR, len(color_df)),
        random_state=42
    )

    balanced_extra.append(sampled_df)

balanced_extra_df = pd.concat(
    balanced_extra,
    ignore_index=True
)

print("\nBalanced extra distribution:")
print(
    balanced_extra_df["color"].value_counts()
)

# =========================
# دمج
# =========================
merged_df = pd.concat(
    [original_df, balanced_extra_df],
    ignore_index=True
)

# =========================
# حذف التكرار
# =========================
merged_df = merged_df.drop_duplicates(
    subset=["image_path", "color"]
)

# =========================
# خلط
# =========================
merged_df = merged_df.sample(
    frac=1.0,
    random_state=42
).reset_index(drop=True)

# =========================
# Save
# =========================
merged_df.to_csv(
    OUTPUT_CSV,
    index=False
)

print("\n=========================")
print("MERGE COMPLETE")
print("=========================")

print("\nFinal distribution:")
print(
    merged_df["color"].value_counts()
)

print("\nTotal samples:", len(merged_df))

print(f"\nSaved as: {OUTPUT_CSV}")
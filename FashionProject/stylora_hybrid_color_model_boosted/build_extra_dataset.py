import os
import pandas as pd

EXTRA_DATASET_DIR = "extra_color_dataset"
OUTPUT_CSV = "extra_dataset.csv"

VALID_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")

rows = []

for folder_name in os.listdir(EXTRA_DATASET_DIR):

    folder_path = os.path.join(EXTRA_DATASET_DIR, folder_name)

    if not os.path.isdir(folder_path):
        continue

    # استخراج اللون
    color = folder_name.split("_")[0].replace("-", " ").title()

    for file_name in os.listdir(folder_path):

        if not file_name.lower().endswith(VALID_EXTENSIONS):
            continue

        image_path = os.path.join(folder_path, file_name)

        rows.append({
            "image_path": image_path.replace("\\", "/"),
            "color": color
        })

df = pd.DataFrame(rows)

print("\nDataset preview:")
print(df.head())

print("\nColor distribution:")
print(df["color"].value_counts())

df.to_csv(OUTPUT_CSV, index=False)

print(f"\nSaved: {OUTPUT_CSV}")
print(f"Total samples: {len(df)}")
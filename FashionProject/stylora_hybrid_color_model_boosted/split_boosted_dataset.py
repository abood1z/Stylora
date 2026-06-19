import pandas as pd
from sklearn.model_selection import train_test_split

INPUT_CSV = "train_boosted.csv"

TRAIN_OUT = "train_boosted_split.csv"
VAL_OUT = "val_boosted_split.csv"
TEST_OUT = "test_boosted_split.csv"

SEED = 42

print("Loading dataset...")
df = pd.read_csv(INPUT_CSV)

print("\nTotal samples:", len(df))

print("\nColor distribution:")
print(df["color"].value_counts())

# =========================
# Train / Temp
# =========================
train_df, temp_df = train_test_split(
    df,
    test_size=0.20,
    stratify=df["color"],
    random_state=SEED
)

# =========================
# Val / Test
# =========================
val_df, test_df = train_test_split(
    temp_df,
    test_size=0.50,
    stratify=temp_df["color"],
    random_state=SEED
)

# =========================
# Save
# =========================
train_df.to_csv(TRAIN_OUT, index=False)
val_df.to_csv(VAL_OUT, index=False)
test_df.to_csv(TEST_OUT, index=False)

print("\n======================")
print("DATASET SPLIT DONE")
print("======================")

print("\nTrain:", len(train_df))
print("Val:", len(val_df))
print("Test:", len(test_df))

print("\nTrain distribution:")
print(train_df["color"].value_counts())

print(f"\nSaved:")
print(TRAIN_OUT)
print(VAL_OUT)
print(TEST_OUT)
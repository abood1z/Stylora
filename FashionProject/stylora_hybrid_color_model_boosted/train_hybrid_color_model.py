import os
import json
import cv2
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import tensorflow as tf

from tensorflow.keras import layers, Model
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from sklearn.preprocessing import StandardScaler
import joblib


IMG_SIZE = (224, 224)
BATCH_SIZE = 32
SEED = 42

TRAIN_CSV = "train_boosted_split.csv"
VAL_CSV = "val_boosted_split.csv"
TEST_CSV = "test_boosted_split.csv"

MODEL_OUTPUT = "stylora_hybrid_color_model_boosted.h5"
SCALER_OUTPUT = "color_feature_scaler_boosted.pkl"
CLASS_OUTPUT = "class_names_hybrid_boosted.json"

CLASS_NAMES = [
    "Black", "White", "Grey", "Navy Blue", "Beige", "Red", "Blue",
    "Green", "Yellow", "Orange", "Purple", "Burgundy", "Olive Green",
    "Pink", "Dusty Rose", "Brown", "Tan", "Turquoise", "Mustard",
    "Gold", "Silver", "Cream"
]

NUM_CLASSES = len(CLASS_NAMES)


def load_df(path):
    df = pd.read_csv(path)
    df = df[df["color"].isin(CLASS_NAMES)].copy()
    df = df[df["image_path"].apply(os.path.exists)].copy()
    return df


def extract_color_features(image_path):
    img = cv2.imread(image_path)

    if img is None:
        return np.zeros(18, dtype=np.float32)

    img = cv2.resize(img, IMG_SIZE)

    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)

    rgb_mean = rgb.mean(axis=(0, 1))
    rgb_std = rgb.std(axis=(0, 1))

    hsv_mean = hsv.mean(axis=(0, 1))
    hsv_std = hsv.std(axis=(0, 1))

    lab_mean = lab.mean(axis=(0, 1))
    lab_std = lab.std(axis=(0, 1))

    features = np.concatenate([
        rgb_mean, rgb_std,
        hsv_mean, hsv_std,
        lab_mean, lab_std
    ])

    return features.astype(np.float32)


def prepare_features(df, scaler=None, fit=False):
    print("Extracting color features...")

    features = np.array([
        extract_color_features(path) for path in df["image_path"].values
    ])

    if fit:
        scaler = StandardScaler()
        features = scaler.fit_transform(features)
    else:
        features = scaler.transform(features)

    return features.astype(np.float32), scaler


def encode_labels(df):
    color_to_id = {c: i for i, c in enumerate(CLASS_NAMES)}
    labels = df["color"].map(color_to_id).values
    labels = tf.keras.utils.to_categorical(labels, NUM_CLASSES)
    return labels.astype(np.float32)


def load_image(path):
    img = tf.io.read_file(path)
    img = tf.image.decode_jpeg(img, channels=3)
    img = tf.image.resize(img, IMG_SIZE)
    img = tf.cast(img, tf.float32)
    img = preprocess_input(img)
    return img


def build_dataset(df, color_features, labels, training=False):
    paths = df["image_path"].values

    ds = tf.data.Dataset.from_tensor_slices((paths, color_features, labels))

    if training:
        ds = ds.shuffle(buffer_size=min(len(df), 10000), seed=SEED)

    def map_fn(path, feat, label):
        img = load_image(path)
        return {"image_input": img, "color_input": feat}, label

    ds = ds.map(map_fn, num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.batch(BATCH_SIZE)
    ds = ds.prefetch(tf.data.AUTOTUNE)

    return ds


def build_hybrid_model():
    image_input = layers.Input(shape=(224, 224, 3), name="image_input")
    color_input = layers.Input(shape=(18,), name="color_input")

    augmentation = tf.keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.03),
        layers.RandomZoom(0.05),
        layers.RandomContrast(0.08),
    ])

    base_model = MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights="imagenet"
    )

    base_model.trainable = False

    x = augmentation(image_input)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dense(256, activation="relu")(x)
    x = layers.Dropout(0.30)(x)

    c = layers.Dense(64, activation="relu")(color_input)
    c = layers.BatchNormalization()(c)
    c = layers.Dropout(0.20)(c)

    combined = layers.Concatenate()([x, c])

    z = layers.Dense(256, activation="relu")(combined)
    z = layers.BatchNormalization()(z)
    z = layers.Dropout(0.35)(z)

    z = layers.Dense(128, activation="relu")(z)
    z = layers.Dropout(0.25)(z)

    output = layers.Dense(NUM_CLASSES, activation="softmax")(z)

    model = Model(
        inputs=[image_input, color_input],
        outputs=output
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.0005),
        loss="categorical_crossentropy",
        metrics=["accuracy"]
    )

    return model, base_model


def plot_curves(history1, history2=None):
    acc = history1.history["accuracy"]
    val_acc = history1.history["val_accuracy"]
    loss = history1.history["loss"]
    val_loss = history1.history["val_loss"]

    if history2:
        acc += history2.history["accuracy"]
        val_acc += history2.history["val_accuracy"]
        loss += history2.history["loss"]
        val_loss += history2.history["val_loss"]

    epochs = range(1, len(acc) + 1)

    plt.figure()
    plt.plot(epochs, acc, label="Train Accuracy")
    plt.plot(epochs, val_acc, label="Val Accuracy")
    plt.legend()
    plt.title("Accuracy")
    plt.xlabel("Epoch")
    plt.ylabel("Accuracy")
    plt.savefig("hybrid_accuracy_curve.png", dpi=300)
    plt.close()

    plt.figure()
    plt.plot(epochs, loss, label="Train Loss")
    plt.plot(epochs, val_loss, label="Val Loss")
    plt.legend()
    plt.title("Loss")
    plt.xlabel("Epoch")
    plt.ylabel("Loss")
    plt.savefig("hybrid_loss_curve.png", dpi=300)
    plt.close()


def main():
    print("Loading CSV files...")

    train_df = load_df(TRAIN_CSV)
    val_df = load_df(VAL_CSV)
    test_df = load_df(TEST_CSV)

    print("Train:", len(train_df))
    print("Val:", len(val_df))
    print("Test:", len(test_df))

    with open(CLASS_OUTPUT, "w", encoding="utf-8") as f:
        json.dump(CLASS_NAMES, f, indent=4)

    train_features, scaler = prepare_features(train_df, fit=True)
    val_features, _ = prepare_features(val_df, scaler=scaler, fit=False)
    test_features, _ = prepare_features(test_df, scaler=scaler, fit=False)

    joblib.dump(scaler, SCALER_OUTPUT)

    train_labels = encode_labels(train_df)
    val_labels = encode_labels(val_df)
    test_labels = encode_labels(test_df)

    train_ds = build_dataset(train_df, train_features, train_labels, training=True)
    val_ds = build_dataset(val_df, val_features, val_labels, training=False)
    test_ds = build_dataset(test_df, test_features, test_labels, training=False)

    model, base_model = build_hybrid_model()

    callbacks = [
        ModelCheckpoint(
            MODEL_OUTPUT,
            monitor="val_loss",
            save_best_only=True,
            verbose=1
        ),
        EarlyStopping(
            monitor="val_loss",
            patience=5,
            restore_best_weights=True,
            verbose=1
        ),
        ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=2,
            min_lr=1e-7,
            verbose=1
        )
    ]

    print("\nStage 1: Training hybrid classifier...\n")

    history1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=15,
        callbacks=callbacks
    )

    print("\nStage 2: Fine-tuning MobileNetV2...\n")

    base_model.trainable = True

    for layer in base_model.layers[:-40]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
        loss="categorical_crossentropy",
        metrics=["accuracy"]
    )

    history2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=10,
        callbacks=callbacks
    )

    print("\nEvaluating on test set...\n")

    test_loss, test_acc = model.evaluate(test_ds)

    print(f"\nTest Accuracy: {test_acc:.4f}")
    print(f"Test Loss: {test_loss:.4f}")

    plot_curves(history1, history2)

    print("\nDone.")
    print("Best model:", MODEL_OUTPUT)
    print("Class names:", CLASS_OUTPUT)
    print("Scaler:", SCALER_OUTPUT)
    print("Plots: hybrid_accuracy_curve.png / hybrid_loss_curve.png")


if __name__ == "__main__":
    main()
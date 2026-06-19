import sys
import json
import cv2
import joblib
import numpy as np
import tensorflow as tf

from tensorflow.keras.applications.mobilenet_v2 import preprocess_input


IMG_SIZE = (224, 224)

MODEL_PATH = "stylora_hybrid_color_model.keras"
CLASS_NAMES_PATH = "class_names_hybrid.json"
SCALER_PATH = "color_feature_scaler.pkl"


def extract_color_features(image_path):
    img = cv2.imread(image_path)

    if img is None:
        raise ValueError(f"Could not read image: {image_path}")

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


def load_image_for_model(image_path):
    img = tf.io.read_file(image_path)
    img = tf.image.decode_jpeg(img, channels=3)
    img = tf.image.resize(img, IMG_SIZE)
    img = tf.cast(img, tf.float32)
    img = preprocess_input(img)
    img = tf.expand_dims(img, axis=0)

    return img


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print('python predict_color.py "D:\\path\\to\\image.jpg"')
        return

    image_path = sys.argv[1]

    model = tf.keras.models.load_model(MODEL_PATH)

    with open(CLASS_NAMES_PATH, "r", encoding="utf-8") as f:
        class_names = json.load(f)

    scaler = joblib.load(SCALER_PATH)

    image_input = load_image_for_model(image_path)

    color_features = extract_color_features(image_path)
    color_features = scaler.transform([color_features]).astype(np.float32)

    preds = model.predict(
        {
            "image_input": image_input,
            "color_input": color_features
        },
        verbose=0
    )[0]

    top_index = int(np.argmax(preds))

    print("\nPredicted Color:")
    print(class_names[top_index])

    print("\nConfidence:")
    print(float(preds[top_index]))

    print("\nTop 5 Predictions:")
    top5 = np.argsort(preds)[-5:][::-1]

    for idx in top5:
        print(f"{class_names[idx]}: {preds[idx]:.4f}")


if __name__ == "__main__":
    main()
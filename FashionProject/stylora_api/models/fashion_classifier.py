from ultralytics import YOLO

import tensorflow as tf
import numpy as np
import cv2

# =====================================
# PATHS
# =====================================

SEG_MODEL_PATH = r"C:\Users\ASUS\Desktop\2\train\weights\best.pt"

CATEGORY_MODEL_PATH = r"C:\Users\ASUS\Desktop\2\category_full_model.h5"

SLEEVE_MODEL_PATH = r"C:\Users\ASUS\Desktop\2\sleeve_full_model.h5"

# =====================================
# LOAD MODELS
# =====================================

seg_model = YOLO(SEG_MODEL_PATH)

category_model = tf.keras.models.load_model(
    CATEGORY_MODEL_PATH,
    compile=False
)

sleeve_model = tf.keras.models.load_model(
    SLEEVE_MODEL_PATH,
    compile=False
)

print("Models loaded ✅")

# =====================================
# CLASSES
# =====================================

category_classes = [
    'Heels',
    'Sandals',
    'Sneakers',
    'dress',
    'outerwear',
    'pants',
    'shorts',
    'skirt',
    'sling',
    'top'
]

sleeve_classes = [
    'long_sleeve',
    'short_sleeve',
    'sleeveless'
]

# =====================================
# PREDICT
# =====================================

def predict(image_path):

    image = cv2.imread(image_path)

    if image is None:
        return {
            "success": False,
            "message": "Image not found"
        }

    results = seg_model.predict(
        source=image,
        conf=0.5,
        verbose=False
    )

    result = results[0]

    if result.masks is None:
        return {
            "success": False,
            "message": "No clothing detected"
        }

    items = []

    for i in range(len(result.masks.data)):

        mask = result.masks.data[i].cpu().numpy()

        mask = cv2.resize(
            mask,
            (image.shape[1], image.shape[0])
        )

        mask = (mask > 0.5).astype(np.uint8)

        segmented = cv2.bitwise_and(
            image,
            image,
            mask=mask
        )

        ys, xs = np.where(mask > 0)

        if len(xs) == 0 or len(ys) == 0:
            continue

        x1 = np.min(xs)
        x2 = np.max(xs)

        y1 = np.min(ys)
        y2 = np.max(ys)

        area = (x2 - x1) * (y2 - y1)

        # تجاهل القطع الصغيرة
        if area < 15000:
            continue

        crop = segmented[y1:y2, x1:x2]

        if crop.size == 0:
            continue

        resized = cv2.resize(
            crop,
            (300, 300)
        )

        resized = resized.astype(np.float32)

        resized = np.expand_dims(
            resized,
            axis=0
        )

        category_pred = category_model.predict(
            resized,
            verbose=0
        )

        category_index = np.argmax(
            category_pred
        )

        category_name = category_classes[
            category_index
        ]

        category_conf = float(
            category_pred[0][category_index] * 100
        )

        # تجاهل التوقعات الضعيفة
        if category_conf < 80:
            continue

        item = {
            "category": category_name,
            "confidence": round(category_conf, 2)
        }

        if category_name in [
            "dress",
            "outerwear",
            "top"
        ]:

            sleeve_pred = sleeve_model.predict(
                resized,
                verbose=0
            )

            sleeve_index = np.argmax(
                sleeve_pred
            )

            sleeve_name = sleeve_classes[
                sleeve_index
            ]

            item["sleeve"] = sleeve_name

        items.append(item)

    # ترتيب حسب الثقة
    items = sorted(
        items,
        key=lambda x: x["confidence"],
        reverse=True
    )

    # إزالة التكرارات قدر الإمكان
    filtered_items = []

    seen = set()

    for item in items:

        key = item["category"]

        if key in seen:
            continue

        seen.add(key)

        filtered_items.append(item)

    return {
        "success": True,
        "items": filtered_items
    }
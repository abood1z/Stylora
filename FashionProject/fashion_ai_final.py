import os
import sys
import json
import random
import numpy as np
import cv2
import joblib
import tensorflow as tf
from ultralytics import YOLO
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input

# استيراد دالة التوصية من ملفك المحلي recommendation.py
try:
    from recommendation import recommend
except ImportError:
    print("❌ لم يتم العثور على ملف recommendation.py في نفس المجلد!")
    exit()

# =====================================
#  تحديد المسارات الديناميكية (تشتغل على أي جهاز)
# =====================================
# BASE_DIR يعطي مسار المجلد الحالي الذي يتواجد فيه هذا الملف
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

IMAGE_PATH = os.path.join(BASE_DIR, "test3.jpg")
SEG_MODEL_PATH = os.path.join(BASE_DIR, "models", "best.pt")
CATEGORY_MODEL_PATH = os.path.join(BASE_DIR, "models", "category_full_model.h5")
SLEEVE_MODEL_PATH = os.path.join(BASE_DIR, "models", "sleeve_full_model.h5")
OUTPUT_FOLDER = os.path.join(BASE_DIR, "multi_results")

# مسارات نموذج الألوان المطور
COLOR_MODEL_DIR = os.path.join(BASE_DIR, "color_model_files")
COLOR_MODEL_PATH = os.path.join(COLOR_MODEL_DIR, "stylora_hybrid_color_model_boosted.h5")
COLOR_CLASSES_PATH = os.path.join(COLOR_MODEL_DIR, "class_names_hybrid_boosted.json")
COLOR_SCALER_PATH = os.path.join(COLOR_MODEL_DIR, "color_feature_scaler_boosted.pkl")

# إنشاء مجلد المخرجات إذا لم يكن موجوداً
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

# =====================================
# LOAD MODELS (تحميل النماذج)
# =====================================
print("⏳ جاري تحميل النماذج، يرجى الانتظار...")
try:
    seg_model = YOLO(SEG_MODEL_PATH)
    category_model = tf.keras.models.load_model(CATEGORY_MODEL_PATH, compile=False)
    sleeve_model = tf.keras.models.load_model(SLEEVE_MODEL_PATH, compile=False)
    color_model = tf.keras.models.load_model(COLOR_MODEL_PATH, compile=False)

    with open(COLOR_CLASSES_PATH, "r", encoding="utf-8") as f:
        color_classes = json.load(f)

    color_scaler = joblib.load(COLOR_SCALER_PATH)
    print("All models and scalers loaded successfully ✅")
except Exception as e:
    print(f"❌ حدث خطأ أثناء تحميل النماذج: {e}")
    print("تأكد من مطابقة أسماء الملفات والمجلدات للهيكلية المطلوبة.")
    exit()

IMG_SIZE = (224, 224)

# =====================================
# FUNCTIONS (الدوال المساعدة)
# =====================================
def extract_color_features_from_crop(img):
    img = cv2.resize(img, IMG_SIZE)
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)

    rgb_mean, rgb_std = rgb.mean(axis=(0, 1)), rgb.std(axis=(0, 1))
    hsv_mean, hsv_std = hsv.mean(axis=(0, 1)), hsv.std(axis=(0, 1))
    lab_mean, lab_std = lab.mean(axis=(0, 1)), lab.std(axis=(0, 1))

    features = np.concatenate([rgb_mean, rgb_std, hsv_mean, hsv_std, lab_mean, lab_std])
    return features.astype(np.float32)


def predict_color(crop):
    resized = cv2.resize(crop, IMG_SIZE)
    image_input = resized.astype(np.float32)
    image_input = preprocess_input(image_input)
    image_input = np.expand_dims(image_input, axis=0)

    color_features = extract_color_features_from_crop(crop)
    color_features = color_scaler.transform([color_features]).astype(np.float32)

    preds = color_model.predict({"image_input": image_input, "color_input": color_features}, verbose=0)[0]
    idx = np.argmax(preds)
    return color_classes[idx], float(preds[idx])


# =====================================
# CLASSES DEFINITIONS
# =====================================
category_classes = ['Heels', 'Sandals', 'Sneakers', 'dress', 'outerwear', 'pants', 'shorts', 'skirt', 'sling', 'top']
sleeve_classes = ['long_sleeve', 'short_sleeve', 'sleeveless']

# =====================================
# PROCESS IMAGE
# =====================================
image = cv2.imread(IMAGE_PATH)
if image is None:
    print(f"❌ لم يتم العثور على الصورة في المسار: {IMAGE_PATH}")
    exit()

original = image.copy()

# التنبؤ بـ Segmentation
results = seg_model.predict(source=image, conf=0.4, verbose=False)
result = results[0]

if result.masks is None:
    print("❌ No clothing detected")
    exit()

# حلقة التكرار لفحص كل قطعة ملابس مكتشفة
for i in range(len(result.masks.data)):
    print("\n======================")
    print(f"ITEM {i+1}")
    print("======================")

    # استخراج الـ Mask
    mask = result.masks.data[i].cpu().numpy()
    mask = cv2.resize(mask, (image.shape[1], image.shape[0]))
    mask = (mask > 0.5).astype(np.uint8)

    # تطبيق الـ Mask لقص القطعة
    segmented = cv2.bitwise_and(image, image, mask=mask)

    # تحديد أبعاد الـ Bounding Box للقص المباشر
    ys, xs = np.where(mask > 0)
    if len(xs) == 0 or len(ys) == 0:
        continue

    x1, x2 = np.min(xs), np.max(xs)
    y1, y2 = np.min(ys), np.max(ys)
    crop = segmented[y1:y2, x1:x2]

    if crop.size == 0:
        continue

    # حفظ القطعة المقصوصة
    save_path = os.path.join(OUTPUT_FOLDER, f"item_{i+1}.jpg")
    cv2.imwrite(save_path, crop)

    # تجهيز الصورة لتصنيف النوع والأكمام
    resized_classification = cv2.resize(crop, (300, 300)).astype(np.float32)
    resized_classification = np.expand_dims(resized_classification, axis=0)

    # توقع نوع القطعة (Category)
    category_pred = category_model.predict(resized_classification, verbose=0)
    category_index = np.argmax(category_pred)
    category_name = category_classes[category_index]
    category_conf = category_pred[0][category_index] * 100

    print(f"Category: {category_name}")
    print(f"Confidence: {category_conf:.2f}%")

    # توقع لون القطعة (تم إصلاح مكانها لتصبح داخل الـ Loop)
    detected_color, color_conf = predict_color(crop)
    print(f"Color: {detected_color}")
    print(f"Color Confidence: {color_conf*100:.2f}%")

    # جلب التوصيات بناءً على القطعة الحالية
    try:
        recommendations = recommend(category_name, detected_color)
        print("Recommendations:")
        print(f"  Recommended Category: {recommendations.get('recommended_category', 'N/A')}")
        print("  Recommended Colors:")
        for color in recommendations.get("recommended_colors", []):
            print(f"    - {color}")
    except Exception as re:
        print(f"⚠️ حدث خطأ أثناء جلب التوصية: {re}")

    # توقع طول الأكمام إن كانت القطعة علوية (Sleeve Prediction)
    if category_name in ['dress', 'outerwear', 'top']:
        sleeve_pred = sleeve_model.predict(resized_classification, verbose=0)
        sleeve_index = np.argmax(sleeve_pred)
        sleeve_name = sleeve_classes[sleeve_index]
        sleeve_conf = sleeve_pred[0][sleeve_index] * 100

        print(f"Sleeve: {sleeve_name}")
        print(f"Confidence: {sleeve_conf:.2f}%")
    else:
        print("Sleeve model skipped ✅")

    print(f"Saved: {save_path}")

print("\n🔥 MULTI-GARMENT ANALYSIS COMPLETE")
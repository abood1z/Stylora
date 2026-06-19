Stylora Hybrid Clothing Color Classification Model

Architecture:
- MobileNetV2 (ImageNet pretrained)
- Hybrid handcrafted color features
- TensorFlow / Keras

Dataset:
- Original fashion clothing dataset
- Additional boosted apparel color dataset
- 20 clothing color categories

Final Performance:
- Test Accuracy: 88.47%
- Test Loss: 0.5298

Features:
- Robust color recognition
- Fashion-oriented preprocessing
- Hybrid CNN + color statistics pipeline
- Supports real-world fashion photography

Files:
- stylora_hybrid_color_model_boosted.keras -> final trained model
- color_feature_scaler_boosted.pkl -> scaler for handcrafted features
- class_names_hybrid_boosted.json -> class labels
- predict_color.py -> inference script

Tech Stack:
- TensorFlow
- OpenCV
- NumPy
- scikit-learn
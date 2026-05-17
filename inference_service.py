import os
import torch
import cv2
import numpy as np
from flask import Flask, request, jsonify, send_file
from werkzeug.utils import secure_filename
import subprocess

app = Flask(__name__)

# --- CONFIGURATION (Pre-loaded paths) ---
MODELS_CHECKPOINT = "checkpoints/cp-vton-plus/gmm_final.pth"
PARSING_MODEL_DIR = "human_parsing_model"

# --- HELPER FUNCTIONS ---
def run_human_parsing(image_path):
    """Automated Human Parse map generation"""
    output_path = image_path.replace('.jpg', '_parsing.png')
    # Execution of self-correction human parsing script
    subprocess.run(["python3", "run_parsing.py", "--image_path", image_path, "--output_path", output_path], check=True)
    return output_path

def generate_cloth_mask(cloth_image):
    """Automated Cloth Mask generation using basic thresholding or AI based masking"""
    gray = cv2.cvtColor(cloth_image, cv2.COLOR_BGR2GRAY)
    _, mask = cv2.threshold(gray, 250, 255, cv2.THRESH_BINARY_INV)
    return mask

@app.route('/inference_tryon', methods=['POST'])
def inference_tryon():
    """Endpoint for High-Quality Cloud Try-On Processing"""
    if 'person' not in request.files or 'cloth' not in request.files:
        return jsonify({"error": "Images required"}), 400

    person_file = request.files['person']
    cloth_file = request.files['cloth']

    p_filename = secure_filename(person_file.filename)
    c_filename = secure_filename(cloth_file.filename)

    p_path = os.path.join("uploads", p_filename)
    c_path = os.path.join("uploads", c_filename)

    person_file.save(p_path)
    cloth_file.save(c_path)

    try:
        # 1. Automatic Parsing (Human Parsing)
        parsing_map = run_human_parsing(p_path)

        # 2. CP-VTON+ Inference (Warping and Blending)
        # Using subprocess to call the main test script for CP-VTON+
        result_filename = f"result_{p_filename}"
        subprocess.run([
            "python3", "test.py",
            "--checkpoint", MODELS_CHECKPOINT,
            "--person_image", p_path,
            "--cloth_image", c_path,
            "--parsing_map", parsing_map,
            "--output_name", result_filename
        ], check=True)

        result_path = os.path.join("results", result_filename)
        
        # Return logical image URL or direct file (For mobile capture result)
        if os.path.exists(result_path):
            return send_file(result_path, mimetype='image/jpeg')
        else:
            return jsonify({"error": "Processing failed"}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    os.makedirs("uploads", exist_ok=True)
    os.makedirs("results", exist_ok=True)
    app.run(host='0.0.0.0', port=8000, debug=False)

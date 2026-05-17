import os
from flask import Flask, request, send_file, jsonify
import subprocess

app = Flask(__name__)

# Upload folders
INPUTS_DIR = 'inputs'
PARSED_OUTPUT_DIR = 'parsed_output'
RESULTS_DIR = 'results'

os.makedirs(INPUTS_DIR, exist_ok=True)
os.makedirs(PARSED_OUTPUT_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)

@app.route('/process_tryon', methods=['POST'])
def process_tryon():
    if 'person' not in request.files or 'cloth' not in request.files:
        return jsonify({'error': 'Missing person or cloth image'}), 400
    
    person_file = request.files['person']
    cloth_file = request.files['cloth']
    
    person_path = os.path.join(INPUTS_DIR, person_file.filename)
    cloth_path = os.path.join(INPUTS_DIR, cloth_file.filename)
    
    person_file.save(person_path)
    cloth_file.save(cloth_path)
    
    try:
        # Step 1: Self-Correction Human Parsing
        # Extracts Parsing Map automatically
        subprocess.run([
            "python", "run_parsing.py", 
            "--input_dir", INPUTS_DIR, 
            "--output_dir", PARSED_OUTPUT_DIR
        ], check=True)
        
        # Step 2: Run CP-VTON+ test.py using pre-loaded Checkpoints
        subprocess.run([
            "python", "test.py",
            "--name", "cp-vton-plus",
            "--dataset", "inputs",
            "--checkpoint_dir", "checkpoints/",
            "--parsing_dir", PARSED_OUTPUT_DIR,
            "--output_dir", RESULTS_DIR
        ], check=True)
        
        # Step 3: Return the final output image (Warped & Blended)
        # Typically saved with some nomenclature, assuming 'final_output.png' or similar logic
        # For this template we'll assume the model outputs to RESULTS_DIR/<person_filename>
        final_image_path = os.path.join(RESULTS_DIR, f"final_{person_file.filename}")
        
        if os.path.exists(final_image_path):
            return send_file(final_image_path, mimetype='image/png')
        else:
            return jsonify({'error': 'Final output not generated'}), 500
            
    except subprocess.CalledProcessError as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Running on 0.0.0.0 to be accessible within Colab (e.g. using ngrok or localtunnel)
    app.run(host='0.0.0.0', port=5000)

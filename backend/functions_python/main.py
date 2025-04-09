import os
import functions_framework # Use this for local testing if needed
import flask # Provided by the Cloud Functions environment
import logging
import numpy as np
import tensorflow as tf
from PIL import Image # For image processing (Pillow)
import requests # To fetch images from public URLs
from io import BytesIO
from google.cloud import storage # To fetch images from GCS

# --- Configuration ---
# Define the path where the model is stored RELATIVE to main.py
# Adjust 'your_model' to your actual model directory name or file name
# Configuration (use environment variables ideally)
BUCKET_NAME = os.environ.get('MODEL_BUCKET_NAME')
MODEL_GCS_PREFIX = os.environ.get('MODEL_GCS_PREFIX')

LOCAL_MODEL_DIR = '/tmp/model' # Local path in function's temp space

MODEL_DIR = './plant_health_model' # If SavedModel format

# Model input size (adjust to your model's requirements)
IMG_HEIGHT = 224
IMG_WIDTH = 224

# --- Global Variables (Initialize clients, but NOT the model) ---
model = None # Initialize model variable globally, but keep it None initially
storage_client = None

# Define your class names in the correct order expected by the model output
# IMPORTANT: Make sure this matches the training order
CLASS_NAMES = ['bacterial_leaf_blight', 'brown_spot', 'healthy_rice', 
                'gray_mold', 'healthy_sunflower', 'leaf_scars', 'leaf_smut', 
                'downy_mildew', 'septoria_leaf_spot', 'blight', 
                'bacterial_spot', 'healthy_tomato']


def download_model_files(bucket_name, model_gcs_path, local_model_dir):
    """Downloads model files from GCS to local temp directory."""
    try:
        if not os.path.exists(local_model_dir):
             os.makedirs(local_model_dir)

        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blobs = bucket.list_blobs(prefix=model_gcs_path) # List all files

        print(f"Downloading model files from gs://{bucket_name}/{model_gcs_path} to {local_model_dir}")
        for blob in blobs:
            if blob.name.endswith('/'): # Skip "directory" markers
                continue
            # Create local subdir structure if needed
            local_file_path = os.path.join(local_model_dir, os.path.relpath(blob.name, model_gcs_path))
            local_file_dir = os.path.dirname(local_file_path)
            if not os.path.exists(local_file_dir):
                os.makedirs(local_file_dir)

            print(f"Downloading {blob.name} to {local_file_path}")
            blob.download_to_filename(local_file_path)
        print("Model download complete.")
        return True
    except Exception as e:
        print(f"Error downloading model: {e}")
        return False

# --- Load the Model (Load ONCE globally, not inside the function) ---
def load_model():
    """Loads the TF model from the local temp directory."""
    global model
    if model is None: # Load only once per instance
        if download_model_files(BUCKET_NAME, MODEL_GCS_PATH, LOCAL_MODEL_DIR):
            try:
                print(f"Loading model from {LOCAL_MODEL_DIR}...")
                # Adjust loading based on your model format (SavedModel, H5, etc.)
                model = tf.saved_model.load(LOCAL_MODEL_DIR)
                # Or: model = tf.keras.models.load_model(os.path.join(LOCAL_MODEL_DIR, 'your_model.h5'))
                print("Model loaded successfully.")
            except Exception as e:
                print(f"Error loading model from disk: {e}")
                # Handle model loading failure
        else:
             print("Model download failed, cannot load.")
             # Handle download failure

load_model()

# --- Initialize GCS Client (if needed) ---
# Load only if needed to avoid unnecessary initialization
storage_client = None

def get_gcs_client():
    global storage_client
    if storage_client is None:
        storage_client = storage.Client()
    return storage_client

# --- Helper Function: Preprocess Image ---
def preprocess_image(image_bytes):
    """Loads image from bytes, resizes, normalizes, and adds batch dim."""
    try:
        img = Image.open(BytesIO(image_bytes)).convert('RGB') # Ensure 3 channels
        img = img.resize((IMG_WIDTH, IMG_HEIGHT))
        img_array = tf.keras.preprocessing.image.img_to_array(img)
        # Normalize (adjust according to your model's training)
        # Example: Scale to [0, 1]
        img_array = img_array / 255.0
        # Example: Use specific preprocessing if your model needs it (e.g., tf.keras.applications.mobilenet_v2.preprocess_input)
        # img_array = tf.keras.applications.mobilenet_v2.preprocess_input(img_array)

        img_batch = np.expand_dims(img_array, axis=0) # Add batch dimension
        return img_batch
    except Exception as e:
        logging.error(f"Error preprocessing image: {e}")
        return None

# --- Helper Function: Fetch Image ---
def fetch_image_bytes(image_url):
    """Fetches image bytes from GCS or public URL."""
    try:
        if image_url.startswith('gs://'):
            # Fetch from GCS
            client = get_gcs_client()
            bucket_name, blob_name = image_url[5:].split('/', 1)
            bucket = client.bucket(bucket_name)
            blob = bucket.blob(blob_name)
            print(f"Fetching image from GCS: {image_url}")
            return blob.download_as_bytes()
        elif image_url.startswith('http://') or image_url.startswith('https://'):
            # Fetch from public URL
            print(f"Fetching image from URL: {image_url}")
            response = requests.get(image_url, timeout=10) # Add timeout
            response.raise_for_status() # Raise exception for bad status codes
            return response.content
        else:
            logging.error(f"Unsupported image URL scheme: {image_url}")
            return None
    except Exception as e:
        logging.error(f"Error fetching image from {image_url}: {e}")
        return None

# --- Cloud Function Definition ---
@functions_framework.http # Decorator for local testing compatibility (optional)
# Replace 'predict_disease' with your desired function name
def predict_disease(request: flask.Request) -> flask.Response:
    """HTTPS Cloud Function to predict crop disease from an image URL."""

    # --- Load Model (Ensure it's loaded for this invocation) ---
    try:
        load_model() # Call the lazy loader function
        # Check if loading failed (if load_model doesn't raise error but model is still None)
        if model is None:
             logging.error("Model is None even after attempting load.")
             return flask.Response("Model unavailable", status=500)
    except Exception as e:
        # Catch errors specifically from load_model if it raises them
        logging.error(f"Model loading failed during request: {e}")
        return flask.Response(f"Model loading error: {e}", status=500)

    # --- Request Handling ---
    if request.method != 'POST':
        return flask.Response(f"Method Not Allowed", status=405)

    try:
        # Expect JSON body like {"image_url": "gs://... or https://..."}
        request_json = request.get_json(silent=True)
        if not request_json or 'image_url' not in request_json:
            logging.error("Invalid request: Missing JSON body or 'image_url' key.")
            return flask.jsonify({"error": "Invalid request format. Send {'image_url': '...'}"}), 400

        image_url = request_json['image_url']
        print(f"Received request for image_url: {image_url}")

    except Exception as e:
        logging.error(f"Error parsing request: {e}")
        return flask.jsonify({"error": "Bad request data"}), 400

    # --- Image Fetching & Processing ---
    image_bytes = fetch_image_bytes(image_url)
    if image_bytes is None:
        return flask.jsonify({"error": "Failed to fetch image"}), 500

    preprocessed_image = preprocess_image(image_bytes)
    if preprocessed_image is None:
        return flask.jsonify({"error": "Failed to preprocess image"}), 500

    # --- Prediction ---
    try:
        print("Running prediction...")
        # If using SavedModel:
        # Assuming the model has a standard serving signature
        # Check your model's signature using `saved_model_cli show --dir your_model --tag_set serve --signature_def serving_default`
        # Adjust input tensor name if necessary (often 'input_1', 'serving_default_input_1:0', etc.)
        infer = model.signatures["serving_default"] # Or your specific signature key
        # Get the input tensor name from the signature (or hardcode if known)
        input_tensor_name = list(infer.structured_input_signature[1].keys())[0]
        predictions = infer(tf.constant(preprocessed_image, dtype=tf.float32))[list(infer.structured_outputs.keys())[0]]

        # If using Keras H5 model:
        # predictions = model.predict(preprocessed_image)

        # --- Post-processing ---
        # predictions usually contains probabilities for each class
        score = tf.nn.softmax(predictions[0]) # Apply softmax if output isn't already probabilities
        predicted_index = np.argmax(score)
        confidence = float(np.max(score)) # Convert numpy float to standard float
        predicted_disease = CLASS_NAMES[predicted_index]

        print(f"Prediction: {predicted_disease}, Confidence: {confidence:.4f}")

        # --- Response ---
        response_data = {
            "disease": predicted_disease,
            "confidence": confidence
        }
        return flask.jsonify(response_data), 200

    except Exception as e:
        logging.exception(f"Error during prediction or post-processing: {e}") # Log full traceback
        return flask.jsonify({"error": "Prediction failed"}), 500
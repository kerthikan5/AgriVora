"""
**CNN Service**
Responsible for: Loading and running inference on the TensorFlow Keras CNN soil texture model (.h5).
"""

import io
import os
import queue
import threading
import requests
from pathlib import Path

import numpy as np
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # backend/app
LABELS_PATH = os.path.join(BASE_DIR, "models", "soil_cnn", "labels.txt")

MODEL_DIR = Path(BASE_DIR) / "models" / "soil_cnn"
MODEL_PATH = MODEL_DIR / "soil_model.h5"
MODEL_URL = os.getenv("MODEL_URL")

model = None
img_h = 224
img_w = 224

def _load_labels():
    try:
        with open(LABELS_PATH, "r") as f:
            return [line.strip() for line in f.readlines() if line.strip()]
    except Exception:
        return ["Alluvial soil", "Black soil", "Other soil", "Red soil", "Yellow soil"]

LABELS = _load_labels()


def _detect_img_size(keras_model) -> int:
    try:
        inp = keras_model.input_shape
        h = inp[1]
        if h and isinstance(h, int) and h > 0:
            return h
        cfg = keras_model.get_config()
        first_layer = cfg.get("layers", [{}])[0]
        batch_shape = first_layer.get("config", {}).get("batch_shape", [None, None])
        candidate = batch_shape[1] if len(batch_shape) > 1 else None
        if candidate and isinstance(candidate, int) and candidate > 0:
            return candidate
    except Exception:
        pass
    return 224

def ensure_model():
    global MODEL_URL
    # Ensure directory exists
    MODEL_DIR.mkdir(parents=True, exist_ok=True)

    if MODEL_PATH.exists():
        print("[CNN] Model already exists locally.")
        return

    # In case os.getenv was updated after boot, refresh MODEL_URL
    if not MODEL_URL:
        MODEL_URL = os.getenv("MODEL_URL")
    
    if not MODEL_URL:
        raise RuntimeError("MODEL_URL is missing. Please add it to your environment variables.")

    print(f"[CNN] Downloading model from {MODEL_URL}...")
    response = requests.get(MODEL_URL, stream=True, timeout=300)
    response.raise_for_status()

    with open(MODEL_PATH, "wb") as f:
        for chunk in response.iter_content(chunk_size=1024 * 1024):
            if chunk:
                f.write(chunk)

    print("[CNN] Model downloaded successfully.")

def load_model_once():
    global model, img_h, img_w
    if model is None:
        import tensorflow as tf
        ensure_model()
        model = tf.keras.models.load_model(str(MODEL_PATH))
        img_h = _detect_img_size(model)
        img_w = img_h
        print(f"[CNN] Model loaded successfully — input {img_h}x{img_w}x3.")
        
        # Warm-up
        dummy = np.zeros((1, img_h, img_w, 3), dtype="float32")
        _ = model(tf.constant(dummy), training=False)
        print("[CNN] Warm-up done.", flush=True)
    return model


_task_queue = queue.Queue()
_result_store = {}
_store_lock = threading.Lock()
_task_counter = 0
_task_counter_lock = threading.Lock()


def _worker():
    """
    Persistent single background thread.
    Loads TF + model lazily upon first request, then runs all inference sequentially.
    All TF ops happen in this one thread → no cross-thread graph issues.
    """
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

    while True:
        task_id, img_bytes, event = _task_queue.get()
        try:
            import tensorflow as tf
            # Load model lazily
            m = load_model_once()

            img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            img = img.resize((img_w, img_h))

            arr = np.array(img, dtype="float32") / 255.0
            arr = np.expand_dims(arr, axis=0)

            tensor = tf.constant(arr)
            output = m(tensor, training=False)
            probs = output.numpy()[0]

            idx = int(np.argmax(probs))
            confidence = float(probs[idx])

            result = {
                "soil_type": LABELS[idx],
                "confidence": round(confidence, 4),
                "probs": {
                    label: round(float(p), 4)
                    for label, p in zip(LABELS, probs)
                },
            }
            with _store_lock:
                _result_store[task_id] = ("ok", result)

        except Exception as e:
            import traceback
            traceback.print_exc()
            with _store_lock:
                _result_store[task_id] = ("err", str(e))
        finally:
            event.set()

_worker_thread = threading.Thread(target=_worker, daemon=True, name="cnn-worker")
_worker_thread.start()


def predict_soil_type(img_bytes: bytes) -> dict:
    """
    Submit image bytes to the CNN worker thread; wait for the result.
    Thread-safe — can be called from async FastAPI handlers.
    """
    global _task_counter
    with _task_counter_lock:
        _task_counter += 1
        tid = _task_counter

    event = threading.Event()
    _task_queue.put((tid, img_bytes, event))

    # Increased timeout to 500s because downloading the model can take a few minutes on the first request!
    if not event.wait(timeout=500):
        with _store_lock:
            _result_store.pop(tid, None)
        raise RuntimeError("CNN inference timed out after 500 s (Might be downloading the model!)")

    with _store_lock:
        status, payload = _result_store.pop(tid)

    if status == "err":
        raise RuntimeError(payload)

    return payload
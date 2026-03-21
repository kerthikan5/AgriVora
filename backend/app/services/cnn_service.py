"""
**CNN Service**
Responsible for: Loading and running inference on the TensorFlow Keras CNN soil texture model (.h5).
"""

import io
import os
import queue
import threading

import numpy as np
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # backend/app
MODEL_PATH = os.path.join(BASE_DIR, "models", "soil_cnn", "soil_model.h5")
LABELS_PATH = os.path.join(BASE_DIR, "models", "soil_cnn", "labels.txt")


def _load_labels():
    try:
        with open(LABELS_PATH, "r") as f:
            return [line.strip() for line in f.readlines() if line.strip()]
    except Exception:
        return ["Alluvial soil", "Black soil", "Other soil", "Red soil", "Yellow soil"]


LABELS = _load_labels()


def _detect_img_size(model) -> int:
    """
    Detect the expected input spatial size from a Keras model.
    Returns H (assumes square input H==W).
    Falls back to 224 (most common CNN size).
    """
    try:
        inp = model.input_shape  # e.g. (None, 224, 224, 3) or (None, None, None, 3)
        # inp[1] and inp[2] are H and W; they may be None if dynamic
        h = inp[1]
        if h and isinstance(h, int) and h > 0:
            return h
        # Try getting from the first layer config
        cfg = model.get_config()
        first_layer = cfg.get("layers", [{}])[0]
        batch_shape = first_layer.get("config", {}).get("batch_shape", [None, None])
        candidate = batch_shape[1] if len(batch_shape) > 1 else None
        if candidate and isinstance(candidate, int) and candidate > 0:
            return candidate
    except Exception:
        pass
    # Final fallback — 224 is the standard for most pretrained CNNs
    return 224


# ── Dedicated single worker thread ───────────────────────────────────────────
# Step 1: Initialize global task queue and local stores for inter-thread communication
_task_queue: "queue.Queue[tuple]" = queue.Queue()
_result_store: dict = {}
_store_lock = threading.Lock()
_task_counter = 0
_task_counter_lock = threading.Lock()


def _worker():
    """
    Persistent single background thread.
    Loads TF + model once, then runs all inference sequentially.
    All TF ops happen in this one thread → no cross-thread graph issues.
    """
    model = None
    img_h = 224
    img_w = 224
    load_err = None

    try:
        # Step 2: Set TensorFlow environment variables to disable excessive logging
        os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
        import tensorflow as tf

        print("[CNN] Loading model...", flush=True)
        # Step 3: Load the pre-trained h5 soil texture CNN model into memory
        model = tf.keras.models.load_model(MODEL_PATH)

        # Step 4: Detect the expected Input size required by the CNN (usually 224x224)
        img_h = _detect_img_size(model)
        img_w = img_h  # Assume square input

        print(f"[CNN] ✅ Model ready — input {img_h}×{img_w}×3, "
              f"output {model.output_shape}", flush=True)

        # Step 5: Warm-up: perform a dummy prediction to compile the underlying TF function
        dummy = np.zeros((1, img_h, img_w, 3), dtype="float32")
        _ = model(tf.constant(dummy), training=False)
        print("[CNN] Warm-up done.", flush=True)

    except Exception as e:
        import traceback
        traceback.print_exc()
        load_err = str(e)
        print(f"[CNN] ❌ Model load failed: {e}", flush=True)

    # ── Main inference loop ────────────────────────────────────────────────
    while True:
        # Step 6: Wait and fetch a new prediction task from the queue indefinitely
        task_id, img_bytes, event = _task_queue.get()
        try:
            if model is None:
                raise RuntimeError(load_err or "Model failed to load")

            import tensorflow as tf

            # Step 7: Parse input bytes into a PIL image, force to RGB 
            img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            # Step 8: Resize strictly to the CNN's required dimensions
            img = img.resize((img_w, img_h))   # (W, H) for PIL

            # Step 9: Normalize array pixels to [0, 1] range and expand dims to represent a batch of size 1
            arr = np.array(img, dtype="float32") / 255.0
            arr = np.expand_dims(arr, axis=0)   # (1, H, W, 3)

            # Step 10: Run the tf constant tensor inference against the loaded Keras model
            tensor = tf.constant(arr)
            output = model(tensor, training=False)
            probs = output.numpy()[0]

            # Step 11: Identify highest probability class and configure the payload dict
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
            # Step 12: Safely store the prediction back into the dict mapped by the original task_id
            with _store_lock:
                _result_store[task_id] = ("ok", result)

        except Exception as e:
            import traceback
            traceback.print_exc()
            with _store_lock:
                _result_store[task_id] = ("err", str(e))
        finally:
            # Step 13: Raise the thread event flag so the caller function knows its result is ready
            event.set()


# Step 14: Daemonize and boot the backend queue worker thread automatically on file load
_worker_thread = threading.Thread(target=_worker, daemon=True, name="cnn-worker")
_worker_thread.start()


def predict_soil_type(img_bytes: bytes) -> dict:
    """
    Submit image bytes to the CNN worker thread; wait for the result.
    Thread-safe — can be called from async FastAPI handlers.
    """
    global _task_counter
    # Step 15: Atomically increment and assign a unique task sequence ID
    with _task_counter_lock:
        _task_counter += 1
        tid = _task_counter

    # Step 16: Setup an async Thread Event flag and submit image payload to the worker queue
    event = threading.Event()
    _task_queue.put((tid, img_bytes, event))

    # Step 17: Block thread intentionally for up to 200s waiting for the CNN prediction to finish processing
    if not event.wait(timeout=200):
        with _store_lock:
            _result_store.pop(tid, None)
        raise RuntimeError("CNN inference timed out after 200 s")

    # Step 18: Safely extract parsed payload out of the result mapping using the unique ID
    with _store_lock:
        status, payload = _result_store.pop(tid)

    if status == "err":
        raise RuntimeError(payload)

    return payload
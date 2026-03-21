import os, sys
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
import tensorflow as tf
import numpy as np

MODEL_PATH = "app/models/soil_cnn/soil_model.h5"
m = tf.keras.models.load_model(MODEL_PATH)

lines = []
lines.append(f"Input shape: {m.input_shape}")
lines.append(f"Output shape: {m.output_shape}")
lines.append(f"Layer count: {len(m.layers)}")
lines.append("")

for layer in m.layers:
    try:
        lines.append(f"  {layer.name} | {type(layer).__name__} | output: {layer.output_shape}")
    except Exception as e:
        lines.append(f"  {layer.name} | {type(layer).__name__} | output: ERROR")

lines.append("")
lines.append("=== TRYING INPUT SIZES ===")
for sz in [64, 100, 128, 150, 172, 224, 256, 300]:
    try:
        dummy = np.zeros((1, sz, sz, 3), dtype="float32")
        out = m(tf.constant(dummy), training=False)
        lines.append(f"  OK {sz}x{sz} => {out.shape}")
    except Exception as e:
        lines.append(f"  FAIL {sz}x{sz} => {str(e)[:120]}")

with open("model_info.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print("Written to model_info.txt")
print(lines[0])
print(lines[1])

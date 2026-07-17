import os
import json
import numpy as np
from PIL import Image
import tensorflow as tf

class PlantModelLoader:
    def __init__(self, model_path: str, labels_path: str):
        self.model_path = model_path
        self.labels_path = labels_path
        
        # Sınıf isimlerini yükleme
        if not os.path.exists(labels_path):
            raise FileNotFoundError(f"Sınıf etiket dosyası bulunamadı: {labels_path}")
            
        with open(labels_path, "r", encoding="utf-8") as f:
            raw_labels = json.load(f)
            self.labels = {int(k): v for k, v in raw_labels.items()}
            
        # TFLite Modelini yükleme
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"TFLite model dosyası bulunamadı: {model_path}")
            
        self.interpreter = tf.lite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()
        
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        
        self.input_shape = self.input_details[0]['shape']
        self.input_height = self.input_shape[1]
        self.input_width = self.input_shape[2]
        
    def preprocess_image(self, image_bytes: bytes) -> np.ndarray:
        import io
        image = Image.open(io.BytesIO(image_bytes))
        
        if image.mode != "RGB":
            image = image.convert("RGB")
            
        image = image.resize((self.input_width, self.input_height), Image.Resampling.BILINEAR)
        image_np = np.array(image, dtype=np.float32)
        image_np = np.expand_dims(image_np, axis=0)
        return image_np

    def predict(self, image_bytes: bytes, confidence_threshold: float = 0.25):
        input_data = self.preprocess_image(image_bytes)
        
        self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
        self.interpreter.invoke()
        
        output_data = self.interpreter.get_tensor(self.output_details[0]['index'])[0]
        
        top_idx = int(np.argmax(output_data))
        confidence = float(output_data[top_idx])
        predicted_class = self.labels.get(top_idx, "Bilinmeyen Sınıf")
        
        all_predictions = [
            {"class_name": self.labels[i], "confidence": float(val)}
            for i, val in enumerate(output_data)
        ]
        all_predictions.sort(key=lambda x: x["confidence"], reverse=True)
        
        is_confident = confidence >= confidence_threshold
        
        result = {
            "prediction": predicted_class,
            "confidence": confidence,
            "is_confident": is_confident,
            "threshold_used": confidence_threshold,
            "all_predictions": all_predictions[:5]
        }
        
        if not is_confident:
            result["warning"] = (
                f"Tahmin güven skoru ({confidence:.2%}), belirlenen eşik değerin ({confidence_threshold:.2%}) "
                f"altındadır. Görüntü net olmayabilir veya model bu tahminden emin olamamıştır. "
                f"Lütfen daha net veya farklı bir açıdan çekilmiş bir fotoğraf yükleyin."
            )
            
        return result

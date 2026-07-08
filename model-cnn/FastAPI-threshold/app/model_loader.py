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
            # Anahtarları int tipine çevirip sıralı liste oluşturuyoruz
            self.labels = {int(k): v for k, v in raw_labels.items()}
            
        # TFLite Modelini yükleme
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"TFLite model dosyası bulunamadı: {model_path}")
            
        self.interpreter = tf.lite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()
        
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        
        # Beklenen girdi boyutları (Örn: [1, 260, 260, 3])
        self.input_shape = self.input_details[0]['shape']
        self.input_height = self.input_shape[1]
        self.input_width = self.input_shape[2]
        
    def preprocess_image(self, image_bytes: bytes) -> np.ndarray:
        """
        Gelen ham resim baytlarını okur, RGB'ye dönüştürür, 260x260 boyutuna getirir,
        float32 olarak cast eder ve batch boyutunu (1, 260, 260, 3) ekler.
        """
        import io
        image = Image.open(io.BytesIO(image_bytes))
        
        # RGB formatına dönüştürme (PNG/RGBA veya tek kanallı resimler için)
        if image.mode != "RGB":
            image = image.convert("RGB")
            
        # Bilinear interpolation ile yeniden boyutlandırma (eğitim aşamasındaki gibi)
        image = image.resize((self.input_width, self.input_height), Image.Resampling.BILINEAR)
        
        # Numpy array'e dönüştür ve float32 cast et (Değer aralığı 0-255)
        # EfficientNet model yapısı gereği kendi içinde rescaling barındırdığı için normalize etmiyoruz.
        image_np = np.array(image, dtype=np.float32)
        
        # Batch boyutu ekle [1, H, W, C]
        image_np = np.expand_dims(image_np, axis=0)
        return image_np

    def predict(self, image_bytes: bytes, confidence_threshold: float = 0.25):
        """
        Görüntü üzerinde tahmin gerçekleştirir, en yüksek olasılıklı tahmini döner
        ve güven skoru filtrelemesini uygular.
        """
        input_data = self.preprocess_image(image_bytes)
        
        # TFLite inference
        self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
        self.interpreter.invoke()
        
        output_data = self.interpreter.get_tensor(self.output_details[0]['index'])[0]
        
        # En yüksek olasılıklı sınıf ve değeri
        top_idx = int(np.argmax(output_data))
        confidence = float(output_data[top_idx])
        predicted_class = self.labels.get(top_idx, "Bilinmeyen Sınıf")
        
        # Tüm olasılıkları listele (istek durumunda göstermek için)
        all_predictions = [
            {"class_name": self.labels[i], "confidence": float(val)}
            for i, val in enumerate(output_data)
        ]
        # Güven değerine göre azalan şekilde sırala
        all_predictions.sort(key=lambda x: x["confidence"], reverse=True)
        
        # Güven filtresi kontrolü
        is_confident = confidence >= confidence_threshold
        
        result = {
            "prediction": predicted_class,
            "confidence": confidence,
            "is_confident": is_confident,
            "threshold_used": confidence_threshold,
            "all_predictions": all_predictions[:5] # En iyi 5 tahmini dönelim
        }
        
        if not is_confident:
            result["warning"] = (
                f"Tahmin güven skoru ({confidence:.2%}), belirlenen eşik değerin ({confidence_threshold:.2%}) "
                f"altındadır. Görüntü net olmayabilir veya model bu tahminden emin olamamıştır. "
                f"Lütfen daha net veya farklı bir açıdan çekilmiş bir fotoğraf yükleyin."
            )
            
        return result

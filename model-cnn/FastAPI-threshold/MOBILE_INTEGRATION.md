# Mobil Uygulama API Entegrasyon Kılavuzu

Bu belge, oluşturduğumuz **Plant Disease Classification API**'sini gelecekteki mobil uygulamanıza (Flutter, React Native, Kotlin veya Swift) nasıl entegre edeceğinizi adım adım açıklamaktadır.

---

## 1. Kritik Alt Yapı ve Ağ Kuralları

### A. Local (Yerel) Testlerde IP Adresi Seçimi
Mobil emülatörler (veya gerçek cihazlar) `127.0.0.1` veya `localhost` adresini **kendi yerel adresleri** olarak görürler. Bu yüzden bilgisayarınızda çalışan API'ye mobil cihazdan bağlanırken:
* **Bilgisayarınızın yerel IP adresini** kullanmalısınız (Örn: `http://192.168.1.100:8000`).
* Windows terminalinde yerel IP'nizi bulmak için `ipconfig` yazıp `IPv4 Address` değerine bakabilirsiniz.
* Sunucuyu başlatırken ağdaki tüm cihazların erişebilmesi için ana bilgisayarda `0.0.0.0` hostu ile başlatmak gerekebilir. Bunun için `run.py` içindeki `host="127.0.0.1"` satırını `host="0.0.0.0"` olarak değiştirebilirsiniz.

### B. Canlıya Alım (Production)
Uygulamayı mağazaya (App Store / Play Store) yüklemeden önce API'yi bir bulut sunucusuna (AWS, GCP, DigitalOcean, Heroku vb.) yüklemeli ve bir domain alarak **HTTPS** güvenliğini aktif etmelisiniz. Mobil işletim sistemleri (özellikle iOS) varsayılan olarak HTTP bağlantılarını engeller (App Transport Security).

---

## 2. Mobil Kod Örnekleri

### A. Flutter (Dart) Entegrasyonu
Flutter uygulamasında `http` kütüphanesini kullanarak resim gönderme örneği:

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>?> sendImageToApi(File imageFile, double threshold) async {
  // Bilgisayarınızın yerel IP'sini girin
  final uri = Uri.parse('http://192.168.1.100:8000/predict?threshold=$threshold');
  
  var request = http.MultipartRequest('POST', uri);
  
  // Resmi isteğe ekleme
  var multipartFile = await http.MultipartFile.fromPath(
    'file',
    imageFile.path,
    filename: 'leaf_image.jpg',
  );
  request.files.add(multipartFile);
  
  try {
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      // Başarılı yanıt
      return jsonDecode(response.body);
    } else {
      print('Hata kodu: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Bağlantı Hatası: $e');
    return null;
  }
}
```

### B. React Native (JavaScript) Entegrasyonu
React Native uygulamasında `fetch` ve `FormData` kullanarak resim gönderme örneği:

```javascript
const uploadLeafImage = async (imageUri, threshold = 0.25) => {
  const apiUrl = `http://192.168.1.100:8000/predict?threshold=${threshold}`;
  
  const formData = new FormData();
  formData.append('file', {
    uri: Platform.OS === 'ios' ? imageUri.replace('file://', '') : imageUri,
    name: 'leaf_image.jpg',
    type: 'image/jpeg',
  });

  try {
    const response = await fetch(apiUrl, {
      method: 'POST',
      body: formData,
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });

    const result = await response.json();
    
    if (response.ok) {
      console.log('Teşhis:', result.prediction);
      console.log('Güven Skoru:', result.confidence);
      console.log('Güvenli mi?', result.is_confident);
      if (!result.is_confident) {
        console.warn('Uyarı:', result.warning);
      }
      return result;
    } else {
      console.error('API Hatası:', result.detail);
    }
  } catch (error) {
    console.error('Bağlantı Hatası:', error);
  }
};
```

### C. Android (Kotlin) Entegrasyonu
Retrofit interface tanımı ve çağrı örneği:

```kotlin
import okhttp3.MultipartBody
import retrofit2.Response
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Query

// API Response Modeli
data class PredictResponse(
    val prediction: String,
    val confidence: Double,
    val is_confident: Boolean,
    val threshold_used: Double,
    val warning: String?
)

interface PlantApiService {
    @Multipart
    @POST("predict")
    suspend fun predictImage(
        @Part file: MultipartBody.Part,
        @Query("threshold") threshold: Double?
    ): Response<PredictResponse>
}
```

---

## 3. Mobil Uygulamada Güven Skoru Kullanıcı Deneyimi (UX)

Mobil uygulamanızda API'den dönen yanıtları işlerken şu mantığı kurmanız önerilir:

1. **`is_confident == true` durumunda**:
   * Ekranda büyük bir yeşil onay işareti gösterin.
   * Teşhisi (Örn: "Domates - Erken Yanıklık") ve tedaviyi içeren detaylı sayfayı açın.
2. **`is_confident == false` durumunda**:
   * Kullanıcıya sarı bir uyarı ekranı göstererek resmi tekrar çekmesini rica edin.
   * API'den dönen `warning` mesajını doğrudan ekranda gösterin.
   * Eğer isterseniz, *"Yine de en olası sonucu gör"* butonu ekleyerek `all_predictions` listesindeki en yüksek olasılıklı tahmini gösterebilirsiniz.

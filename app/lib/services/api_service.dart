import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService instance = ApiService._init();
  
  // Default emulator IP targeting host machine localhost
  String baseUrl = 'http://10.0.2.2:8000';

  ApiService._init();

  void updateBaseUrl(String newUrl) {
    if (newUrl.isNotEmpty) {
      baseUrl = newUrl;
    }
  }

  Future<Map<String, dynamic>?> predictLeafDisease(File imageFile, {double threshold = 0.25}) async {
    final uri = Uri.parse('$baseUrl/predict?threshold=$threshold');
    var request = http.MultipartRequest('POST', uri);
    
    var multipartFile = await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    );
    request.files.add(multipartFile);

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        print("Backend predict success: $decoded");
        return decoded;
      } else {
        print('Inference failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Connection error in predict: $e');
      return null;
    }
  }

  // 2. Current weather API call
  Future<Map<String, dynamic>?> getCurrentWeather(double latitude, double longitude) async {
    final url = Uri.parse('$baseUrl/weather/current?latitude=$latitude&longitude=$longitude');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('Current weather connection error: $e');
      return null;
    }
  }

  // 3. Forecast weather API call
  Future<List<dynamic>?> getWeatherForecast(double latitude, double longitude) async {
    final url = Uri.parse('$baseUrl/weather/forecast?latitude=$latitude&longitude=$longitude');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('Weather forecast connection error: $e');
      return null;
    }
  }

  // 4. Irrigation calculation
  Future<double> calculateIrrigation(Map<String, dynamic> weatherData, Map<String, dynamic> cropData) async {
    final url = Uri.parse('$baseUrl/irrigation');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'weather_data': weatherData,
          'crop_data': cropData,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['optimal_irrigation_mm'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Irrigation calculation connection error: $e');
      return 0.0;
    }
  }

  // 5. NPK Leaching calculation
  Future<Map<String, dynamic>?> calculateLeaching(double rain, double irr, String soilType) async {
    final url = Uri.parse('$baseUrl/leaching');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'precipitation_mm': rain,
          'net_irrigation_mm': irr,
          'soil_type': soilType,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Leaching calculation connection error: $e');
      return null;
    }
  }

  // 6. Gemini AI Agent recommendations
  Future<String?> getAIRecommendation(Map<String, dynamic> tarlaData) async {
    final url = Uri.parse('$baseUrl/ai/recommend');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(tarlaData),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final rec = data['recommendation'];
        if (rec is String) {
          return rec;
        } else if (rec is Map && rec['recommendation_text'] != null) {
          return rec['recommendation_text'].toString();
        }
        return data['message']?.toString() ?? 'AI Önerisi alındı.';
      }
      print('AI Agent http error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('AI Agent recommendation connection error: $e');
      return null;
    }
  }

  // 7. Get Regional disease logs
  Future<List<dynamic>?> getRegionalRiskLogs() async {
    final url = Uri.parse('$baseUrl/risk-logs');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('Regional risk logs connection error: $e');
      return null;
    }
  }

  // 8. Share Regional risk log
  Future<bool> shareRegionalRiskLog(Map<String, dynamic> logData) async {
    final url = Uri.parse('$baseUrl/risk-logs');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(logData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Share risk log connection error: $e');
      return false;
    }
  }
}

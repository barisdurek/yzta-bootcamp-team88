import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../services/api_service.dart';
import 'opt_detail_screen.dart';
import 'diagnosis_screen.dart';
import 'risk_map_screen.dart';
import 'terra_chat_screen.dart';
import 'profile_settings_screen.dart';
import '../utils/turkey_cities.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _fields = [];
  Map<String, dynamic>? _selectedField;
  Map<String, dynamic>? _activeCrop;
  Map<String, dynamic>? _currentWeather;
  Map<String, dynamic>? _latestRecommendation;
  
  // Simulated sensor readings
  double _soilMoisture = 63.0;
  double _soilTemp = 24.0;
  double _nitrogenLevel = 82.0;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields([int? selectFieldId]) async {
    setState(() => _isLoading = true);
    final userId = (widget.user['id'] ?? widget.user['user_id'] ?? 1) as int;
    final fields = await DatabaseHelper.instance.getFieldsForUser(userId);

    Map<String, dynamic>? nextSelected;
    if (fields.isNotEmpty) {
      if (selectFieldId != null) {
        nextSelected = fields.firstWhere(
          (f) => f['id'] == selectFieldId,
          orElse: () => fields.last,
        );
      } else if (_selectedField != null) {
        final existingId = _selectedField!['id'];
        nextSelected = fields.firstWhere(
          (f) => f['id'] == existingId,
          orElse: () => fields.first,
        );
      } else {
        nextSelected = fields.first;
      }
    }

    setState(() {
      _fields = fields;
      _selectedField = nextSelected;
      if (nextSelected == null) {
        _activeCrop = null;
      }
      _isLoading = false;
    });

    if (_selectedField != null) {
      await _loadFieldDetails();
    }
  }

  Future<void> _loadFieldDetails() async {
    if (_selectedField == null) return;
    
    // Load crop details
    final crop = await DatabaseHelper.instance.getActiveCropForField(_selectedField!['id']);
    // Load latest recommendation
    final rec = await DatabaseHelper.instance.getLatestRecommendation(_selectedField!['id']);
    
    // Load weather from API (mock or real)
    final weather = await ApiService.instance.getCurrentWeather(
      _selectedField!['latitude'] ?? 38.4622,
      _selectedField!['longitude'] ?? 27.0923,
    );

    // Fetch sensors or use defaults
    final sensors = await DatabaseHelper.instance.getSensorsForField(_selectedField!['id']);
    if (sensors.isNotEmpty) {
      _soilMoisture = (sensors.first['soil_moisture_pct'] as num).toDouble();
      _soilTemp = (sensors.first['soil_temp_c'] as num).toDouble();
    } else {
      // Seed default random values for demo
      _soilMoisture = 52.0;
      _soilTemp = 23.0;
    }

    setState(() {
      _activeCrop = crop;
      _latestRecommendation = rec;
      _currentWeather = weather;
    });

    // If there's no recommendation, let's trigger an automatic one to show the bento card
    if (_latestRecommendation == null) {
      await _triggerAIRecommendation();
    }
  }

  Future<void> _triggerAIRecommendation() async {
    if (_selectedField == null || _activeCrop == null) return;

    // Create the exact Input JSON Schema needed by the AI Agent
    final inputJson = {
      "current_time": DateTime.now().toIso8601String(),
      "user_info": {
        "name": widget.user['name'],
        "location": "${_selectedField!['city']} / ${_selectedField!['district']}"
      },
      "field_info": {
        "field_name": _selectedField!['name'],
        "crop_name": _activeCrop!['name'],
        "growth_stage": _activeCrop!['growth_stage'] ?? "Meyve Gelişimi"
      },
      "crop_db_info": {
        "optimum_temp_range": _activeCrop!['optimum_temp_range'],
        "optimum_moisture_range_pct": _activeCrop!['optimum_moisture_range_pct'],
        "suggested_npk": _activeCrop!['suggested_npk'],
        "water_need": _activeCrop!['water_need']
      },
      "farmer_history": [
        {
          "action": "sulama",
          "date": DateTime.now().subtract(const Duration(hours: 48)).toIso8601String(),
          "details": "Damla sulama yapıldı"
        }
      ],
      "sensor_records": {
        "soil_moisture_pct": _soilMoisture,
        "soil_temp_c": _soilTemp
      },
      "weather_forecast": [
        {
          "date": DateTime.now().strftime("%Y-%m-%d"),
          "temp_c": _currentWeather != null ? _currentWeather!['temperature_c'] : 28.0,
          "humidity_pct": _currentWeather != null ? _currentWeather!['humidity_pct'] : 55,
          "precipitation_mm": 0.0,
          "condition": _currentWeather != null ? _currentWeather!['weather_description'] : "Açık"
        },
        {
          "date": DateTime.now().add(const Duration(days: 1)).strftime("%Y-%m-%d"),
          "temp_c": 29.0,
          "humidity_pct": 50,
          "precipitation_mm": 0.0,
          "condition": "Açık"
        }
      ],
      "cnn_disease_result": {
        "detected": false,
        "disease_name": null,
        "confidence_pct": 0
      }
    };

    final result = await ApiService.instance.getAIRecommendation(inputJson);
    if (result != null) {
      final recMap = {
        'field_id': _selectedField!['id'],
        'recommendation_type': 'Proaktif Tavsiye',
        'recommendation_text': result,
        'created_at': DateTime.now().toIso8601String(),
      };
      await DatabaseHelper.instance.insertAIRecommendation(recMap);
      setState(() {
        _latestRecommendation = recMap;
      });
    }
  }

  Future<void> _showAddFieldDialog() async {
    final nameController = TextEditingController();
    final areaController = TextEditingController();
    
    String selectedSoilType = 'Tınlı';
    int selectedCropId = 1;
    String? selectedCity = widget.user['city'] != null && widget.user['city'].toString().isNotEmpty
        ? widget.user['city']
        : 'Konya';
    String? selectedDistrict = widget.user['district'] != null && widget.user['district'].toString().isNotEmpty
        ? widget.user['district']
        : 'Karatay';

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final districts = selectedCity != null ? TurkeyCities.getDistrictsForCity(selectedCity!) : <String>[];
              if (selectedDistrict != null && !districts.contains(selectedDistrict)) {
                selectedDistrict = districts.isNotEmpty ? districts.first : null;
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  'Yeni Tarla Ekle',
                  style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Tarla Adı (örn: Zeytinlik Altı)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: areaController,
                        decoration: const InputDecoration(labelText: 'Alan (Dekar)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      
                      // City Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedCity,
                        decoration: const InputDecoration(labelText: 'İl (Şehir)', border: OutlineInputBorder()),
                        items: TurkeyCities.getCities.map((city) {
                          return DropdownMenuItem(value: city, child: Text(city));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCity = val;
                              selectedDistrict = TurkeyCities.getDistrictsForCity(val).first;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // District Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedDistrict,
                        decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder()),
                        items: districts.map((dist) {
                          return DropdownMenuItem(value: dist, child: Text(dist));
                        }).toList(),
                        onChanged: selectedCity == null
                            ? null
                            : (val) {
                                setDialogState(() {
                                  selectedDistrict = val;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedSoilType,
                        decoration: const InputDecoration(labelText: 'Toprak Tipi', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Killi', child: Text('Killi')),
                          DropdownMenuItem(value: 'Tınlı', child: Text('Tınlı')),
                          DropdownMenuItem(value: 'Kumlu', child: Text('Kumlu')),
                          DropdownMenuItem(value: 'Kireçli', child: Text('Kireçli')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedSoilType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: selectedCropId,
                        decoration: const InputDecoration(labelText: 'Ekili Ürün', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Domates')),
                          DropdownMenuItem(value: 2, child: Text('Patates')),
                          DropdownMenuItem(value: 3, child: Text('Biber')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCropId = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A7C59), foregroundColor: Colors.white),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final area = double.tryParse(areaController.text.trim()) ?? 10.0;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lütfen tarla adını giriniz.'), backgroundColor: Color(0xFFB83230)),
                        );
                        return;
                      }

                      try {
                        final db = DatabaseHelper.instance;
                        final userId = (widget.user['id'] ?? widget.user['user_id'] ?? 1) as int;

                        final fid = await db.insertField({
                          'name': name,
                          'user_id': userId,
                          'city': selectedCity ?? 'Konya',
                          'district': selectedDistrict ?? 'Karatay',
                          'area': area,
                          'soil_type': selectedSoilType,
                          'irrigation_type': 'Damlama',
                          'latitude': 37.87,
                          'longitude': 32.49,
                        });

                        await db.insertFieldCrop({
                          'field_id': fid,
                          'crop_id': selectedCropId,
                          'planting_date': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
                          'growth_stage': 'Vejetatif',
                          'is_active': 1,
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Yeni tarla başarıyla eklendi: $name'), backgroundColor: const Color(0xFF4A7C59)),
                        );
                        await _loadFields(fid);
                      } catch (e) {
                        print("Add field error: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tarla eklenirken bir hata oluştu: $e'), backgroundColor: const Color(0xFFB83230)),
                        );
                      }
                    },
                    child: const Text('Kaydet'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  Future<void> _showAddSensorDataDialog() async {
    final moistController = TextEditingController(text: _soilMoisture.toString());
    final tempController = TextEditingController(text: _soilTemp.toString());

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF6F0),
            title: Text('IoT Sensör Verisi Ekle', style: GoogleFonts.literata(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: moistController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Toprak Nemi (%)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tempController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Toprak Sıcaklığı (°C)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A7C59)),
                onPressed: () async {
                  if (_selectedField == null) return;
                  final moist = double.tryParse(moistController.text) ?? 50.0;
                  final temp = double.tryParse(tempController.text) ?? 22.0;

                  await DatabaseHelper.instance.insertSensorRecord({
                    'field_id': _selectedField!['id'],
                    'soil_moisture_pct': moist,
                    'soil_temp_c': temp,
                    'source': 'IoT Node 1',
                    'raw_data_json': '{}',
                    'measured_at': DateTime.now().toIso8601String(),
                  });

                  Navigator.pop(context);
                  
                  // Reload
                  _soilMoisture = moist;
                  _soilTemp = temp;
                  await _triggerAIRecommendation();
                  setState(() {});
                },
                child: const Text('Ekle', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildDashboardHome() {
    if (_selectedField == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grass_outlined, size: 80, color: Color(0xFF4A7C59)),
              const SizedBox(height: 16),
              Text(
                'Kayıtlı Tarla Bulunmamaktadır',
                style: GoogleFonts.literata(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tarla Gözcüsü\'nün analiz yapabilmesi için ilk tarlanı ekleyerek işe başla.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A7C59), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                onPressed: _showAddFieldDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text('Yeni Tarla Ekle', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Proactive text formatting
    String adviceText = "Tarla verileriniz analiz ediliyor...";
    if (_latestRecommendation != null) {
      adviceText = _latestRecommendation!['recommendation_text'];
      // Extract summary if it contains multiple lines
      if (adviceText.contains('\n')) {
        adviceText = adviceText.split('\n').firstWhere(
          (line) => line.contains('**') || line.contains('⚠️') || line.contains('🔴') || line.length > 20,
          orElse: () => adviceText.split('\n')[0]
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dropdown Field Selector & Weather Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedField != null ? _selectedField!['id'] as int? : null,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A7C59)),
                    items: _fields.map((f) {
                      return DropdownMenuItem<int>(
                        value: f['id'] as int,
                        child: Text(
                          f['name'] ?? f['field_name'] ?? 'Tarla',
                          style: GoogleFonts.literata(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E3230),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final selected = _fields.firstWhere((f) => f['id'] == val, orElse: () => _fields.first);
                        setState(() {
                          _selectedField = selected;
                        });
                        _loadFieldDetails();
                      }
                    },
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currentWeather != null ? '${_currentWeather!['temperature_c']}°C' : '28°C',
                    style: GoogleFonts.literata(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF4A7C59)),
                  ),
                  Text(
                    _currentWeather != null ? _currentWeather!['weather_description'] : 'Açık',
                    style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF705C30)),
                  ),
                ],
              )
            ],
          ),
          Text(
            '${_selectedField!['city']}, ${_selectedField!['district']} • ${_activeCrop != null ? _activeCrop!['name'] : ''}',
            style: GoogleFonts.nunitoSans(fontSize: 14, color: const Color(0xFF6B6358)),
          ),
          const SizedBox(height: 16),
          
          // Proactive Advice Card (Bento Large)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4A7C59).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4A7C59).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A7C59),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Proaktif Tavsiye',
                      style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  adviceText,
                  style: GoogleFonts.nunitoSans(fontSize: 14, color: const Color(0xFF2E3230), height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A7C59),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    // Navigate to AI Assistant Chat Tab
                    setState(() {
                      _currentIndex = 4; // Chat is at index 4
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('AI Mühendisine Sor', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Actions Grid
          Text(
            'Hızlı İşlemler',
            style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = 2; // Diagnose tab
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E8DB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.camera_alt, color: Color(0xFF705C30), size: 30),
                        const SizedBox(height: 8),
                        Text('Yaprak Tara', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF2E3230))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _showAddSensorDataDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E0D8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.settings_input_hdmi, color: Color(0xFF6B6358), size: 30),
                        const SizedBox(height: 8),
                        Text('Sensör Simüle Et', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF2E3230))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Soil Health Bento gauges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toprak Sağlığı Durumu',
                style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
              ),
              Text(
                'CANLI IOT',
                style: GoogleFonts.nunitoSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59), letterSpacing: 1),
              )
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC4C8BC).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Moisture Circular gauge
                _buildCircularGauge('Toprak Nemi', _soilMoisture, '%', Colors.blue),
                // Nitrogen circular gauge
                _buildCircularGauge('Azot Seviyesi', _nitrogenLevel, '%', const Color(0xFF705C30)),
                // Temperature numeric gauge
                Column(
                  children: [
                    const Icon(Icons.thermostat, color: Colors.orange, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      '${_soilTemp.toStringAsFixed(1)}°C',
                      style: GoogleFonts.literata(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Sıcaklık', style: GoogleFonts.nunitoSans(fontSize: 12, color: Colors.grey[600])),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFAF6F0),
                    foregroundColor: const Color(0xFF4A7C59),
                    side: const BorderSide(color: Color(0xFF4A7C59)),
                    elevation: 0,
                  ),
                  onPressed: _showAddFieldDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Tarla Ekle'),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCircularGauge(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: value / 100.0,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${value.toInt()}$unit',
              style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 13),
            )
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.nunitoSans(fontSize: 12, color: Colors.grey[600]),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildDashboardHome(),
      _selectedField != null 
          ? OptDetailScreen(field: _selectedField!, crop: _activeCrop ?? {}) 
          : _buildDashboardHome(),
      _selectedField != null
          ? DiagnosisScreen(field: _selectedField!, crop: _activeCrop ?? {})
          : _buildDashboardHome(),
      RiskMapScreen(user: widget.user),
      _selectedField != null
          ? TerraChatScreen(user: widget.user, field: _selectedField!, crop: _activeCrop ?? {}, soilMoist: _soilMoisture, soilTemp: _soilTemp)
          : _buildDashboardHome(),
      ProfileSettingsScreen(user: widget.user, onUrlUpdated: () {
        _loadFieldDetails();
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0ECE4),
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.agriculture, color: Color(0xFF4A7C59)),
            const SizedBox(width: 8),
            Text(
              'Tarla Gözcüsü',
              style: GoogleFonts.literata(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4A7C59),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: Color(0xFF4A7C59)),
            onPressed: () async {
              if (_selectedField != null) {
                await _loadFieldDetails();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hava durumu ve AI önerileri güncellendi!'), backgroundColor: Color(0xFF4A7C59)),
                );
              }
            },
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF6F0),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -100,
              top: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A7C59).withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              right: -100,
              bottom: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF705C30).withOpacity(0.04),
                ),
              ),
            ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _currentIndex,
                    children: screens,
                  ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFF0ECE4),
        selectedItemColor: const Color(0xFF4A7C59),
        unselectedItemColor: const Color(0xFF6B6358),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Özet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_drop_outlined),
            activeIcon: Icon(Icons.water_drop),
            label: 'Sulama',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: 'Teşhis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Risk Haritası',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Terra',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

// Extension to format DateTime to string matching format in python
extension DateFormatting on DateTime {
  String strftime(String format) {
    if (format == "%Y-%m-%d") {
      return "${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
    }
    return toIso8601String();
  }
  
  String toIso8601StringDate() {
    return toIso8601String().split('T')[0];
  }
}

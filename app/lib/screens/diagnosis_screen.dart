import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../services/api_service.dart';

class DiagnosisScreen extends StatefulWidget {
  final Map<String, dynamic> field;
  final Map<String, dynamic> crop;

  const DiagnosisScreen({super.key, required this.field, required this.crop});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;
  Map<String, dynamic>? _apiResult;
  List<Map<String, dynamic>> _pastRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPastRecords();
  }

  @override
  void didUpdateWidget(covariant DiagnosisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field['id'] != widget.field['id']) {
      _loadPastRecords();
    }
  }

  Future<void> _loadPastRecords() async {
    final records = await DatabaseHelper.instance.getDiseaseRecordsForField(widget.field['id']);
    setState(() {
      _pastRecords = records;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _apiResult = null;
      _isUploading = true;
    });

    // Call API predict
    final result = await ApiService.instance.predictLeafDisease(_selectedImage!, threshold: 0.25);
    
    setState(() {
      _isUploading = false;
      _apiResult = result;
    });

    if (result != null && result['is_confident'] == true) {
      // Save record in local SQLite database
      final diseaseName = result['prediction'];
      final confidence = result['confidence'] as double;
      
      // Auto generate treatment plan based on disease
      String advice = "Hastalık teşhis edildi. Bitkiyi gözlemleyin.";
      if (diseaseName.contains("Bacterial") || diseaseName.contains("leke")) {
        advice = "Bakırlı fungusit (organik) püskürtün. Sulamayı yapraktan yapmayın.";
      } else if (diseaseName.contains("blight") || diseaseName.contains("Yanıklık")) {
        advice = "Hastalıklı yaprakları budayıp yakın. Metalaxyl aktif maddeli ruhsatlı ilaç kullanın.";
      } else if (diseaseName.contains("Mold") || diseaseName.contains("küfü")) {
        advice = "Sera havalandırmasını artırın. Kükürtlü organik toz püskürtmesi planlayın.";
      }

      await DatabaseHelper.instance.insertDiseaseRecord({
        'field_id': widget.field['id'],
        'crop_id': widget.crop['id'] ?? 1,
        'image_path': _selectedImage!.path,
        'predicted_disease': diseaseName,
        'confidence_score': confidence,
        'ai_recommendation': advice,
        'detected_at': DateTime.now().toIso8601String(),
      });

      _loadPastRecords();
    }
  }

  Future<void> _shareToRegionalRisk(String disease) async {
    // Strips coordinates and details for privacy (Modül 4)
    final gridCode = 'Grid_${widget.field['city']}_${widget.field['district']}_${widget.field['id']}';
    
    final riskData = {
      "grid_code": gridCode,
      "region_name": "${widget.field['district']} Bölgesi",
      "city": widget.field['city'],
      "district": widget.field['district'],
      "crop_name": widget.crop['name'] ?? "Bilinmeyen Ürün",
      "risk_type": "Hastalık Uyarısı",
      "detected_disease": disease,
      "risk_level": "Yüksek",
      "source": "Kullanıcı Teşhisi"
    };

    final success = await ApiService.instance.shareRegionalRiskLog(riskData);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teşhis bilgisi bölgenizdeki diğer çiftçileri korumak için anonim olarak paylaşıldı!'),
            backgroundColor: Color(0xFF4A7C59),
          ),
        );
      }
    }
  }

  Widget _buildResultPanel() {
    if (_apiResult == null) return const SizedBox();

    final isConfident = _apiResult!['is_confident'] == true;
    final disease = _apiResult!['prediction'];
    final confidence = (_apiResult!['confidence'] as num).toDouble() * 100;
    final warning = _apiResult!['warning'];

    if (!isConfident) {
      // Low confidence screen (UX rules)
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDAD8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB83230).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning, color: Color(0xFFB83230)),
                    const SizedBox(width: 8),
                    Text(
                      'Güven Eşiği Altında Kalındı!',
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF690005)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  warning ?? 'Resim net değil veya model bu yaprak teşhisinden emin olamadı. Lütfen daha net bir fotoğraf çekin.',
                  style: GoogleFonts.nunitoSans(color: const Color(0xFF690005)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Fallback view button
          ExpansionTile(
            title: Text(
              'Yine de olası sonuçları gör',
              style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF705C30)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: (_apiResult!['all_predictions'] as List).map<Widget>((p) {
                    final confVal = (p['confidence'] as num).toDouble() * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(p['class_name'].toString(), style: GoogleFonts.nunitoSans(fontSize: 13)),
                          Text('%${confVal.toStringAsFixed(1)}', style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            ],
          )
        ],
      );
    }

    // Confident diagnosis screen
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4A7C59), size: 28),
                const SizedBox(width: 8),
                Text(
                  'Teşhis Tamamlandı',
                  style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sınıf / Hastalık:', style: GoogleFonts.nunitoSans(color: Colors.grey[700])),
                Text(
                  disease.toString().replaceAll('_', ' '),
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Güven Skoru:', style: GoogleFonts.nunitoSans(color: Colors.grey[700])),
                Text(
                  '%${confidence.toStringAsFixed(1)}',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Treatment protocols
            Text('Ziraat Mühendisi Önerisi:', style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8DB).withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '☘ Organik Çözüm:',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF705C30)),
                  ),
                  Text(
                    'Hastalıklı yaprakları budayın ve tarladan uzaklaştırıp imha edin. Organik tarıma uygun bakırlı fungusit uygulaması yapın.',
                    style: GoogleFonts.nunitoSans(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '🧪 Kimyasal Çözüm (Ruhsatlı İlaç):',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
                  ),
                  Text(
                    'Hastalık şiddetliyse sistemik etkili Metalaxyl veya Cymoxanil etken maddeli ilaçları sabah rüzgarsız saatte uygulayın.',
                    style: GoogleFonts.nunitoSans(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Share button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF705C30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _shareToRegionalRisk(disease),
              icon: const Icon(Icons.share, size: 18),
              label: Text('Bölgesel Koruma Ağına Anonim Paylaş', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Yapay Zeka Yaprak Teşhisi',
            style: GoogleFonts.literata(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
          ),
          Text(
            'CNN modelimizi kullanarak bitki yaprak fotoğraflarından anında hastalık teşhisi yapın.',
            style: GoogleFonts.nunitoSans(fontSize: 14, color: const Color(0xFF6B6358)),
          ),
          const SizedBox(height: 20),

          // Upload card
          Card(
            color: Colors.white.withOpacity(0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
                        )
                      : Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                          ),
                          child: const Icon(Icons.image_search, size: 48, color: Colors.grey),
                        ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7C59),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Fotoğraf Çek'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4A7C59),
                            side: const BorderSide(color: Color(0xFF4A7C59)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeri'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Uploading indicator
          if (_isUploading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A7C59))),
                    SizedBox(height: 12),
                    Text('Yaprak analiz ediliyor, lütfen bekleyin...'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // API Result
          _buildResultPanel(),
          const SizedBox(height: 24),

          // Past logs list
          if (_pastRecords.isNotEmpty) ...[
            Text(
              'Geçmiş Teşhis Kayıtları',
              style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pastRecords.length,
              itemBuilder: (context, index) {
                final rec = _pastRecords[index];
                final parsedDate = DateTime.tryParse(rec['detected_at'] ?? '');
                final date = parsedDate != null ? parsedDate.toIso8601String().split('T')[0] : '';
                final conf = ((rec['confidence_score'] as num?)?.toDouble() ?? 0.0) * 100;
                
                return Card(
                  color: Colors.white.withOpacity(0.6),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.spa, color: Color(0xFF4A7C59)),
                    title: Text(
                      rec['predicted_disease'].toString().replaceAll('_', ' '),
                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Tarih: $date • Güven: %${conf.toStringAsFixed(1)}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFFFAF6F0),
                            title: Text(rec['predicted_disease'].toString().replaceAll('_', ' '), style: GoogleFonts.literata(fontWeight: FontWeight.bold)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Güven: %${conf.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Tarih: ${rec['detected_at']}'),
                                const Divider(),
                                Text('Öneri:', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold)),
                                Text(rec['ai_recommendation'] ?? ''),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Kapat'),
                              )
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ]
        ],
      ),
    );
  }
}
extension StringParsing on String {
  String toNormalFormat() {
    return replaceAll('_', ' ');
  }
}

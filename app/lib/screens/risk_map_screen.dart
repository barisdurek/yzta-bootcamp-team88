import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../services/api_service.dart';

class RiskMapScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const RiskMapScreen({super.key, required this.user});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _userFields = [];
  Map<int, Map<String, dynamic>> _fieldCrops = {};
  List<dynamic> _riskLogs = [];
  String? _dangerAlert;

  @override
  void initState() {
    super.initState();
    _loadRiskData();
  }

  Future<void> _loadRiskData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _dangerAlert = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final userId = widget.user['id'] as int?;
      
      if (userId != null) {
        final fields = await db.getFieldsForUser(userId);
        final Map<int, Map<String, dynamic>> crops = {};
        for (var f in fields) {
          final fid = f['id'] as int?;
          if (fid != null) {
            final activeCrop = await db.getActiveCropForField(fid);
            if (activeCrop != null) {
              crops[fid] = activeCrop;
            }
          }
        }
        _userFields = fields;
        _fieldCrops = crops;
      }

      // Fetch regional risk logs from backend
      final logs = await ApiService.instance.getRegionalRiskLogs();
      if (logs != null) {
        final userDistrict = widget.user['district'] ?? 'Karatay';
        final nearHazard = logs.firstWhere(
          (log) => (log['district'] == userDistrict && log['risk_level'] == 'Yüksek'),
          orElse: () => null,
        );

        if (nearHazard != null) {
          _dangerAlert = '⚠️ KRİTİK BÖLGESEL UYARI: ${nearHazard['district']} civarındaki tarlalarda "${nearHazard['detected_disease']}" zararlısı tespit edilmiştir! Lütfen mahsullerinizi hemen kontrol edin.';
        }
        _riskLogs = logs;
      }
    } catch (e) {
      print("Risk data load error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'Yüksek':
      case 'Kritik':
        return const Color(0xFFB83230);
      case 'Orta':
        return const Color(0xFF705C30);
      default:
        return const Color(0xFF4A7C59);
    }
  }

  Map<String, dynamic> _calculateFieldRisk(Map<String, dynamic> field, Map<String, dynamic>? crop) {
    final cropName = (crop != null ? crop['name'] ?? 'Domates' : 'Domates').toString();
    final district = (field['district'] ?? widget.user['district'] ?? 'Karatay').toString();
    final city = (field['city'] ?? field['province'] ?? widget.user['city'] ?? 'Konya').toString();
    final soil = (field['soil_type'] ?? 'Tınlı').toString();

    String riskLevel = 'Orta';
    String diseaseRisk = 'Erken Yanıklık İhtimali';
    String details = 'Bağıl nem %65 seviyesindedir.';
    String action = 'Düzenli kontrol sağlayın.';

    final nameLower = cropName.toLowerCase();
    if (nameLower.contains('patates')) {
      riskLevel = 'Yüksek';
      diseaseRisk = 'Geç Yanıklık (Phytophthora) İhtimali';
      details = '$city - $district bölgesindeki toprak nemi ve gece sıcaklık düşüşü spor çimlenmesine uygundur.';
      action = 'Damlama sulamaya geçin ve koruyucu Bakır / Metalaxyl ilaçlamasını değerlendirin.';
    } else if (nameLower.contains('biber')) {
      riskLevel = 'Orta';
      diseaseRisk = 'Bakteriyel Leke (Xanthomonas) Riski';
      details = 'Nem %60 seviyesinde, rüzgar hızı düşük. Bakteriyel yayılım riski orta seviyededir.';
      action = 'Yaprakları üstten ıslatacak sulama yöntemlerinden kaçının.';
    } else {
      riskLevel = soil == 'Killi' ? 'Yüksek' : 'Düşük';
      diseaseRisk = 'Erken Yanıklık (Alternaria solani) Riski';
      details = 'Sıcaklık 24°C, gündüz nemi %55. Yaprak ıslaklık süresi takibi önerilir.';
      action = 'Hastalıklı alt yaprakları budayın ve havalandırmayı artırın.';
    }

    return {
      'level': riskLevel,
      'disease_risk': diseaseRisk,
      'details': details,
      'action': action,
      'crop_name': cropName,
      'location': '$city / $district'
    };
  }

  void _showFieldRiskDetailDialog(Map<String, dynamic> field, Map<String, dynamic> riskInfo) {
    final color = _getRiskColor(riskInfo['level']);
    final sizeDekar = (field['area'] as num?)?.toDouble() ?? (((field['area_m2'] as num?)?.toDouble() ?? 0.0) / 1000.0);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  field['name'] ?? field['field_name'] ?? 'Tarla Risk Raporu',
                  style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Aktif Risk Düzeyi: ${riskInfo['level'].toUpperCase()}',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: color, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text('📍 Konum:', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
                Text('${riskInfo['location']} • ${sizeDekar.toStringAsFixed(1)} Dekar', style: GoogleFonts.nunitoSans(fontSize: 13)),
                const SizedBox(height: 8),
                Text('🌾 Mahsul ve Toprak:', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
                Text('${riskInfo['crop_name']} • Toprak: ${field['soil_type'] ?? 'Tınlı'}', style: GoogleFonts.nunitoSans(fontSize: 13)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text('🦠 Olası Teşhis Riski:', style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF2E3230))),
                const SizedBox(height: 4),
                Text(riskInfo['disease_risk'], style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                const SizedBox(height: 6),
                Text(riskInfo['details'], style: GoogleFonts.nunitoSans(fontSize: 13, height: 1.3, color: const Color(0xFF6B6358))),
                const SizedBox(height: 12),
                Text('💡 Ziraat Mühendisi Tavsiyesi:', style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF4A7C59))),
                const SizedBox(height: 4),
                Text(riskInfo['action'], style: GoogleFonts.nunitoSans(fontSize: 13, height: 1.3)),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A7C59), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRiskData,
      color: const Color(0xFF4A7C59),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bölgesel Risk Ağı ve Koruma',
                        style: GoogleFonts.literata(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
                      ),
                      Text(
                        'Kayıtlı tarlalarınız ve çevre tarlalardan gelen canlı uyarılar.',
                        style: GoogleFonts.nunitoSans(fontSize: 13, color: const Color(0xFF6B6358)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF4A7C59)),
                  onPressed: _loadRiskData,
                )
              ],
            ),
            const SizedBox(height: 16),

            // High urgency warning banner
            if (_dangerAlert != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB83230).withOpacity(0.3)),
                ),
                child: Text(
                  _dangerAlert!,
                  style: GoogleFonts.nunitoSans(
                    color: const Color(0xFF690005),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. User's Fields Risk Cards
            Text(
              'Arazileriniz İçin Canlı Risk Analizi',
              style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
            ),
            const SizedBox(height: 8),

            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                : _userFields.isEmpty
                    ? Card(
                        color: Colors.white.withOpacity(0.6),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Henüz tescilli bir araziniz yok. Profil sekmesinden tarla ekleyerek bölgesel risk takibini başlatabilirsiniz.',
                            style: GoogleFonts.nunitoSans(color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        children: _userFields.map((field) {
                          final fid = field['id'] as int;
                          final activeCrop = _fieldCrops[fid];
                          final riskInfo = _calculateFieldRisk(field, activeCrop);
                          final color = _getRiskColor(riskInfo['level']);
                          final sizeDekar = (field['area'] as num?)?.toDouble() ?? (((field['area_m2'] as num?)?.toDouble() ?? 0.0) / 1000.0);

                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 1.5,
                            child: InkWell(
                              onTap: () => _showFieldRiskDetailDialog(field, riskInfo),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(Icons.location_on, color: color, size: 20),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  field['name'] ?? field['field_name'] ?? 'İsimsiz Tarla',
                                                  style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF2E3230)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Risk: ${riskInfo['level']}',
                                            style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: color, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${riskInfo['location']} • ${riskInfo['crop_name']} (${sizeDekar.toStringAsFixed(1)} Dekar)',
                                      style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF6B6358)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      riskInfo['disease_risk'],
                                      style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      riskInfo['details'],
                                      style: GoogleFonts.nunitoSans(fontSize: 12, color: Colors.grey[700]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text('Detaylı Rapor', style: GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59))),
                                        const Icon(Icons.chevron_right, size: 14, color: Color(0xFF4A7C59)),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

            const SizedBox(height: 20),

            // 2. Regional Risk Logs Feed
            Text(
              'Çevresel Anonim Risk Bildirimleri',
              style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
            ),
            const SizedBox(height: 8),

            _isLoading
                ? const SizedBox()
                : _riskLogs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Şu an bölgenizde aktif bir çevre risk bildirimi bulunmamaktadır.',
                            style: GoogleFonts.nunitoSans(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _riskLogs.length,
                        itemBuilder: (context, index) {
                          final log = _riskLogs[index];
                          final color = _getRiskColor(log['risk_level'] ?? 'Orta');
                          
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Seviye: ${log['risk_level']}',
                                          style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: color, fontSize: 10),
                                        ),
                                      ),
                                      Text(
                                        log['grid_code'] ?? '',
                                        style: GoogleFonts.nunitoSans(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${log['city']}, ${log['district']} • ${log['crop_name']}',
                                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF6B6358)),
                                  ),
                                  Text(
                                    '${log['detected_disease']} Teşhisi Yapıldı',
                                    style: GoogleFonts.literata(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class RiskMapScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const RiskMapScreen({super.key, required this.user});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  bool _isLoading = false;
  List<dynamic> _riskLogs = [];
  String? _dangerAlert;

  @override
  void initState() {
    super.initState();
    _fetchRiskLogs();
  }

  Future<void> _fetchRiskLogs() async {
    setState(() {
      _isLoading = true;
      _dangerAlert = null;
    });

    final logs = await ApiService.instance.getRegionalRiskLogs();

    if (logs != null) {
      // Find if there is a severe hazard near Karatay or the user's registered district
      final userDistrict = widget.user['district'] ?? 'Karatay';
      
      final nearHazard = logs.firstWhere(
        (log) => (log['district'] == userDistrict && log['risk_level'] == 'Yüksek'),
        orElse: () => null,
      );

      if (nearHazard != null) {
        _dangerAlert = '⚠️ KRİTİK UYARI: ${nearHazard['district']} bölgesinde, ${nearHazard['crop_name']} mahsullerinde yakın tarlalarda "${nearHazard['detected_disease']}" zararlısı tespit edilmiştir! Lütfen mahsullerinizi hemen kontrol edin.';
      }

      setState(() {
        _riskLogs = logs;
      });
    }

    setState(() {
      _isLoading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchRiskLogs,
      color: const Color(0xFF4A7C59),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bölgesel Risk Ağı ve Koruma',
              style: GoogleFonts.literata(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
            ),
            Text(
              'Çevredeki tarlalardan toplanan anonim hastalık teşhis kayıtları ve uyarılar.',
              style: GoogleFonts.nunitoSans(fontSize: 14, color: const Color(0xFF6B6358)),
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
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bölgesel Aktif Alarmlar',
                  style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF4A7C59)),
                  onPressed: _fetchRiskLogs,
                )
              ],
            ),
            const SizedBox(height: 8),

            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _riskLogs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'Şu an bölgenizde aktif bir risk raporu bulunmamaktadır.',
                            style: GoogleFonts.nunitoSans(color: Colors.grey),
                            textAlign: TextAlign.center,
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
                            color: Colors.white.withOpacity(0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Seviye: ${log['risk_level']}',
                                          style: GoogleFonts.nunitoSans(
                                            fontWeight: FontWeight.bold, 
                                            color: color,
                                            fontSize: 11
                                          ),
                                        ),
                                      ),
                                      Text(
                                        log['grid_code'] ?? '',
                                        style: GoogleFonts.nunitoSans(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${log['city']}, ${log['district']} • ${log['crop_name']}',
                                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF6B6358)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${log['detected_disease']} Teşhisi Yapıldı',
                                    style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.source_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Kaynak: ${log['source']}',
                                        style: GoogleFonts.nunitoSans(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  )
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

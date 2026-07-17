import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class OptDetailScreen extends StatefulWidget {
  final Map<String, dynamic> field;
  final Map<String, dynamic> crop;

  const OptDetailScreen({super.key, required this.field, required this.crop});

  @override
  State<OptDetailScreen> createState() => _OptDetailScreenState();
}

class _OptDetailScreenState extends State<OptDetailScreen> {
  bool _isLoading = false;
  List<dynamic> _forecast = [];
  List<double> _waterNeeds = [];
  Map<String, dynamic>? _leachingResults;

  @override
  void initState() {
    super.initState();
    _fetchOptimizationData();
  }

  @override
  void didUpdateWidget(covariant OptDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field['id'] != widget.field['id'] || oldWidget.crop['id'] != widget.crop['id']) {
      _fetchOptimizationData();
    }
  }

  Future<void> _fetchOptimizationData() async {
    setState(() {
      _isLoading = true;
      _forecast = [];
      _waterNeeds = [];
      _leachingResults = null;
    });

    final lat = widget.field['latitude'] ?? 38.4622;
    final lon = widget.field['longitude'] ?? 27.0923;

    // Get weather forecast
    final forecastData = await ApiService.instance.getWeatherForecast(lat, lon);
    if (forecastData != null && forecastData.isNotEmpty) {
      _forecast = forecastData;

      // Calculate Penman-Monteith water needs for each forecast day
      for (var day in forecastData) {
        final cropData = {
          'root_depth_m': widget.crop['root_depth_m'] ?? 0.5,
          'crop_coefficient': widget.crop['kc'] ?? 0.85,
        };
        final water = await ApiService.instance.calculateIrrigation(day, cropData);
        _waterNeeds.add(water);
      }

      // Calculate leaching for tomorrow (index 1) which is likely simulated to rain
      if (forecastData.length > 1) {
        final tomorrow = forecastData[1];
        final rain = (tomorrow['precipitation_mm'] as num?)?.toDouble() ?? 0.0;
        final irr = _waterNeeds[1];
        final soil = widget.field['soil_type'] ?? 'Tınlı';

        final leaching = await ApiService.instance.calculateLeaching(rain, irr, soil);
        if (leaching != null) {
          _leachingResults = leaching;
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_forecast.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Hava Tahmin Verisi Alınamadı',
                style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _fetchOptimizationData,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    // Leaching values
    final nLoss = _leachingResults?.containsKey('N_loss_pct') == true ? _leachingResults!['N_loss_pct'] as double : 0.0;
    final pLoss = _leachingResults?.containsKey('P_loss_pct') == true ? _leachingResults!['P_loss_pct'] as double : 0.0;
    final kLoss = _leachingResults?.containsKey('K_loss_pct') == true ? _leachingResults!['K_loss_pct'] as double : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Screen Title
          Text(
            'Sulama ve Gübreleme Yönetimi',
            style: GoogleFonts.literata(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
          ),
          Text(
            'Hava tahminlerine göre Penman-Monteith su ihtiyacı ve gübre yıkanma analizi.',
            style: GoogleFonts.nunitoSans(fontSize: 14, color: const Color(0xFF6B6358)),
          ),
          const SizedBox(height: 20),

          // 3-Day Water Optimization Table
          Card(
            color: Colors.white.withOpacity(0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '3 Günlük Su İhtiyacı Optimizasyonu',
                    style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _forecast.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final day = _forecast[index];
                      final water = _waterNeeds.length > index ? _waterNeeds[index] : 0.0;
                      final rain = (day['precipitation_mm'] as num?)?.toDouble() ?? 0.0;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day['date'] ?? '',
                                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '${day['temp_c']}°C • ${day['condition']}',
                                  style: GoogleFonts.nunitoSans(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${water.toStringAsFixed(1)} L/m²',
                                  style: GoogleFonts.literata(
                                    fontWeight: FontWeight.bold, 
                                    color: water > 0 ? const Color(0xFF4A7C59) : Colors.grey,
                                    fontSize: 15
                                  ),
                                ),
                                Text(
                                  rain > 0 ? 'Yağış: ${rain}mm (İptal/Azalt)' : 'Yağış Yok',
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 11, 
                                    color: rain > 15 ? const Color(0xFFB83230) : Colors.grey[500],
                                    fontWeight: rain > 15 ? FontWeight.bold : FontWeight.normal
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fertilizer Leaching Simulation Card
          Card(
            color: Colors.white.withOpacity(0.8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Besin Yıkanma Risk Simülasyonu',
                        style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
                      ),
                      Tooltip(
                        message: 'Toprak tipine ve beklenen yağış miktarına bağlı hesaplanan NPK sızma oranı.',
                        child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Yarın beklenen hava durumuna göre NPK gübre kayıp yüzdeleri:',
                    style: GoogleFonts.nunitoSans(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),

                  // Custom visual Bar chart for NPK
                  _buildNPKBar('Azot (N)', nLoss, Colors.blue),
                  const SizedBox(height: 12),
                  _buildNPKBar('Fosfor (P)', pLoss, Colors.red),
                  const SizedBox(height: 12),
                  _buildNPKBar('Potasyum (K)', kLoss, Colors.orange),

                  const SizedBox(height: 20),
                  // Leaching Advice Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8E0A8).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF705C30).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFF705C30), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Gübreleme Tavsiyesi',
                              style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF705C30)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          nLoss > 20
                              ? '⚠️ Şiddetli yağış topraktaki azotu alta geçirmiştir (yıkanma %${nLoss.toStringAsFixed(1)}). Bitkinin sararmasını önlemek için bir sonraki sulamada %10 ekstra azot takviyesi yapın.'
                              : '✓ Mevcut yıkanma riski düşüktür. Rutin gübreleme programınıza devam edebilirsiniz.',
                          style: GoogleFonts.nunitoSans(fontSize: 13, color: const Color(0xFF2E3230)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNPKBar(String element, double value, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(element, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('%${value.toStringAsFixed(1)} Kayıp', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 13, color: value > 15 ? const Color(0xFFB83230) : Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              height: 12,
              width: MediaQuery.of(context).size.width * 0.75 * (value / 100.0),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        )
      ],
    );
  }
}

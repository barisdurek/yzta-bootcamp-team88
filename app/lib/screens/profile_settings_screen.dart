import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../services/api_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUrlUpdated;

  const ProfileSettingsScreen({super.key, required this.user, required this.onUrlUpdated});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  late Map<String, dynamic> _currentUser;
  
  List<Map<String, dynamic>> _userFields = [];
  Map<int, Map<String, dynamic>> _fieldCrops = {};
  bool _loadingFields = true;
  String _selectedLanguage = 'tr';

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _urlController.text = ApiService.instance.baseUrl;
    _loadFieldsData();
  }

  Future<void> _loadFieldsData() async {
    if (!mounted) return;
    setState(() {
      _loadingFields = true;
    });
    try {
      final db = DatabaseHelper.instance;
      final userId = _currentUser['id'] as int?;
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
        if (mounted) {
          setState(() {
            _userFields = fields;
            _fieldCrops = crops;
            _loadingFields = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingFields = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFields = false;
        });
      }
    }
  }

  void _saveUrlSetting() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      ApiService.instance.updateBaseUrl(url);
      widget.onUrlUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend API adresi başarıyla güncellendi!'),
          backgroundColor: Color(0xFF4A7C59),
        ),
      );
    }
  }

  // Edit Profile Dialog
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _currentUser['name']);
    final phoneCtrl = TextEditingController(text: _currentUser['phone'] ?? '');
    final cityCtrl = TextEditingController(text: _currentUser['city'] ?? 'Konya');
    final districtCtrl = TextEditingController(text: _currentUser['district'] ?? 'Karatay');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Profili Düzenle',
            style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Telefon Numarası', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'Şehir', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: districtCtrl,
                  decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder()),
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
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final city = cityCtrl.text.trim();
                final district = districtCtrl.text.trim();

                if (name.isNotEmpty) {
                  final updatedUser = Map<String, dynamic>.from(_currentUser);
                  updatedUser['name'] = name;
                  updatedUser['phone'] = phone;
                  updatedUser['city'] = city;
                  updatedUser['district'] = district;

                  await DatabaseHelper.instance.updateUser(updatedUser);
                  
                  setState(() {
                    _currentUser = updatedUser;
                  });
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil bilgileri güncellendi!'), backgroundColor: Color(0xFF4A7C59)),
                  );
                  _loadFieldsData(); // Reload fields to display updated city/district if changed
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  // Quick Add Field Dialog from Profile Screen
  void _showAddFieldDialog() {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: _currentUser['city'] ?? 'Konya');
    final districtCtrl = TextEditingController(text: _currentUser['district'] ?? 'Karatay');
    
    String selectedSoil = 'Tınlı';
    int selectedCropId = 1; // Tomato by default

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Tarla Adı (örn: Zeytinlik Altı)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: areaCtrl,
                      decoration: const InputDecoration(labelText: 'Alan (Dekar)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'Şehir', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: districtCtrl,
                      decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSoil,
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
                            selectedSoil = val;
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
                        DropdownMenuItem(value: 4, child: Text('Mısır')),
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
                    final name = nameCtrl.text.trim();
                    final area = double.tryParse(areaCtrl.text.trim()) ?? 10.0;
                    final city = cityCtrl.text.trim();
                    final district = districtCtrl.text.trim();

                    if (name.isNotEmpty) {
                      final db = DatabaseHelper.instance;
                      // 1. Insert field
                      final fid = await db.insertField({
                        'user_id': _currentUser['id'],
                        'field_name': name,
                        'province': city,
                        'district': district,
                        'area_m2': area * 1000, // Dekar to m2
                        'soil_type': selectedSoil,
                        'irrigation_type': 'Damlama',
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });

                      // 2. Insert field_crop active relation
                      await db.insertFieldCrop({
                        'field_id': fid,
                        'crop_id': selectedCropId,
                        'planting_date': DateTime.now().toIso8601String().split('T')[0],
                        'growth_stage': 'Gelişme Dönemi',
                        'is_active': 1,
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yeni tarla başarıyla eklendi!'), backgroundColor: Color(0xFF4A7C59)),
                      );
                      _loadFieldsData();
                    }
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Get field image based on crop type
  String _getFieldImage(String cropName) {
    switch (cropName.toLowerCase()) {
      case 'domates':
        return 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&q=80&w=200';
      case 'patates':
        return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&q=80&w=200';
      case 'biber':
        return 'https://images.unsplash.com/photo-1592417817098-8f3d6eb19675?auto=format&fit=crop&q=80&w=200';
      case 'mısır':
        return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&q=80&w=200';
      default:
        return 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&q=80&w=200';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalHectares = _userFields.fold(0.0, (sum, f) => sum + (((f['area_m2'] as num?)?.toDouble() ?? 0.0) / 10000.0));
    final double totalDekars = totalHectares * 10;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Profil ve Ayarlar',
            style: GoogleFonts.literata(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
          ),
          const SizedBox(height: 16),

          // 1. User Profile Hero Section with Gold Hour mesh styling
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4A7C59).withOpacity(0.15)),
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F6EC), Color(0xFFFAF2DF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E3230).withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Profile Image Frame
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://images.unsplash.com/photo-1595974482597-4b8da8879bc5?auto=format&fit=crop&q=80&w=200',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFC8E8D0),
                            child: const Icon(Icons.person, size: 40, color: Color(0xFF4A7C59)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser['name'] ?? 'Üretici',
                            style: GoogleFonts.literata(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentUser['role'] ?? 'Mühendis Çiftçi',
                            style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.mail_outline, size: 14, color: Color(0xFF6B6358)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _currentUser['email'] ?? '',
                                  style: GoogleFonts.nunitoSans(fontSize: 12, color: const Color(0xFF6B6358)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF6B6358)),
                              const SizedBox(width: 6),
                              Text(
                                _currentUser['phone'] != null && _currentUser['phone'].toString().isNotEmpty
                                    ? _currentUser['phone']
                                    : '+90 (555) 000 00 00',
                                style: GoogleFonts.nunitoSans(fontSize: 12, color: const Color(0xFF6B6358)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A7C59),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showEditProfileDialog,
                    child: Text('Profili Düzenle', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. My Fields Bento Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kayıtlı Arazilerim',
                style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
              ),
              TextButton.icon(
                onPressed: _showAddFieldDialog,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF4A7C59)),
                label: Text('Yeni Ekle', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59))),
              )
            ],
          ),
          const SizedBox(height: 8),
          
          _loadingFields
              ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
              : _userFields.isEmpty
                  ? Card(
                      color: Colors.white.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Henüz tescilli bir araziniz bulunmuyor. Üstteki "Yeni Ekle" butonuna basarak ilk tarlanızı oluşturabilirsiniz.',
                          style: GoogleFonts.nunitoSans(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _userFields.length,
                      itemBuilder: (context, index) {
                        final field = _userFields[index];
                        final fid = field['id'] as int;
                        final activeCrop = _fieldCrops[fid];
                        final cropName = activeCrop != null ? activeCrop['name'] ?? 'Ürün' : 'Ekili Ürün';
                        final double sizeDekar = ((field['area_m2'] as num?)?.toDouble() ?? 0.0) / 1000.0;
                        final String img = _getFieldImage(cropName);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC4C8BC).withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF2E3230).withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
                            ]
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  img,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFFE8F6EC),
                                    child: const Icon(Icons.wb_sunny, color: Color(0xFF4A7C59)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      field['field_name'] ?? 'İsimsiz Tarla',
                                      style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF2E3230)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${field['province']}, ${field['district']} • ${sizeDekar.toStringAsFixed(1)} Dekar',
                                      style: GoogleFonts.nunitoSans(fontSize: 12, color: const Color(0xFF6B6358)),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F6EC),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            cropName.toUpperCase(),
                                            style: GoogleFonts.nunitoSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF2A6038)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAE6DE),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            (field['soil_type'] ?? 'Tınlı').toString().toUpperCase(),
                                            style: GoogleFonts.nunitoSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF6B6358)),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        );
                      },
                    ),
          const SizedBox(height: 20),

          // 3. Language Card
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language, color: Color(0xFF705C30)),
                      const SizedBox(width: 8),
                      Text(
                        'Dil Seçeneği (Language)',
                        style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLanguage = val;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dil tercihi güncellendi: ${val.toUpperCase()}')),
                        );
                      }
                    },
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Account Settings Card (Stitch mock options)
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_applications, color: Color(0xFF4A7C59)),
                      const SizedBox(width: 8),
                      Text(
                        'Hesap ve Sistem Ayarları',
                        style: GoogleFonts.literata(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Security
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Güvenlik ve Şifre'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      _showDialogInfo('Güvenlik ve Şifre', 'Şifrenizi ve iki adımlı doğrulama ayarlarınızı buradan yapılandırabilirsiniz. (Şu an SQLite korumalıdır)');
                    },
                  ),
                  const Divider(height: 1),
                  
                  // Notifications
                  ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: const Text('Anlık Bildirimler'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      _showDialogInfo('Anlık Bildirimler', 'Hastalık uyarıları, hava durumu değişimleri ve sulama önerisi bildirimlerini buradan yönetebilirsiniz.');
                    },
                  ),
                  const Divider(height: 1),
                  
                  // Subscription
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Abonelik Planı'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      _showDialogInfo('Abonelik Planı', 'Mevcut Planınız: Tarla Gözcüsü Proaktif Tarım Planı (Ücretsiz Lisans). Aylık hava durumu ve CNN teşhis limiti sınırsızdır.');
                    },
                  ),
                  const Divider(height: 1),

                  // Developer API Server config in-list
                  ExpansionTile(
                    leading: const Icon(Icons.dns_outlined, color: Colors.blueGrey),
                    title: const Text('FastAPI Sunucu Bağlantısı'),
                    subtitle: Text(
                      'Şu anki: ${_urlController.text}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _urlController,
                              decoration: const InputDecoration(
                                labelText: 'Backend API URL',
                                border: OutlineInputBorder(),
                                hintText: 'http://10.0.2.2:8000',
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A7C59), foregroundColor: Colors.white),
                              onPressed: _saveUrlSetting,
                              child: const Text('API Adresini Kaydet'),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Atmospheric Ecological Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4A7C59),
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: const NetworkImage('https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&q=80&w=600'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(const Color(0xFF4A7C59).withOpacity(0.85), BlendMode.srcOver),
              )
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.eco, color: Color(0xFFC8E8D0), size: 36),
                const SizedBox(height: 8),
                Text(
                  'Geleceğe Kök Salıyoruz',
                  style: GoogleFonts.literata(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu sezon kayıtlı tarlalarınızda toplam ${totalDekars.toStringAsFixed(1)} dekar alanı korudunuz. Yapay zeka destekli analizlerimiz su tüketimini ortalama %12 oranında azaltmaya yardımcı oldu.',
                  style: GoogleFonts.nunitoSans(fontSize: 13, color: const Color(0xFFE8F6EC), height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4A7C59),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  onPressed: () {
                    _showDialogInfo(
                      'Sürdürülebilirlik Etki Raporu',
                      '• Korunan Toprak Alanı: ${totalDekars.toStringAsFixed(1)} Dekar\n'
                      '• Tahmini Su Tasarrufu: ${(totalDekars * 140).toStringAsFixed(0)} Litre\n'
                      '• Karbon Azaltım Etkisi: %4.2\n'
                      '• Önlenen Potansiyel Hastalık: 3 Vak\'a\n\n'
                      'Tarla Gözcüsü proaktif tarım modellerini kullandığınız için teşekkür ederiz!'
                    );
                  },
                  child: Text('Etki Raporunu Görüntüle', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB83230),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout),
            label: Text('Oturumu Kapat', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDialogInfo(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59))),
          content: Text(content, style: GoogleFonts.nunitoSans(height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat', style: TextStyle(color: Color(0xFF4A7C59), fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }
}

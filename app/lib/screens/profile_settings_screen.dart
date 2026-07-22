import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../utils/turkey_cities.dart';
import 'login_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUrlUpdated;

  const ProfileSettingsScreen({super.key, required this.user, required this.onUrlUpdated});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late Map<String, dynamic> _currentUser;
  
  List<Map<String, dynamic>> _userFields = [];
  Map<int, Map<String, dynamic>> _fieldCrops = {};
  bool _loadingFields = true;

  // Notification Toggles
  bool _notifyDiseases = true;
  bool _notifyIrrigation = true;
  bool _notifyWeather = true;
  bool _notifyAiTips = true;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
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
      }
    } catch (e) {
      print("Fields load error: $e");
      if (mounted) {
        setState(() {
          _loadingFields = false;
        });
      }
    }
  }

  // Pick profile photo from gallery or camera
  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      final updatedUser = Map<String, dynamic>.from(_currentUser);
      updatedUser['image_path'] = picked.path;

      await DatabaseHelper.instance.updateUser(updatedUser);
      setState(() {
        _currentUser = updatedUser;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafınız başarıyla güncellendi!'),
            backgroundColor: Color(0xFF4A7C59),
          ),
        );
      }
    }
  }

  // Edit Profile Info Dialog
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _currentUser['name'] ?? '');
    final phoneCtrl = TextEditingController(text: _currentUser['phone'] ?? '');
    String? selectedCity = _currentUser['city'] != null && _currentUser['city'].toString().isNotEmpty
        ? _currentUser['city']
        : 'Konya';
    String? selectedDistrict = _currentUser['district'] != null && _currentUser['district'].toString().isNotEmpty
        ? _currentUser['district']
        : 'Karatay';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final districts = selectedCity != null ? TurkeyCities.getDistrictsForCity(selectedCity!) : <String>[];
            if (selectedDistrict != null && !districts.contains(selectedDistrict)) {
              selectedDistrict = districts.isNotEmpty ? districts.first : null;
            }

            final avatarPath = _currentUser['image_path']?.toString();

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
                    GestureDetector(
                      onTap: () async {
                        await _pickProfilePhoto();
                        setDialogState(() {});
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          ClipOval(
                            child: avatarPath != null && avatarPath.isNotEmpty && File(avatarPath).existsSync()
                                ? Image.file(
                                    File(avatarPath),
                                    key: ValueKey(avatarPath),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    'https://images.unsplash.com/photo-1595974482597-4b8da8879bc5?auto=format&fit=crop&q=80&w=200',
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFF4A7C59), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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

                    if (name.isNotEmpty) {
                      final updatedUser = Map<String, dynamic>.from(_currentUser);
                      updatedUser['name'] = name;
                      updatedUser['phone'] = phone;
                      updatedUser['city'] = selectedCity ?? 'Konya';
                      updatedUser['district'] = selectedDistrict ?? 'Karatay';

                      await DatabaseHelper.instance.updateUser(updatedUser);
                      
                      setState(() {
                        _currentUser = updatedUser;
                      });
                      
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil bilgileri güncellendi!'), backgroundColor: Color(0xFF4A7C59)),
                      );
                      _loadFieldsData();
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

  // Change Password Dialog
  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Güvenlik ve Şifre Güncelleme',
            style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mevcut Şifre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Yeni Şifre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Yeni Şifre Tekrar', border: OutlineInputBorder()),
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
                final current = currentPassCtrl.text;
                final newPass = newPassCtrl.text;
                final confirmPass = confirmPassCtrl.text;

                final realPass = _currentUser['password'] ?? '';
                if (current != realPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mevcut şifreniz hatalı!'), backgroundColor: Color(0xFFB83230)),
                  );
                  return;
                }
                if (newPass.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeni şifreniz en az 4 karakter olmalıdır.'), backgroundColor: Color(0xFFB83230)),
                  );
                  return;
                }
                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeni şifreler uyuşmuyor!'), backgroundColor: Color(0xFFB83230)),
                  );
                  return;
                }

                final userId = _currentUser['id'] as int?;
                if (userId != null) {
                  await DatabaseHelper.instance.updateUserPassword(userId, newPass);
                  setState(() {
                    _currentUser['password'] = newPass;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Şifreniz başarıyla güncellendi!'), backgroundColor: Color(0xFF4A7C59)),
                  );
                }
              },
              child: const Text('Şifreyi Güncelle'),
            ),
          ],
        );
      },
    );
  }

  // Quick Add Field Dialog
  void _showAddFieldDialog() {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    String? selectedCity = _currentUser['city'] != null && _currentUser['city'].toString().isNotEmpty
        ? _currentUser['city']
        : 'Konya';
    String? selectedDistrict = _currentUser['district'] != null && _currentUser['district'].toString().isNotEmpty
        ? _currentUser['district']
        : 'Karatay';
    
    String selectedSoil = 'Tınlı';
    int selectedCropId = 1; // Tomato by default

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

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lütfen tarla adını giriniz.'), backgroundColor: Color(0xFFB83230)),
                      );
                      return;
                    }

                    try {
                      final db = DatabaseHelper.instance;
                      final userId = (_currentUser['id'] ?? _currentUser['user_id'] ?? 1) as int;

                      final fid = await db.insertField({
                        'name': name,
                        'user_id': userId,
                        'city': selectedCity ?? 'Konya',
                        'district': selectedDistrict ?? 'Karatay',
                        'area': area,
                        'soil_type': selectedSoil,
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
                      _loadFieldsData();
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

  // Field Action Dialog (Edit / Delete)
  void _showFieldOptionsDialog(Map<String, dynamic> field, Map<String, dynamic>? activeCrop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  field['name'] ?? field['field_name'] ?? 'Tarla İşlemleri',
                  style: GoogleFonts.literata(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2E3230)),
                ),
                const SizedBox(height: 8),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF4A7C59)),
                  title: const Text('Araziyi Düzenle'),
                  subtitle: const Text('İsim, alan, şehir, ilçe veya ürün bilgisini güncelle'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditFieldDialog(field, activeCrop);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFB83230)),
                  title: const Text('Araziyi Sil', style: TextStyle(color: Color(0xFFB83230), fontWeight: FontWeight.bold)),
                  subtitle: const Text('Bu tarlayı ve bağlı tüm kayıtları siler'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteField(field);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Edit Existing Field Dialog
  void _showEditFieldDialog(Map<String, dynamic> field, Map<String, dynamic>? activeCrop) {
    final nameCtrl = TextEditingController(text: field['name'] ?? field['field_name'] ?? '');
    final double initialArea = (field['area'] as num?)?.toDouble() ?? (((field['area_m2'] as num?)?.toDouble() ?? 0.0) / 1000.0);
    final areaCtrl = TextEditingController(text: initialArea.toStringAsFixed(1));

    String? selectedCity = field['city'] ?? field['province'] ?? 'Konya';
    String? selectedDistrict = field['district'] ?? 'Karatay';
    String selectedSoil = field['soil_type'] ?? 'Tınlı';
    int selectedCropId = activeCrop != null ? (activeCrop['id'] as int? ?? 1) : 1;

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
                'Araziyi Düzenle',
                style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Tarla Adı', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: areaCtrl,
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
                    final area = double.tryParse(areaCtrl.text.trim()) ?? initialArea;
                    final fid = field['id'] as int;

                    if (name.isNotEmpty && selectedCity != null && selectedDistrict != null) {
                      final updatedField = Map<String, dynamic>.from(field);
                      updatedField['name'] = name;
                      updatedField['area'] = area;
                      updatedField['city'] = selectedCity;
                      updatedField['district'] = selectedDistrict;
                      updatedField['soil_type'] = selectedSoil;

                      final db = DatabaseHelper.instance;
                      await db.updateField(updatedField);
                      await db.updateFieldCropRelation(fid, selectedCropId);

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tarla bilgileri başarıyla güncellendi!'), backgroundColor: Color(0xFF4A7C59)),
                      );
                      _loadFieldsData();
                    }
                  },
                  child: const Text('Güncelle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete Confirmation Dialog
  void _confirmDeleteField(Map<String, dynamic> field) {
    final fid = field['id'] as int;
    final name = field['name'] ?? field['field_name'] ?? 'Tarla';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Araziyi Sil', style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFFB83230))),
          content: Text(
            '"$name" tarlasını ve bağlı tüm geçmiş sulama, hava durumu ve teşhis kayıtlarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
            style: GoogleFonts.nunitoSans(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB83230), foregroundColor: Colors.white),
              onPressed: () async {
                await DatabaseHelper.instance.deleteField(fid);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$name" tarlası başarıyla silindi.'), backgroundColor: const Color(0xFFB83230)),
                );
                _loadFieldsData();
              },
              child: const Text('Evet, Sil'),
            )
          ],
        );
      },
    );
  }

  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Anlık Bildirim Tercihleri',
                style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      activeThumbColor: const Color(0xFF4A7C59),
                      title: Text('🦠 Hastalık & Salgın Uyarıları', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Bölgesel hastalık tespiti ve proaktif sprey uyarısı', style: GoogleFonts.nunitoSans(fontSize: 12)),
                      value: _notifyDiseases,
                      onChanged: (val) {
                        setDialogState(() => _notifyDiseases = val);
                        setState(() => _notifyDiseases = val);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFF4A7C59),
                      title: Text('💧 Akıllı Sulama Hatırlatıcıları', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Toprak nem düşüşü ve optimal sulama vakti bildirimi', style: GoogleFonts.nunitoSans(fontSize: 12)),
                      value: _notifyIrrigation,
                      onChanged: (val) {
                        setDialogState(() => _notifyIrrigation = val);
                        setState(() => _notifyIrrigation = val);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFF4A7C59),
                      title: Text('⚡ Don & Aşırı Hava Olayı Uyarısı', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Gece sıcaklık düşüşü, fırtına ve yağış ihtimali', style: GoogleFonts.nunitoSans(fontSize: 12)),
                      value: _notifyWeather,
                      onChanged: (val) {
                        setDialogState(() => _notifyWeather = val);
                        setState(() => _notifyWeather = val);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      activeThumbColor: const Color(0xFF4A7C59),
                      title: Text('🤖 Terra AI İpuçları', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Haftalık ürün bakımı, gübreleme ve verim tavsiyeleri', style: GoogleFonts.nunitoSans(fontSize: 12)),
                      value: _notifyAiTips,
                      onChanged: (val) {
                        setDialogState(() => _notifyAiTips = val);
                        setState(() => _notifyAiTips = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A7C59), foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bildirim tercihleri güncellendi!'), backgroundColor: Color(0xFF4A7C59)),
                    );
                  },
                  child: const Text('Kaydet ve Kapat'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showDialogInfo(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFF4A7C59))),
          content: Text(content, style: GoogleFonts.nunitoSans()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam', style: TextStyle(color: Color(0xFF4A7C59))),
            ),
          ],
        );
      },
    );
  }

  String _getFieldImage(String cropName) {
    final name = cropName.toLowerCase();
    if (name.contains('domates')) {
      return 'https://images.unsplash.com/photo-1592841200221-a6898f307baa?auto=format&fit=crop&q=80&w=300';
    } else if (name.contains('patates')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&q=80&w=300';
    } else if (name.contains('biber')) {
      return 'https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?auto=format&fit=crop&q=80&w=300';
    }
    return 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&q=80&w=300';
  }

  @override
  Widget build(BuildContext context) {
    final userImgPath = _currentUser['image_path']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. User Header Bento Card
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF4A7C59), width: 2),
                              ),
                              child: ClipOval(
                                child: userImgPath != null && userImgPath.isNotEmpty && File(userImgPath).existsSync()
                                    ? Image.file(
                                        File(userImgPath),
                                        key: ValueKey(userImgPath),
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        'https://images.unsplash.com/photo-1595974482597-4b8da8879bc5?auto=format&fit=crop&q=80&w=200',
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 76,
                                          height: 76,
                                          color: const Color(0xFFC8E8D0),
                                          child: const Icon(Icons.person, size: 40, color: Color(0xFF4A7C59)),
                                        ),
                                      ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: Color(0xFF4A7C59), shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            )
                          ],
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
                                const Icon(Icons.location_city_outlined, size: 14, color: Color(0xFF6B6358)),
                                const SizedBox(width: 6),
                                Text(
                                  '${_currentUser['city'] ?? 'Konya'} / ${_currentUser['district'] ?? 'Karatay'}',
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
                        final double sizeDekar = (field['area'] as num?)?.toDouble() ?? (((field['area_m2'] as num?)?.toDouble() ?? 0.0) / 1000.0);
                        final String img = _getFieldImage(cropName);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showFieldOptionsDialog(field, activeCrop),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
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
                                          field['name'] ?? field['field_name'] ?? 'İsimsiz Tarla',
                                          style: GoogleFonts.literata(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF2E3230)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${field['city'] ?? field['province'] ?? 'Konya'}, ${field['district']} • ${sizeDekar.toStringAsFixed(1)} Dekar',
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
                                  const Icon(Icons.more_vert, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          const SizedBox(height: 24),

          // 3. Account Settings Card
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
                  
                  // Security & Password
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: Color(0xFF4A7C59)),
                    title: const Text('Güvenlik ve Şifre'),
                    subtitle: const Text('Şifrenizi ve oturum bilgilerinizi güncelleyin'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1),
                  
                  // Notifications
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF4A7C59)),
                    title: const Text('Anlık Bildirim Tercihleri'),
                    subtitle: const Text('Hastalık, sulama ve hava durumu uyarıları'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _showNotificationSettingsDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFFFDAD8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0.5,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: const Icon(Icons.logout, color: Color(0xFFB83230)),
              title: Text(
                'Çıkış Yap',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: const Color(0xFFB83230), fontSize: 16),
              ),
              subtitle: Text(
                'Hesabınızdan güvenli şekilde çıkış yapın',
                style: GoogleFonts.nunitoSans(fontSize: 12, color: const Color(0xFF690005)),
              ),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFB83230)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Çıkış Yap', style: GoogleFonts.literata(fontWeight: FontWeight.bold, color: const Color(0xFFB83230))),
                    content: Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?', style: GoogleFonts.nunitoSans()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB83230), foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text('Çıkış Yap'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

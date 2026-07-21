import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tarla_gozcusu.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
    );

    // Auto migrate columns if missing on existing databases
    try {
      await db.execute('ALTER TABLE users ADD COLUMN image_path TEXT;');
    } catch (_) {}

    return db;
  }

  Future<void> _createDB(Database db, int version) async {
    const textType = 'TEXT';
    const integerType = 'INTEGER';
    const realType = 'REAL';

    // 1. users Table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name $textType NOT NULL,
        email $textType UNIQUE NOT NULL,
        password $textType NOT NULL,
        phone $textType,
        role $textType,
        city $textType,
        district $textType,
        image_path $textType,
        created_at $textType,
        updated_at $textType
      )
    ''');

    // 2. region_climate Table
    await db.execute('''
      CREATE TABLE region_climate (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        avg_temps $textType,
        avg_precips $textType,
        region_coords $textType
      )
    ''');

    // 3. fields Table
    await db.execute('''
      CREATE TABLE fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name $textType NOT NULL,
        user_id $integerType NOT NULL,
        region_climate_id $integerType,
        city $textType,
        district $textType,
        latitude $realType,
        longitude $realType,
        area $realType,
        soil_type $textType,
        irrigation_type $textType,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 4. crops Table
    await db.execute('''
      CREATE TABLE crops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name $textType NOT NULL,
        scientific_name $textType,
        root_depth_m $realType,
        suggested_npk $textType,
        npk_description $textType,
        water_need $textType,
        growth_duration $integerType,
        optimum_temp_range $textType,
        optimum_moisture_range_pct $textType,
        suggested_ph_range $textType,
        irrigation_notes $textType,
        fertilization_notes $textType,
        common_diseases $textType
      )
    ''');

    // 5. field_crops Table
    await db.execute('''
      CREATE TABLE field_crops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id $integerType NOT NULL,
        crop_id $integerType NOT NULL,
        planting_date $textType,
        expected_harvest_date $textType,
        growth_stage $textType,
        is_active $integerType DEFAULT 1,
        FOREIGN KEY (field_id) REFERENCES fields (id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops (id) ON DELETE CASCADE
      )
    ''');

    // 6. weather_records Table
    await db.execute('''
      CREATE TABLE weather_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id $integerType NOT NULL,
        temperature $realType,
        humidity $realType,
        wind_speed $realType,
        precipitation $realType,
        provider $textType,
        recorded_at $textType,
        FOREIGN KEY (field_id) REFERENCES fields (id) ON DELETE CASCADE
      )
    ''');

    // 7. sensor_records Table
    await db.execute('''
      CREATE TABLE sensor_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id $integerType NOT NULL,
        soil_moisture_pct $realType,
        soil_temp_c $realType,
        source $textType,
        raw_data_json $textType,
        measured_at $textType,
        FOREIGN KEY (field_id) REFERENCES fields (id) ON DELETE CASCADE
      )
    ''');

    // 8. disease_detection_records Table
    await db.execute('''
      CREATE TABLE disease_detection_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id $integerType NOT NULL,
        crop_id $integerType NOT NULL,
        image_path $textType,
        predicted_disease $textType,
        confidence_score $realType,
        ai_recommendation $textType,
        detected_at $textType,
        FOREIGN KEY (field_id) REFERENCES fields (id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops (id) ON DELETE CASCADE
      )
    ''');

    // 9. ai_recommendations Table
    await db.execute('''
      CREATE TABLE ai_recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id $integerType NOT NULL,
        recommendation_type $textType,
        recommendation_text $textType,
        created_at $textType,
        FOREIGN KEY (field_id) REFERENCES fields (id) ON DELETE CASCADE
      )
    ''');

    // 10. anonymous_risk_logs Table
    await db.execute('''
      CREATE TABLE anonymous_risk_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grid_code $textType,
        region_name $textType,
        city $textType,
        district $textType,
        crop_name $textType,
        risk_type $textType,
        detected_disease $textType,
        risk_level $textType,
        source $textType,
        detected_at $textType
      )
    ''');

    // Seed Crops Table
    await _seedCrops(db);
  }

  Future<void> _seedCrops(Database db) async {
    final cropsList = [
      {
        'name': 'Domates',
        'scientific_name': 'Solanum lycopersicum',
        'root_depth_m': 0.6,
        'suggested_npk': '5-10-15',
        'npk_description': 'Meyve bağlama evresinde yüksek potasyum ve fosfor ihtiyacı vardır.',
        'water_need': 'Orta',
        'growth_duration': 90,
        'optimum_temp_range': '22-28 C',
        'optimum_moisture_range_pct': '50-70 %',
        'suggested_ph_range': '6.0-6.8',
        'irrigation_notes': 'Kök çürüklüğünü önlemek için damlama sulama önerilir. Toprak üstü ıslatılmamalıdır.',
        'fertilization_notes': 'Gelişimin erken evrelerinde azot, meyvelenmede potasyum takviyesi yapın.',
        'common_diseases': 'Mildiyö (Geç Yanıklık), Erken Yanıklık, Yaprak Küfü, Bakteriyel Leke'
      },
      {
        'name': 'Patates',
        'scientific_name': 'Solanum tuberosum',
        'root_depth_m': 0.4,
        'suggested_npk': '10-15-20',
        'npk_description': 'Yumru gelişiminde potasyum hayati önem taşır.',
        'water_need': 'Yüksek',
        'growth_duration': 120,
        'optimum_temp_range': '15-22 C',
        'optimum_moisture_range_pct': '60-80 %',
        'suggested_ph_range': '5.5-6.5',
        'irrigation_notes': 'Düzenli nem yumru kalitesini artırır. Hasattan 2 hafta önce sulama kesilir.',
        'fertilization_notes': 'Toprak analizine göre dikim öncesi taban gübresi uygulayın.',
        'common_diseases': 'Erken Yanıklık, Geç Yanıklık, Kara Bacak, Kuruluk'
      },
      {
        'name': 'Biber',
        'scientific_name': 'Capsicum annuum',
        'root_depth_m': 0.5,
        'suggested_npk': '15-15-15',
        'npk_description': 'Dengeli NPK oranı ve iz elementler gelişimi hızlandırır.',
        'water_need': 'Düşük-Orta',
        'growth_duration': 80,
        'optimum_temp_range': '20-30 C',
        'optimum_moisture_range_pct': '50-65 %',
        'suggested_ph_range': '6.0-7.0',
        'irrigation_notes': 'Çiçeklenme döneminde aşırı sulama çiçek dökümüne neden olabilir.',
        'fertilization_notes': 'Magnezyum ve Kalsiyum eksikliği çiçek burnu çürüklüğüne yol açar.',
        'common_diseases': 'Bakteriyel Leke, Külleme, Phytophthora Kök Çürüklüğü'
      }
    ];

    for (var crop in cropsList) {
      await db.insert('crops', crop);
    }
  }

  // --- CRUD Operations for Users ---
  Future<Map<String, dynamic>?> registerUser(String name, String email, String password) async {
    final db = await instance.database;
    final user = {
      'name': name,
      'email': email,
      'password': password, // In production, hash this.
      'phone': '',
      'role': 'Üretici',
      'city': 'Konya',
      'district': 'Karatay',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final id = await db.insert('users', user);
      final registered = Map<String, dynamic>.from(user);
      registered['id'] = id;
      return registered;
    } catch (e) {
      print("User registration failed: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    final Map<String, dynamic> cleanUser = {};
    if (user.containsKey('name')) cleanUser['name'] = user['name'];
    if (user.containsKey('email')) cleanUser['email'] = user['email'];
    if (user.containsKey('password')) cleanUser['password'] = user['password'];
    if (user.containsKey('phone')) cleanUser['phone'] = user['phone'];
    if (user.containsKey('role')) cleanUser['role'] = user['role'];
    if (user.containsKey('city')) cleanUser['city'] = user['city'];
    if (user.containsKey('district')) cleanUser['district'] = user['district'];
    if (user.containsKey('image_path')) cleanUser['image_path'] = user['image_path'];
    cleanUser['updated_at'] = DateTime.now().toIso8601String();

    return await db.update(
      'users',
      cleanUser,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  // --- CRUD Operations for Fields ---
  Future<int> insertField(Map<String, dynamic> field) async {
    final db = await instance.database;
    final Map<String, dynamic> cleanField = {
      'name': field['name'] ?? field['field_name'] ?? 'İsimsiz Tarla',
      'user_id': field['user_id'] ?? 1,
      'city': field['city'] ?? field['province'] ?? 'Konya',
      'district': field['district'] ?? 'Karatay',
      'latitude': (field['latitude'] as num?)?.toDouble() ?? 37.87,
      'longitude': (field['longitude'] as num?)?.toDouble() ?? 32.49,
      'area': (field['area'] as num?)?.toDouble() ?? 10.0,
      'soil_type': field['soil_type'] ?? 'Tınlı',
      'irrigation_type': field['irrigation_type'] ?? 'Damlama',
    };
    return await db.insert('fields', cleanField);
  }

  Future<List<Map<String, dynamic>>> getFieldsForUser(int userId) async {
    final db = await instance.database;
    return await db.query('fields', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> updateField(Map<String, dynamic> field) async {
    final db = await instance.database;
    final Map<String, dynamic> cleanField = {
      'name': field['name'] ?? field['field_name'] ?? 'İsimsiz Tarla',
      'city': field['city'] ?? field['province'] ?? 'Konya',
      'district': field['district'] ?? 'Karatay',
      'area': (field['area'] as num?)?.toDouble() ?? 10.0,
      'soil_type': field['soil_type'] ?? 'Tınlı',
      'irrigation_type': field['irrigation_type'] ?? 'Damlama',
    };
    return await db.update(
      'fields',
      cleanField,
      where: 'id = ?',
      whereArgs: [field['id']],
    );
  }

  Future<int> updateFieldCropRelation(int fieldId, int cropId) async {
    final db = await instance.database;
    await db.delete('field_crops', where: 'field_id = ?', whereArgs: [fieldId]);
    return await db.insert('field_crops', {
      'field_id': fieldId,
      'crop_id': cropId,
      'planting_date': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'growth_stage': 'Vejetatif',
      'is_active': 1,
    });
  }

  Future<int> deleteField(int fieldId) async {
    final db = await instance.database;
    await db.delete('field_crops', where: 'field_id = ?', whereArgs: [fieldId]);
    await db.delete('sensor_records', where: 'field_id = ?', whereArgs: [fieldId]);
    await db.delete('weather_records', where: 'field_id = ?', whereArgs: [fieldId]);
    await db.delete('disease_detection_records', where: 'field_id = ?', whereArgs: [fieldId]);
    await db.delete('ai_recommendations', where: 'field_id = ?', whereArgs: [fieldId]);
    return await db.delete('fields', where: 'id = ?', whereArgs: [fieldId]);
  }

  Future<int> updateUserPassword(int userId, String newPassword) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {
        'password': newPassword,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<Map<String, dynamic>>> getCrops() async {
    final db = await instance.database;
    return await db.query('crops');
  }

  // --- Field Crop Relation ---
  Future<int> insertFieldCrop(Map<String, dynamic> fieldCrop) async {
    final db = await instance.database;
    return await db.insert('field_crops', fieldCrop);
  }

  Future<Map<String, dynamic>?> getActiveCropForField(int fieldId) async {
    final db = await instance.database;
    final results = await db.rawQuery('''
      SELECT c.*, fc.planting_date, fc.expected_harvest_date, fc.growth_stage 
      FROM crops c
      JOIN field_crops fc ON c.id = fc.crop_id
      WHERE fc.field_id = ? AND fc.is_active = 1
      LIMIT 1
    ''', [fieldId]);
    
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // --- Weather Records ---
  Future<int> insertWeatherRecord(Map<String, dynamic> record) async {
    final db = await instance.database;
    return await db.insert('weather_records', record);
  }

  Future<List<Map<String, dynamic>>> getWeatherForField(int fieldId) async {
    final db = await instance.database;
    return await db.query('weather_records', where: 'field_id = ?', orderBy: 'recorded_at DESC', limit: 10);
  }

  // --- Sensor Records ---
  Future<int> insertSensorRecord(Map<String, dynamic> record) async {
    final db = await instance.database;
    return await db.insert('sensor_records', record);
  }

  Future<List<Map<String, dynamic>>> getSensorsForField(int fieldId) async {
    final db = await instance.database;
    return await db.query('sensor_records', where: 'field_id = ?', orderBy: 'measured_at DESC', limit: 20);
  }

  // --- Disease Records ---
  Future<int> insertDiseaseRecord(Map<String, dynamic> record) async {
    final db = await instance.database;
    return await db.insert('disease_detection_records', record);
  }

  Future<List<Map<String, dynamic>>> getDiseaseRecordsForField(int fieldId) async {
    final db = await instance.database;
    return await db.query('disease_detection_records', where: 'field_id = ?', orderBy: 'detected_at DESC');
  }

  // --- AI Recommendations ---
  Future<int> insertAIRecommendation(Map<String, dynamic> rec) async {
    final db = await instance.database;
    return await db.insert('ai_recommendations', rec);
  }

  Future<Map<String, dynamic>?> getLatestRecommendation(int fieldId) async {
    final db = await instance.database;
    final results = await db.query('ai_recommendations', where: 'field_id = ?', orderBy: 'created_at DESC', limit: 1);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
}

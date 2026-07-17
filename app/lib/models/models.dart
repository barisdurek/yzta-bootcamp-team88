class User {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String role;
  final String city;
  final String district;
  final String? createdAt;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.role = 'Üretici',
    this.city = '',
    this.district = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': role,
      'city': city,
      'district': district,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'Üretici',
      city: map['city'] ?? '',
      district: map['district'] ?? '',
      createdAt: map['created_at'],
    );
  }
}

class Field {
  final int? id;
  final String name;
  final int userId;
  final int? regionClimateId;
  final String city;
  final String district;
  final double latitude;
  final double longitude;
  final double area;
  final String soilType;
  final String irrigationType;

  Field({
    this.id,
    required this.name,
    required this.userId,
    this.regionClimateId,
    required this.city,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.soilType,
    required this.irrigationType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'user_id': userId,
      'region_climate_id': regionClimateId,
      'city': city,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'area': area,
      'soil_type': soilType,
      'irrigation_type': irrigationType,
    };
  }

  factory Field.fromMap(Map<String, dynamic> map) {
    return Field(
      id: map['id'],
      name: map['name'],
      userId: map['user_id'],
      regionClimateId: map['region_climate_id'],
      city: map['city'] ?? '',
      district: map['district'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      area: (map['area'] as num?)?.toDouble() ?? 0.0,
      soilType: map['soil_type'] ?? 'Tınlı',
      irrigationType: map['irrigation_type'] ?? 'Damlama',
    );
  }
}

class Crop {
  final int? id;
  final String name;
  final String scientificName;
  final double rootDepthM;
  final String suggestedNpk;
  final String npkDescription;
  final String waterNeed;
  final int growthDuration;
  final String optimumTempRange;
  final String optimumMoistureRangePct;
  final String suggestedPhRange;
  final String irrigationNotes;
  final String fertilization_notes;
  final String commonDiseases;

  Crop({
    this.id,
    required this.name,
    required this.scientificName,
    required this.rootDepthM,
    required this.suggestedNpk,
    required this.npkDescription,
    required this.waterNeed,
    required this.growthDuration,
    required this.optimumTempRange,
    required this.optimumMoistureRangePct,
    required this.suggestedPhRange,
    required this.irrigationNotes,
    required this.fertilization_notes,
    required this.commonDiseases,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'scientific_name': scientificName,
      'root_depth_m': rootDepthM,
      'suggested_npk': suggestedNpk,
      'npk_description': npkDescription,
      'water_need': waterNeed,
      'growth_duration': growthDuration,
      'optimum_temp_range': optimumTempRange,
      'optimum_moisture_range_pct': optimumMoistureRangePct,
      'suggested_ph_range': suggestedPhRange,
      'irrigation_notes': irrigationNotes,
      'fertilization_notes': fertilization_notes,
      'common_diseases': commonDiseases,
    };
  }

  factory Crop.fromMap(Map<String, dynamic> map) {
    return Crop(
      id: map['id'],
      name: map['name'],
      scientificName: map['scientific_name'] ?? '',
      rootDepthM: (map['root_depth_m'] as num?)?.toDouble() ?? 0.5,
      suggestedNpk: map['suggested_npk'] ?? '',
      npkDescription: map['npk_description'] ?? '',
      waterNeed: map['water_need'] ?? '',
      growthDuration: map['growth_duration'] ?? 100,
      optimumTempRange: map['optimum_temp_range'] ?? '',
      optimumMoistureRangePct: map['optimum_moisture_range_pct'] ?? '',
      suggestedPhRange: map['suggested_ph_range'] ?? '',
      irrigationNotes: map['irrigation_notes'] ?? '',
      fertilization_notes: map['fertilization_notes'] ?? '',
      commonDiseases: map['common_diseases'] ?? '',
    );
  }
}

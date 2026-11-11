/// Delivery platforms the backend accepts. [wireValue] is what is stored and
/// sent; [label] is for display only.
enum DeliveryPlatform {
  zepto('zepto', 'Zepto'),
  blinkit('blinkit', 'Blinkit'),
  swiggyInstamart('swiggy_instamart', 'Swiggy Instamart'),
  other('other', 'Other');

  const DeliveryPlatform(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static DeliveryPlatform? fromWire(Object? value) {
    for (final p in values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}

/// The rider-editable profile fields, as sent to the backend.
class ProfileInput {
  const ProfileInput({
    required this.name,
    required this.phone,
    required this.city,
    required this.platform,
  });

  final String name;
  final String phone;
  final String city;
  final DeliveryPlatform platform;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'city': city,
    'platform': platform.wireValue,
  };

  /// Only the fields that differ from [profile], for a PATCH.
  Map<String, dynamic> changesFrom(WorkerProfile profile) => {
    if (name != profile.name) 'name': name,
    if (phone != profile.phone) 'phone': phone,
    if (city != profile.city) 'city': city,
    if (platform != profile.platform) 'platform': platform.wireValue,
  };
}

/// A worker profile as returned by `GET /api/workers/me`.
class WorkerProfile {
  const WorkerProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.city,
    required this.platform,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String phone;
  final String city;
  final DeliveryPlatform platform;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Throws [FormatException] if [json] is not a valid profile.
  factory WorkerProfile.fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    final name = json['name'];
    final phone = json['phone'];
    final city = json['city'];
    final platform = DeliveryPlatform.fromWire(json['platform']);
    if (uid is! String ||
        name is! String ||
        phone is! String ||
        city is! String ||
        platform == null) {
      throw const FormatException('Invalid worker profile');
    }
    return WorkerProfile(
      uid: uid,
      name: name,
      phone: phone,
      city: city,
      platform: platform,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

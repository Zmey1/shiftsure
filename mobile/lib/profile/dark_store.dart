import 'worker_profile.dart';

/// A dark store as shown to the rider: the store plus the zone the backend
/// resolved for it. Display only; the backend validates every assignment.
class DarkStoreSummary {
  const DarkStoreSummary({
    required this.id,
    required this.name,
    required this.zoneId,
    required this.zoneName,
  });

  final String id;
  final String name;
  final String zoneId;
  final String zoneName;

  /// Throws [FormatException] if [json] is not a store summary.
  factory DarkStoreSummary.fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      final id = json['id'];
      final name = json['name'];
      final zone = json['zone'];
      if (id is String && name is String && zone is Map<String, dynamic>) {
        final zoneId = zone['id'];
        final zoneName = zone['name'];
        if (zoneId is String && zoneName is String) {
          return DarkStoreSummary(
            id: id,
            name: name,
            zoneId: zoneId,
            zoneName: zoneName,
          );
        }
      }
    }
    throw const FormatException('Invalid dark store');
  }
}

/// `GET /api/dark-stores`: the stores the backend will accept for the rider's
/// saved platform and city, from its demonstration catalog.
class DarkStoreListing {
  const DarkStoreListing({
    required this.platform,
    required this.city,
    required this.stores,
    required this.availableCities,
    required this.demo,
  });

  /// The platform and city the backend filtered by (the saved profile).
  final DeliveryPlatform platform;
  final String city;
  final List<DarkStoreSummary> stores;

  /// Catalog cities that have stores on [platform].
  final List<String> availableCities;

  /// True while the catalog is fictional demonstration data.
  final bool demo;

  /// Throws [FormatException] if [json] is not a listing.
  factory DarkStoreListing.fromJson(Map<String, dynamic> json) {
    final platform = DeliveryPlatform.fromWire(json['platform']);
    final city = json['city'];
    final stores = json['stores'];
    final cities = json['available_cities'];
    if (platform == null ||
        city is! String ||
        stores is! List ||
        cities is! List ||
        cities.any((c) => c is! String)) {
      throw const FormatException('Invalid dark-store listing');
    }
    return DarkStoreListing(
      platform: platform,
      city: city,
      stores: [for (final s in stores) DarkStoreSummary.fromJson(s)],
      availableCities: cities.cast<String>(),
      demo: json['demo'] == true,
    );
  }
}

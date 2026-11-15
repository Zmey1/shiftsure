import 'package:flutter_test/flutter_test.dart';
import 'package:shiftsure_rider/profile/dark_store.dart';
import 'package:shiftsure_rider/profile/profile_validators.dart';
import 'package:shiftsure_rider/profile/worker_profile.dart';

void main() {
  test('platform wire values match the backend', () {
    expect(DeliveryPlatform.values.map((p) => p.wireValue), [
      'zepto',
      'blinkit',
      'swiggy_instamart',
      'other',
    ]);
    expect(DeliveryPlatform.fromWire('swiggy_instamart'), isNotNull);
    expect(DeliveryPlatform.fromWire('Zepto'), isNull);
  });

  test('profile JSON parses and rejects malformed data', () {
    final p = WorkerProfile.fromJson({
      'uid': 'u1',
      'name': 'Asha',
      'phone': '9876543210',
      'city': 'Pune',
      'platform': 'other',
      'created_at': '2026-01-01T00:00:00.000Z',
    });
    expect(p.platform, DeliveryPlatform.other);
    expect(p.createdAt, DateTime.utc(2026));
    expect(
      () => WorkerProfile.fromJson({'uid': 'u1', 'platform': 'zepto'}),
      throwsFormatException,
    );
    expect(
      () => WorkerProfile.fromJson({
        'uid': 'u1',
        'name': 'Asha',
        'phone': '9876543210',
        'city': 'Pune',
        'platform': 'uber',
      }),
      throwsFormatException,
    );
  });

  test('dark store is optional on a profile and validated when present', () {
    const base = {
      'uid': 'u1',
      'name': 'Asha',
      'phone': '9876543210',
      'city': 'Pune',
      'platform': 'zepto',
    };
    // PR #10 responses have no dark_store at all.
    expect(WorkerProfile.fromJson(base).darkStore, isNull);
    expect(
      WorkerProfile.fromJson({...base, 'dark_store': null}).darkStore,
      isNull,
    );
    final p = WorkerProfile.fromJson({
      ...base,
      'dark_store': {
        'id': 's1',
        'name': 'Store',
        'zone': {'id': 'z1', 'name': 'Zone'},
      },
    });
    expect(p.darkStore!.zoneId, 'z1');
    expect(p.darkStore!.zoneName, 'Zone');
    expect(
      () => WorkerProfile.fromJson({
        ...base,
        'dark_store': {'id': 's1', 'name': 'Store'},
      }),
      throwsFormatException,
    );
  });

  test('dark-store listing parses and rejects malformed data', () {
    final listing = DarkStoreListing.fromJson({
      'demo': true,
      'platform': 'blinkit',
      'city': 'Pune',
      'stores': [
        {
          'id': 's1',
          'name': 'Store',
          'zone': {'id': 'z1', 'name': 'Zone'},
        },
      ],
      'available_cities': ['Pune'],
    });
    expect(listing.platform, DeliveryPlatform.blinkit);
    expect(listing.stores.single.id, 's1');
    expect(listing.demo, isTrue);
    expect(
      () => DarkStoreListing.fromJson({
        'platform': 'blinkit',
        'city': 'Pune',
        'stores': [],
        'available_cities': [1],
      }),
      throwsFormatException,
    );
  });

  test('validators mirror the backend rules', () {
    expect(validateName("D'Souza-Rao"), isNull);
    expect(validateName('रवि कुमार'), isNull);
    expect(validateName('R'), isNotNull);
    expect(validateName('R2D2'), isNotNull);
    expect(validateName('x' * 81), isNotNull);
    expect(validateCity('New Delhi'), isNull);
    expect(validateCity('x' * 61), isNotNull);
    expect(validatePhone('+91 98765-43210'), isNull);
    expect(validatePhone('5876543210'), isNotNull);
    expect(validatePhone('919876543210'), isNotNull);
    expect(normalizePhone(' +91 98765 43210 '), '9876543210');
    expect(normalizeText('  a   b '), 'a b');
  });
}

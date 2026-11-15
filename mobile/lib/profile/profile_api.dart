import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../auth/auth_service.dart';
import 'dark_store.dart';
import 'worker_profile.dart';

/// The signed-in worker's own profile (`/api/workers/me`).
///
/// The backend assigns the rider role during onboarding. Custom claims only
/// reach the app in a new ID token, so whenever the backend reports
/// `token_refresh_required` this forces a token refresh. That also covers
/// interrupted onboarding: if the app closed before refreshing, the next
/// [fetchMine] does it.
class ProfileApi {
  ProfileApi({required this.api, required this.auth});

  final ApiClient api;
  final AuthService auth;

  static const path = '/api/workers/me';
  static const storesPath = '/api/dark-stores';
  static const darkStorePath = '/api/workers/me/dark-store';

  /// The current profile, or null if the worker has not set one up yet.
  Future<WorkerProfile?> fetchMine() async {
    final Map<String, dynamic> body;
    try {
      body = await api.getJson(path);
    } on ApiException catch (e) {
      if (e.statusCode == 404 && e.code == 'profile_not_found') return null;
      rethrow;
    }
    await _refreshTokenIfRequired(body);
    return _parse(body);
  }

  /// Creates the profile. If one already exists (e.g. created on another
  /// device or by an earlier attempt whose response was lost), returns it.
  Future<WorkerProfile> create(ProfileInput input) async {
    final Map<String, dynamic> body;
    try {
      body = await api.postJson(path, input.toJson());
    } on ApiException catch (e) {
      if (e.statusCode == 409 && e.code == 'profile_exists') {
        final existing = await fetchMine();
        if (existing != null) return existing;
      }
      rethrow;
    }
    await _refreshTokenIfRequired(body);
    return _parse(body);
  }

  /// Applies [changes] (a subset of the profile fields).
  ///
  /// Editing requires the rider role in the ID token. If the token predates
  /// role assignment the backend answers 403; refresh once and retry.
  Future<WorkerProfile> update(Map<String, dynamic> changes) async {
    return _parse(await _asRider(() => api.patchJson(path, changes)));
  }

  /// The demo dark stores the backend offers for the saved platform and city.
  Future<DarkStoreListing> fetchStoreOptions() async {
    final body = await _asRider(() => api.getJson(storesPath));
    try {
      return DarkStoreListing.fromJson(body);
    } on FormatException {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Unexpected response from server.',
      );
    }
  }

  /// Chooses dark store [storeId]. The backend checks it against the saved
  /// profile and resolves its zone; a rejected choice throws [ApiException]
  /// with code `store_not_found`, `store_unavailable`, or `store_mismatch`.
  Future<WorkerProfile> assignDarkStore(String storeId) async {
    final body = await _asRider(
      () => api.putJson(darkStorePath, {'dark_store_id': storeId}),
    );
    return _parse(body);
  }

  /// Runs a rider-only request; on 403 (token predates the rider role)
  /// refreshes the token once and retries, like [update].
  Future<Map<String, dynamic>> _asRider(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on ApiException catch (e) {
      if (e.statusCode != 403 || e.code != 'forbidden') rethrow;
      await auth.getIdToken(forceRefresh: true);
      return request();
    }
  }

  Future<void> _refreshTokenIfRequired(Map<String, dynamic> body) async {
    if (body['token_refresh_required'] != true) return;
    try {
      await auth.getIdToken(forceRefresh: true);
    } catch (_) {
      // Not fatal: the profile is saved. The next fetchMine, or the retry in
      // update, refreshes again.
    }
  }

  static WorkerProfile _parse(Map<String, dynamic> body) {
    final profile = body['profile'];
    try {
      if (profile is Map<String, dynamic>) {
        return WorkerProfile.fromJson(profile);
      }
    } on FormatException {
      // fall through
    }
    throw const ApiException(
      ApiErrorKind.invalidResponse,
      'Unexpected response from server.',
    );
  }
}

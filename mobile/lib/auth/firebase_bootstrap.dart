import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../firebase_options.dart';

/// Project used in emulator mode. It matches `.firebaserc`, the Firebase CLI
/// `--project` flag and the backend's `FIREBASE_PROJECT_ID`, so ID tokens minted
/// by the emulator verify against the local backend. It is never a real project.
const emulatorProjectId = 'demo-shiftsure';

/// Initialises Firebase. By default this uses the generated options for the
/// Firebase development project. With [AppConfig.useAuthEmulator] it points
/// Auth at the local emulator and switches the project id to
/// [emulatorProjectId]; that mode is refused in release builds.
Future<void> initFirebase(AppConfig config) async {
  var options = DefaultFirebaseOptions.currentPlatform;
  if (config.useAuthEmulator) {
    if (kReleaseMode) {
      throw StateError('USE_AUTH_EMULATOR is not allowed in release builds.');
    }
    options = options.copyWith(projectId: emulatorProjectId);
  }
  await Firebase.initializeApp(options: options);
  if (config.useAuthEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(
      config.authEmulatorHost ?? defaultAuthEmulatorHost(),
      config.authEmulatorPort,
      // The host is already resolved above. FlutterFire's automatic mapping
      // would silently rewrite an explicit 127.0.0.1 to 10.0.2.2 on Android,
      // which breaks physical devices using `adb reverse`.
      automaticHostMapping: false,
    );
  }
}

/// The Android emulator reaches the host machine at 10.0.2.2; the iOS
/// simulator shares the host's network.
String defaultAuthEmulatorHost() =>
    defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';

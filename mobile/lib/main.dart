import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/firebase_auth_service.dart';
import 'auth/firebase_bootstrap.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  await initFirebase(config);
  runApp(ShiftSureApp(config: config, auth: FirebaseAuthService()));
}

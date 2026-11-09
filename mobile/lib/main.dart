import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  runApp(ShiftSureApp(config: AppConfig.fromEnvironment()));
}

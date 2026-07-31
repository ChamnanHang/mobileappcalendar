import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // No-op unless built with --dart-define=ADS_ENABLED=true on mobile.
  unawaited(AdsConfig.init());

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NotedApp());
}

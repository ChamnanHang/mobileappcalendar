import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/ads.dart';
import 'widgets/error_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // In a release build a widget that throws paints the grey "an error
  // occurred" box by default — in debug it is the red screen. Neither belongs
  // in a shipped app, so a subtree that fails renders a plain message in the
  // app's own styling instead of a crash artefact.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const AppErrorView();
  };

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

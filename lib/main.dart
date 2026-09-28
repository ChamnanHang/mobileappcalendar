import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  // Status and navigation bar icon colours follow the theme; NotedApp sets
  // them through an AnnotatedRegion so they flip with light and dark mode.

  runApp(const NotedApp());
}

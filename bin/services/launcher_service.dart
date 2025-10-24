import 'dart:io';

import '../utils/logger.dart';

/// Flutter 앱을 실행합니다.
Future<void> launchApp(String flutterAppPath) async {
  final logger = Logger.instance;

  // 경로에서 앱 이름 추출
  // 예: '/Applications/test_dart_cli.app' -> 'test_dart_cli'
  final appName = flutterAppPath
      .split('/')
      .last
      .replaceAll('.app', '');

  await logger.log('Launching Flutter app: $flutterAppPath (app name: $appName)');

  try {
    final process = await Process.start(
      'open',
      ['-a', appName],
      mode: ProcessStartMode.detached,
    );
    await logger.log(
      'Flutter app "$appName" launched successfully (PID: ${process.pid})',
    );
  } catch (e) {
    await logger.log('Failed to launch Flutter app "$appName": $e');
  }
}

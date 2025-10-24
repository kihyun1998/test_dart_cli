import 'dart:io';

import '../utils/logger.dart';

/// Flutter 앱을 실행합니다.
Future<void> launchApp(String flutterAppPath) async {
  final logger = Logger.instance;
  await logger.log('Launching Flutter app: $flutterAppPath');

  try {
    final process = await Process.start(
      'open',
      ['-a', 'test_dart_cli'],  // 앱 이름으로 실행
      mode: ProcessStartMode.detached,
    );
    await logger.log(
      'Flutter app launched successfully (PID: ${process.pid})',
    );
  } catch (e) {
    await logger.log('Failed to launch Flutter app: $e');
  }
}

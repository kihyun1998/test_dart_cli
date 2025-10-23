import 'dart:io';

import '../utils/logger.dart';

/// Flutter 앱을 실행합니다.
Future<void> launchApp(File logFile, String flutterAppPath) async {
  await writeLog(logFile, 'Launching Flutter app: $flutterAppPath');

  try {
    final process = await Process.start(
      'open',
      ['-a', 'test_dart_cli'],  // 앱 이름으로 실행
      mode: ProcessStartMode.detached,
    );
    await writeLog(
      logFile,
      'Flutter app launched successfully (PID: ${process.pid})',
    );
  } catch (e) {
    await writeLog(logFile, 'Failed to launch Flutter app: $e');
  }
}

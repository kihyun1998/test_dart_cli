import 'dart:io';

/// 로그 파일에 타임스탬프와 함께 메시지를 기록합니다.
Future<void> writeLog(File logFile, String message) async {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final logMessage = '[$timestamp] $message\n';

  try {
    await logFile.writeAsString(logMessage, mode: FileMode.append, flush: true);
  } catch (e) {
    stderr.writeln('Failed to write log: $e');
  }
}

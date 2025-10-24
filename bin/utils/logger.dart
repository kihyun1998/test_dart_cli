import 'dart:io';

/// 싱글톤 Logger 클래스
class Logger {
  static Logger? _instance;
  File? _logFile;

  Logger._();

  /// Logger 인스턴스를 가져옵니다.
  static Logger get instance {
    _instance ??= Logger._();
    return _instance!;
  }

  /// 로그 파일을 초기화합니다.
  void initialize(String logFilePath) {
    _logFile = File(logFilePath);

    // 로그 디렉토리 생성
    final logDir = _logFile!.parent;
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
  }

  /// 로그 메시지를 기록합니다.
  Future<void> log(String message) async {
    if (_logFile == null) {
      stderr.writeln('Logger not initialized');
      return;
    }

    final timestamp = DateTime.now().toString().substring(0, 19);
    final logMessage = '[$timestamp] $message\n';

    try {
      await _logFile!.writeAsString(
        logMessage,
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      stderr.writeln('Failed to write log: $e');
    }
  }
}

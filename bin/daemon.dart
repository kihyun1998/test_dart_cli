import 'dart:io';
import 'dart:async';

void main(List<String> args) async {
  // 로그 파일 경로: 인자로 받거나 기본값 사용
  final logFilePath = args.isNotEmpty ? args[0] : 'logs/daemon_log.txt';

  final logFile = File(logFilePath);

  // 로그 디렉토리 생성
  final logDir = logFile.parent;
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final currentPid = pid;

  // 시작 로그 기록
  await _writeLog(logFile, 'Daemon started (PID: $currentPid)');

  // SIGTERM/SIGINT 핸들러 설정
  ProcessSignal.sigterm.watch().listen((signal) async {
    await _writeLog(logFile, 'Daemon received SIGTERM, shutting down...');
    exit(0);
  });

  ProcessSignal.sigint.watch().listen((signal) async {
    await _writeLog(logFile, 'Daemon received SIGINT, shutting down...');
    exit(0);
  });

  // 무한 루프: 1초마다 heartbeat 기록
  while (true) {
    await _writeLog(logFile, 'Heartbeat');
    await Future.delayed(Duration(seconds: 1));
  }
}

Future<void> _writeLog(File logFile, String message) async {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final logMessage = '[$timestamp] $message\n';

  try {
    await logFile.writeAsString(
      logMessage,
      mode: FileMode.append,
      flush: true,
    );
  } catch (e) {
    stderr.writeln('Failed to write log: $e');
  }
}

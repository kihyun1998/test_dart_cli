import 'dart:async';
import 'dart:io';

void main(List<String> args) async {
  // 인자: [로그 파일 경로, Flutter 앱 경로, zip 파일 경로]
  if (args.length < 3) {
    stderr.writeln('Usage: daemon <log_file_path> <flutter_app_path> <zip_file_path>');
    exit(1);
  }

  final logFilePath = args[0];
  final flutterAppPath = args[1];
  final zipFilePath = args[2];

  final logFile = File(logFilePath);

  // 로그 디렉토리 생성
  final logDir = logFile.parent;
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final currentPid = pid;

  // 시작 로그 기록
  await _writeLog(logFile, 'Daemon started (PID: $currentPid)');
  await _writeLog(logFile, 'Flutter app path: $flutterAppPath');
  await _writeLog(logFile, 'Zip file path: $zipFilePath');

  // SIGTERM/SIGINT 핸들러 설정
  ProcessSignal.sigterm.watch().listen((signal) async {
    await _writeLog(logFile, 'Daemon received SIGTERM, shutting down...');
    exit(0);
  });

  ProcessSignal.sigint.watch().listen((signal) async {
    await _writeLog(logFile, 'Daemon received SIGINT, shutting down...');
    exit(0);
  });

  // 10개의 로그 출력
  for (int i = 1; i <= 10; i++) {
    await _writeLog(logFile, 'Log entry $i/10');
    await Future.delayed(Duration(milliseconds: 500));
  }

  // Flutter 앱 실행
  await _writeLog(logFile, 'Launching Flutter app: $flutterAppPath');

  try {
    final process = await Process.start(
      'open',
      ['-a', 'test_dart_cli'],  // 앱 이름으로 실행
      mode: ProcessStartMode.detached,
    );
    await _writeLog(
      logFile,
      'Flutter app launched successfully (PID: ${process.pid})',
    );
  } catch (e) {
    await _writeLog(logFile, 'Failed to launch Flutter app: $e');
  }

  await _writeLog(logFile, 'Daemon exiting...');
  exit(0);
}

Future<void> _writeLog(File logFile, String message) async {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final logMessage = '[$timestamp] $message\n';

  try {
    await logFile.writeAsString(logMessage, mode: FileMode.append, flush: true);
  } catch (e) {
    stderr.writeln('Failed to write log: $e');
  }
}

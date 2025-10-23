import 'dart:async';
import 'dart:io';

void main(List<String> args) async {
  // 인자: [부모 PID, 로그 파일 경로, Flutter 앱 경로, zip 파일 경로]
  if (args.length < 4) {
    stderr.writeln('Usage: daemon <parent_pid> <log_file_path> <flutter_app_path> <zip_file_path>');
    exit(1);
  }

  final parentPid = int.parse(args[0]);
  final logFilePath = args[1];
  final flutterAppPath = args[2];
  final zipFilePath = args[3];

  final logFile = File(logFilePath);

  // 로그 디렉토리 생성
  final logDir = logFile.parent;
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final currentPid = pid;

  // 시작 로그 기록
  await _writeLog(logFile, 'Daemon started (PID: $currentPid)');
  await _writeLog(logFile, 'Parent PID: $parentPid');
  await _writeLog(logFile, 'Flutter app path: $flutterAppPath');
  await _writeLog(logFile, 'Zip file path: $zipFilePath');

  // 부모 프로세스 모니터링 시작
  await _writeLog(logFile, 'Starting parent process monitoring...');
  int checkCount = 0;
  while (await _isProcessAlive(parentPid)) {
    checkCount++;
    await _writeLog(logFile, 'Parent process check #$checkCount: still alive');
    await Future.delayed(Duration(seconds: 1));
  }
  await _writeLog(logFile, 'Parent process exit detected!');

  // SIGTERM/SIGINT 핸들러 설정
  ProcessSignal.sigterm.watch().listen((signal) async {
    await _writeLog(logFile, 'Daemon received SIGTERM, shutting down...');
    exit(0);
  });

  ProcessSignal.sigint.watch().listen((signal) async {
    await _writeLog(logFile, 'Daemon received SIGINT, shutting down...');
    exit(0);
  });

  // 앱 백업
  final backupSuccess = await _backupCurrentApp(logFile, flutterAppPath);
  if (!backupSuccess) {
    await _launchApp(logFile, flutterAppPath);
    await _writeLog(logFile, 'Daemon exiting due to backup failure...');
    exit(1);
  }

  // Flutter 앱 실행
  await _launchApp(logFile, flutterAppPath);

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

Future<bool> _isProcessAlive(int pid) async {
  try {
    final result = await Process.run('ps', ['-p', '$pid']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

Future<bool> _backupCurrentApp(File logFile, String flutterAppPath) async {
  try {
    await _writeLog(logFile, 'Starting backup of current app...');

    final appDir = Directory(flutterAppPath);

    // 사용자 홈 디렉토리에 백업 저장
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      await _writeLog(logFile, 'Failed to get HOME directory');
      return false;
    }

    final backupPath = '$homeDir/.test_dart_cli_backup/test_dart_cli.app.backup';
    final backupDir = Directory(backupPath);

    // 기존 백업 삭제
    if (await backupDir.exists()) {
      await _writeLog(logFile, 'Removing existing backup...');
      await backupDir.delete(recursive: true);
    }

    // 앱 복사
    await _writeLog(logFile, 'Copying app to backup location...');
    await _copyDirectory(appDir, backupDir);

    // 백업 검증
    if (!await backupDir.exists()) {
      await _writeLog(logFile, 'Backup verification failed: backup directory does not exist');
      return false;
    }

    await _writeLog(logFile, 'Backup completed successfully: $backupPath');
    return true;
  } catch (e) {
    await _writeLog(logFile, 'Backup failed: $e');
    return false;
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);

  await for (final entity in source.list(recursive: false)) {
    if (entity is Directory) {
      final newDirectory = Directory('${destination.path}/${entity.path.split('/').last}');
      await _copyDirectory(entity, newDirectory);
    } else if (entity is File) {
      final newFile = File('${destination.path}/${entity.path.split('/').last}');
      await entity.copy(newFile.path);
    }
  }
}

Future<void> _launchApp(File logFile, String flutterAppPath) async {
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
}

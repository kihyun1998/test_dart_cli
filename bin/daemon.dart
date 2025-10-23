import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';

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

  String? tempDir;

  try {
    // 1. 백업 (rename)
    final backupSuccess = await _moveAppToBackup(logFile, flutterAppPath);
    if (!backupSuccess) {
      await _launchApp(logFile, flutterAppPath);
      await _writeLog(logFile, 'Daemon exiting due to backup failure...');
      exit(1);
    }

    // 2. Zip 압축 해제
    tempDir = await _extractZipToTemp(logFile, zipFilePath);
    if (tempDir == null) {
      await _writeLog(logFile, 'Failed to extract zip, rolling back...');
      await _rollbackFromBackup(logFile, flutterAppPath);
      await _launchApp(logFile, flutterAppPath);
      exit(1);
    }

    // 3. 새 앱 설치 (rename)
    final tempAppPath = '$tempDir/test_dart_cli.app';
    final installSuccess = await _installNewApp(logFile, tempAppPath, flutterAppPath);
    if (!installSuccess) {
      await _writeLog(logFile, 'Failed to install new app, rolling back...');
      await _cleanupTempDir(logFile, tempDir);
      await _rollbackFromBackup(logFile, flutterAppPath);
      await _launchApp(logFile, flutterAppPath);
      exit(1);
    }

    // 4. 성공 - 정리
    await _writeLog(logFile, 'Update successful!');
    await _cleanupTempDir(logFile, tempDir);
    await _deleteBackup(logFile);

  } catch (e) {
    await _writeLog(logFile, 'Unexpected error during update: $e');
    if (tempDir != null) {
      await _cleanupTempDir(logFile, tempDir);
    }
    await _rollbackFromBackup(logFile, flutterAppPath);
    await _launchApp(logFile, flutterAppPath);
    exit(1);
  }

  // 5. 앱 재실행
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

Future<bool> _moveAppToBackup(File logFile, String flutterAppPath) async {
  try {
    await _writeLog(logFile, 'Starting backup (rename) of current app...');

    final appDir = Directory(flutterAppPath);
    if (!await appDir.exists()) {
      await _writeLog(logFile, 'App does not exist at: $flutterAppPath');
      return false;
    }

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

    // 백업 디렉토리의 부모 디렉토리 생성
    final backupParent = backupDir.parent;
    if (!await backupParent.exists()) {
      await backupParent.create(recursive: true);
    }

    // 앱을 백업 위치로 rename
    await _writeLog(logFile, 'Moving app to backup location...');
    await appDir.rename(backupPath);

    // 백업 검증
    if (!await backupDir.exists()) {
      await _writeLog(logFile, 'Backup verification failed: backup directory does not exist');
      return false;
    }

    await _writeLog(logFile, 'Backup completed successfully (renamed): $backupPath');
    return true;
  } catch (e) {
    await _writeLog(logFile, 'Backup failed: $e');
    return false;
  }
}

Future<String?> _extractZipToTemp(File logFile, String zipFilePath) async {
  try {
    await _writeLog(logFile, 'Starting zip extraction...');

    // Zip 파일 존재 확인
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      await _writeLog(logFile, 'Zip file does not exist: $zipFilePath');
      return null;
    }

    // 임시 디렉토리 생성
    final tempDir = await Directory.systemTemp.createTemp('test_dart_cli_update_');
    await _writeLog(logFile, 'Created temp directory: ${tempDir.path}');

    // Zip 파일 읽기
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 압축 해제
    for (final file in archive) {
      final filename = file.name;
      final filePath = '${tempDir.path}/$filename';

      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);

        // Unix 권한 복원 (특히 실행 파일)
        // Unix 권한 비트만 추출 (하위 9비트: rwxrwxrwx)
        final mode = file.mode & 0x1FF;
        if (mode != 0) {
          try {
            await Process.run('chmod', [mode.toRadixString(8), filePath]);
          } catch (e) {
            await _writeLog(logFile, 'Failed to set permissions for $filename: $e');
          }
        }
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    await _writeLog(logFile, 'Zip extraction completed: ${archive.length} files extracted');

    // test_dart_cli.app 존재 확인
    final appPath = '${tempDir.path}/test_dart_cli.app';
    final appDir = Directory(appPath);
    if (!await appDir.exists()) {
      await _writeLog(logFile, 'Extracted app not found: $appPath');
      await tempDir.delete(recursive: true);
      return null;
    }

    await _writeLog(logFile, 'App found at: $appPath');
    return tempDir.path;
  } catch (e) {
    await _writeLog(logFile, 'Zip extraction failed: $e');
    return null;
  }
}

Future<bool> _installNewApp(File logFile, String tempAppPath, String targetPath) async {
  try {
    await _writeLog(logFile, 'Installing new app...');
    await _writeLog(logFile, 'From: $tempAppPath');
    await _writeLog(logFile, 'To: $targetPath');

    final tempApp = Directory(tempAppPath);
    if (!await tempApp.exists()) {
      await _writeLog(logFile, 'Temp app does not exist: $tempAppPath');
      return false;
    }

    // Rename으로 이동
    await tempApp.rename(targetPath);

    // 설치 검증
    final installedApp = Directory(targetPath);
    if (!await installedApp.exists()) {
      await _writeLog(logFile, 'Installation verification failed: app not found at $targetPath');
      return false;
    }

    await _writeLog(logFile, 'New app installed successfully');
    return true;
  } catch (e) {
    await _writeLog(logFile, 'Installation failed: $e');
    return false;
  }
}

Future<bool> _rollbackFromBackup(File logFile, String flutterAppPath) async {
  try {
    await _writeLog(logFile, 'Rolling back from backup...');

    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      await _writeLog(logFile, 'Failed to get HOME directory for rollback');
      return false;
    }

    final backupPath = '$homeDir/.test_dart_cli_backup/test_dart_cli.app.backup';
    final backupDir = Directory(backupPath);

    if (!await backupDir.exists()) {
      await _writeLog(logFile, 'Backup does not exist: $backupPath');
      return false;
    }

    // 실패한 앱이 있다면 삭제
    final failedApp = Directory(flutterAppPath);
    if (await failedApp.exists()) {
      await _writeLog(logFile, 'Removing failed app...');
      await failedApp.delete(recursive: true);
    }

    // 백업을 원래 위치로 rename
    await backupDir.rename(flutterAppPath);

    // 롤백 검증
    final restoredApp = Directory(flutterAppPath);
    if (!await restoredApp.exists()) {
      await _writeLog(logFile, 'Rollback verification failed: app not found at $flutterAppPath');
      return false;
    }

    await _writeLog(logFile, 'Rollback completed successfully');
    return true;
  } catch (e) {
    await _writeLog(logFile, 'Rollback failed: $e');
    return false;
  }
}

Future<void> _cleanupTempDir(File logFile, String tempDir) async {
  try {
    await _writeLog(logFile, 'Cleaning up temp directory: $tempDir');
    final dir = Directory(tempDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await _writeLog(logFile, 'Temp directory deleted');
    }
  } catch (e) {
    await _writeLog(logFile, 'Failed to cleanup temp directory (non-critical): $e');
  }
}

Future<void> _deleteBackup(File logFile) async {
  try {
    await _writeLog(logFile, 'Deleting backup...');

    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      await _writeLog(logFile, 'Failed to get HOME directory');
      return;
    }

    final backupPath = '$homeDir/.test_dart_cli_backup/test_dart_cli.app.backup';
    final backupDir = Directory(backupPath);

    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
      await _writeLog(logFile, 'Backup deleted successfully');
    } else {
      await _writeLog(logFile, 'No backup to delete');
    }
  } catch (e) {
    await _writeLog(logFile, 'Failed to delete backup (non-critical): $e');
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

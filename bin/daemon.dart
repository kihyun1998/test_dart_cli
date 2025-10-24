import 'dart:io';

import 'utils/logger.dart';
import 'utils/process_monitor.dart';
import 'services/backup_service.dart';
import 'services/installer_service.dart';
import 'services/launcher_service.dart';

void main(List<String> args) async {
  // 인자: [부모 PID, 로그 파일 경로, Flutter 앱 경로, 압축 해제된 폴더 경로]
  if (args.length < 4) {
    stderr.writeln('Usage: daemon <parent_pid> <log_file_path> <flutter_app_path> <extracted_folder_path>');
    exit(1);
  }

  final parentPid = int.parse(args[0]);
  final logFilePath = args[1];
  final flutterAppPath = args[2];
  final extractedFolderPath = args[3];

  final logFile = File(logFilePath);

  // 로그 디렉토리 생성
  final logDir = logFile.parent;
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final currentPid = pid;

  // 시작 로그 기록
  await writeLog(logFile, 'Daemon started (PID: $currentPid)');
  await writeLog(logFile, 'Parent PID: $parentPid');
  await writeLog(logFile, 'Flutter app path: $flutterAppPath');
  await writeLog(logFile, 'Extracted folder path: $extractedFolderPath');

  // 부모 프로세스 모니터링
  await monitorParentProcess(logFile, parentPid);

  // SIGTERM/SIGINT 핸들러 설정
  setupSignalHandlers(logFile);

  // 업데이트 프로세스 실행
  await _runUpdateProcess(logFile, flutterAppPath, extractedFolderPath);
}

/// 임시 디렉토리를 삭제합니다.
Future<void> cleanupTempDir(File logFile, String tempDir) async {
  try {
    await writeLog(logFile, 'Cleaning up temp directory: $tempDir');
    final dir = Directory(tempDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await writeLog(logFile, 'Temp directory deleted');
    }
  } catch (e) {
    await writeLog(logFile, 'Failed to cleanup temp directory (non-critical): $e');
  }
}

/// 업데이트 프로세스를 실행합니다.
Future<void> _runUpdateProcess(
  File logFile,
  String flutterAppPath,
  String extractedFolderPath,
) async {
  try {
    // 1. 백업 (rename)
    final backupSuccess = await moveAppToBackup(logFile, flutterAppPath);
    if (!backupSuccess) {
      await launchApp(logFile, flutterAppPath);
      await writeLog(logFile, 'Daemon exiting due to backup failure...');
      exit(1);
    }

    // 2. 압축 해제된 앱 존재 확인
    final tempAppPath = '$extractedFolderPath/test_dart_cli.app';
    final tempApp = Directory(tempAppPath);
    if (!await tempApp.exists()) {
      await writeLog(logFile, 'Extracted app not found: $tempAppPath');
      await cleanupTempDir(logFile, extractedFolderPath);
      await rollbackFromBackup(logFile, flutterAppPath);
      await launchApp(logFile, flutterAppPath);
      exit(1);
    }
    await writeLog(logFile, 'Extracted app verified: $tempAppPath');

    // 3. 새 앱 설치 (rename)
    final installSuccess = await installNewApp(logFile, tempAppPath, flutterAppPath);
    if (!installSuccess) {
      await writeLog(logFile, 'Failed to install new app, rolling back...');
      await cleanupTempDir(logFile, extractedFolderPath);
      await rollbackFromBackup(logFile, flutterAppPath);
      await launchApp(logFile, flutterAppPath);
      exit(1);
    }

    // 4. 성공 - 정리
    await writeLog(logFile, 'Update successful!');
    await cleanupTempDir(logFile, extractedFolderPath);
    await deleteBackup(logFile);

  } catch (e) {
    await writeLog(logFile, 'Unexpected error during update: $e');
    await cleanupTempDir(logFile, extractedFolderPath);
    await rollbackFromBackup(logFile, flutterAppPath);
    await launchApp(logFile, flutterAppPath);
    exit(1);
  }

  // 5. 앱 재실행
  await launchApp(logFile, flutterAppPath);
  await writeLog(logFile, 'Daemon exiting...');
  exit(0);
}

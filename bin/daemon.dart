import 'dart:io';

import 'utils/logger.dart';
import 'utils/process_monitor.dart';
import 'services/backup_service.dart';
import 'services/installer_service.dart';
import 'services/launcher_service.dart';

void main(List<String> args) async {
  // 인자: [부모 PID, 로그 파일 경로, Flutter 앱 경로, 압축 해제된 폴더 경로, 백업 경로]
  if (args.length < 5) {
    stderr.writeln('Usage: daemon <parent_pid> <log_file_path> <flutter_app_path> <extracted_folder_path> <backup_path>');
    exit(1);
  }

  final parentPid = int.parse(args[0]);
  final logFilePath = args[1];
  final flutterAppPath = args[2];
  final extractedFolderPath = args[3];
  final backupPath = args[4];

  // Logger 초기화
  final logger = Logger.instance;
  logger.initialize(logFilePath);

  final currentPid = pid;

  // 시작 로그 기록
  await logger.log('Daemon started (PID: $currentPid)');
  await logger.log('Parent PID: $parentPid');
  await logger.log('Flutter app path: $flutterAppPath');
  await logger.log('Extracted folder path: $extractedFolderPath');
  await logger.log('Backup path: $backupPath');

  // 부모 프로세스 모니터링
  await monitorParentProcess(parentPid);

  // SIGTERM/SIGINT 핸들러 설정
  setupSignalHandlers();

  // 업데이트 프로세스 실행
  await _runUpdateProcess(flutterAppPath, extractedFolderPath, backupPath);
}

/// 임시 디렉토리를 삭제합니다.
Future<void> cleanupTempDir(String tempDir) async {
  final logger = Logger.instance;
  try {
    await logger.log('Cleaning up temp directory: $tempDir');
    final dir = Directory(tempDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await logger.log('Temp directory deleted');
    }
  } catch (e) {
    await logger.log('Failed to cleanup temp directory (non-critical): $e');
  }
}

/// 업데이트 프로세스를 실행합니다.
Future<void> _runUpdateProcess(
  String flutterAppPath,
  String extractedFolderPath,
  String backupPath,
) async {
  final logger = Logger.instance;

  try {
    // 1. 백업 (rename)
    final backupSuccess = await moveAppToBackup(flutterAppPath, backupPath);
    if (!backupSuccess) {
      await launchApp(flutterAppPath);
      await logger.log('Daemon exiting due to backup failure...');
      exit(1);
    }

    // 2. 압축 해제된 앱 존재 확인
    final tempAppPath = '$extractedFolderPath/test_dart_cli.app';
    final tempApp = Directory(tempAppPath);
    if (!await tempApp.exists()) {
      await logger.log('Extracted app not found: $tempAppPath');
      await cleanupTempDir(extractedFolderPath);
      await rollbackFromBackup(flutterAppPath, backupPath);
      await launchApp(flutterAppPath);
      exit(1);
    }
    await logger.log('Extracted app verified: $tempAppPath');

    // 3. 새 앱 설치 (rename)
    final installSuccess = await installNewApp(tempAppPath, flutterAppPath);
    if (!installSuccess) {
      await logger.log('Failed to install new app, rolling back...');
      await cleanupTempDir(extractedFolderPath);
      await rollbackFromBackup(flutterAppPath, backupPath);
      await launchApp(flutterAppPath);
      exit(1);
    }

    // 4. 성공 - 정리
    await logger.log('Update successful!');
    await cleanupTempDir(extractedFolderPath);
    await deleteBackup(backupPath);

  } catch (e) {
    await logger.log('Unexpected error during update: $e');
    await cleanupTempDir(extractedFolderPath);
    await rollbackFromBackup(flutterAppPath, backupPath);
    await launchApp(flutterAppPath);
    exit(1);
  }

  // 5. 앱 재실행
  await launchApp(flutterAppPath);
  await logger.log('Daemon exiting...');
  exit(0);
}

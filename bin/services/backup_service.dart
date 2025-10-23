import 'dart:io';

import '../utils/logger.dart';

/// 백업 경로를 계산합니다.
String getBackupPath() {
  final homeDir = Platform.environment['HOME'];
  if (homeDir == null) {
    throw Exception('Failed to get HOME directory');
  }
  return '$homeDir/.test_dart_cli_backup/test_dart_cli.app.backup';
}

/// 현재 앱을 백업 위치로 이동합니다 (rename 사용).
Future<bool> moveAppToBackup(File logFile, String flutterAppPath) async {
  try {
    await writeLog(logFile, 'Starting backup (rename) of current app...');

    final appDir = Directory(flutterAppPath);
    if (!await appDir.exists()) {
      await writeLog(logFile, 'App does not exist at: $flutterAppPath');
      return false;
    }

    final backupPath = getBackupPath();
    final backupDir = Directory(backupPath);

    // 기존 백업 삭제
    if (await backupDir.exists()) {
      await writeLog(logFile, 'Removing existing backup...');
      await backupDir.delete(recursive: true);
    }

    // 백업 디렉토리의 부모 디렉토리 생성
    final backupParent = backupDir.parent;
    if (!await backupParent.exists()) {
      await backupParent.create(recursive: true);
    }

    // 앱을 백업 위치로 rename
    await writeLog(logFile, 'Moving app to backup location...');
    await appDir.rename(backupPath);

    // 백업 검증
    if (!await backupDir.exists()) {
      await writeLog(logFile, 'Backup verification failed: backup directory does not exist');
      return false;
    }

    await writeLog(logFile, 'Backup completed successfully (renamed): $backupPath');
    return true;
  } catch (e) {
    await writeLog(logFile, 'Backup failed: $e');
    return false;
  }
}

/// 백업에서 앱을 복원합니다 (rollback).
Future<bool> rollbackFromBackup(File logFile, String flutterAppPath) async {
  try {
    await writeLog(logFile, 'Rolling back from backup...');

    final backupPath = getBackupPath();
    final backupDir = Directory(backupPath);

    if (!await backupDir.exists()) {
      await writeLog(logFile, 'Backup does not exist: $backupPath');
      return false;
    }

    // 실패한 앱이 있다면 삭제
    final failedApp = Directory(flutterAppPath);
    if (await failedApp.exists()) {
      await writeLog(logFile, 'Removing failed app...');
      await failedApp.delete(recursive: true);
    }

    // 백업을 원래 위치로 rename
    await backupDir.rename(flutterAppPath);

    // 롤백 검증
    final restoredApp = Directory(flutterAppPath);
    if (!await restoredApp.exists()) {
      await writeLog(logFile, 'Rollback verification failed: app not found at $flutterAppPath');
      return false;
    }

    await writeLog(logFile, 'Rollback completed successfully');
    return true;
  } catch (e) {
    await writeLog(logFile, 'Rollback failed: $e');
    return false;
  }
}

/// 백업을 삭제합니다 (성공 시 정리용).
Future<void> deleteBackup(File logFile) async {
  try {
    await writeLog(logFile, 'Deleting backup...');

    final backupPath = getBackupPath();
    final backupDir = Directory(backupPath);

    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
      await writeLog(logFile, 'Backup deleted successfully');
    } else {
      await writeLog(logFile, 'No backup to delete');
    }
  } catch (e) {
    await writeLog(logFile, 'Failed to delete backup (non-critical): $e');
  }
}

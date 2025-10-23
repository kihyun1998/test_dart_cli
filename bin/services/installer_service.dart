import 'dart:io';

import '../utils/logger.dart';

/// 임시 디렉토리의 앱을 타겟 위치로 설치합니다 (rename 사용).
Future<bool> installNewApp(File logFile, String tempAppPath, String targetPath) async {
  try {
    await writeLog(logFile, 'Installing new app...');
    await writeLog(logFile, 'From: $tempAppPath');
    await writeLog(logFile, 'To: $targetPath');

    final tempApp = Directory(tempAppPath);
    if (!await tempApp.exists()) {
      await writeLog(logFile, 'Temp app does not exist: $tempAppPath');
      return false;
    }

    // Rename으로 이동
    await tempApp.rename(targetPath);

    // 설치 검증
    final installedApp = Directory(targetPath);
    if (!await installedApp.exists()) {
      await writeLog(logFile, 'Installation verification failed: app not found at $targetPath');
      return false;
    }

    await writeLog(logFile, 'New app installed successfully');
    return true;
  } catch (e) {
    await writeLog(logFile, 'Installation failed: $e');
    return false;
  }
}

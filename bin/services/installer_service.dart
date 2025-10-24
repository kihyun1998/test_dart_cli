import 'dart:io';

import '../utils/logger.dart';

/// 임시 디렉토리의 앱을 타겟 위치로 설치합니다 (rename 사용).
Future<bool> installNewApp(String tempAppPath, String targetPath) async {
  final logger = Logger.instance;
  try {
    await logger.log('Installing new app...');
    await logger.log('From: $tempAppPath');
    await logger.log('To: $targetPath');

    final tempApp = Directory(tempAppPath);
    if (!await tempApp.exists()) {
      await logger.log('Temp app does not exist: $tempAppPath');
      return false;
    }

    // Rename으로 이동
    await tempApp.rename(targetPath);

    // 설치 검증
    final installedApp = Directory(targetPath);
    if (!await installedApp.exists()) {
      await logger.log('Installation verification failed: app not found at $targetPath');
      return false;
    }

    await logger.log('New app installed successfully');
    return true;
  } catch (e) {
    await logger.log('Installation failed: $e');
    return false;
  }
}

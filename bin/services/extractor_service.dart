import 'dart:io';
import 'package:archive/archive.dart';

import '../utils/logger.dart';

/// Zip 파일을 임시 디렉토리에 압축 해제합니다.
/// 성공 시 임시 디렉토리 경로를 반환하고, 실패 시 null을 반환합니다.
Future<String?> extractZipToTemp(File logFile, String zipFilePath) async {
  try {
    await writeLog(logFile, 'Starting zip extraction...');

    // Zip 파일 존재 확인
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      await writeLog(logFile, 'Zip file does not exist: $zipFilePath');
      return null;
    }

    // 임시 디렉토리 생성
    final tempDir = await Directory.systemTemp.createTemp('test_dart_cli_update_');
    await writeLog(logFile, 'Created temp directory: ${tempDir.path}');

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
        await _restorePermissions(logFile, file, filePath, filename);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    await writeLog(logFile, 'Zip extraction completed: ${archive.length} files extracted');

    // test_dart_cli.app 존재 확인
    final appPath = '${tempDir.path}/test_dart_cli.app';
    final appDir = Directory(appPath);
    if (!await appDir.exists()) {
      await writeLog(logFile, 'Extracted app not found: $appPath');
      await tempDir.delete(recursive: true);
      return null;
    }

    await writeLog(logFile, 'App found at: $appPath');
    return tempDir.path;
  } catch (e) {
    await writeLog(logFile, 'Zip extraction failed: $e');
    return null;
  }
}

/// Unix 권한을 복원합니다.
Future<void> _restorePermissions(
  File logFile,
  ArchiveFile file,
  String filePath,
  String filename,
) async {
  // Unix 권한 비트만 추출 (하위 9비트: rwxrwxrwx)
  final mode = file.mode & 0x1FF;
  if (mode != 0) {
    try {
      await Process.run('chmod', [mode.toRadixString(8), filePath]);
    } catch (e) {
      await writeLog(logFile, 'Failed to set permissions for $filename: $e');
    }
  }
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

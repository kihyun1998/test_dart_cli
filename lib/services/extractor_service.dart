import 'dart:io';
import 'package:archive/archive.dart';

/// 압축 해제 결과를 담는 클래스
class ExtractionResult {
  final bool success;
  final String? extractedPath;
  final String message;

  ExtractionResult({
    required this.success,
    this.extractedPath,
    required this.message,
  });
}

/// Zip 파일을 임시 디렉토리에 압축 해제합니다.
/// 성공 시 임시 디렉토리 경로를 반환하고, 실패 시 에러 메시지를 반환합니다.
Future<ExtractionResult> extractZipToTemp(String zipFilePath) async {
  Directory? tempDir;

  try {
    print('[Extractor] Starting zip extraction...');
    print('[Extractor] Zip file path: $zipFilePath');

    // Zip 파일 존재 확인
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      return ExtractionResult(
        success: false,
        message: 'Zip 파일이 존재하지 않습니다: $zipFilePath',
      );
    }

    // 임시 디렉토리 생성 (고정 경로 사용)
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      return ExtractionResult(
        success: false,
        message: 'HOME 환경 변수를 찾을 수 없습니다',
      );
    }

    tempDir = Directory('$homeDir/.test_dart_cli_temp');

    // 기존 임시 디렉토리가 있으면 삭제
    if (await tempDir.exists()) {
      print('[Extractor] Removing existing temp directory...');
      await tempDir.delete(recursive: true);
    }

    // 임시 디렉토리 생성
    await tempDir.create(recursive: true);
    print('[Extractor] Created temp directory: ${tempDir.path}');

    // Zip 파일 읽기
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    print('[Extractor] Zip file decoded: ${archive.length} files found');

    // 압축 해제
    int fileCount = 0;
    for (final file in archive) {
      final filename = file.name;
      final filePath = '${tempDir.path}/$filename';

      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);

        // Unix 권한 복원 (특히 실행 파일)
        await _restorePermissions(file, filePath, filename);
        fileCount++;
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    print('[Extractor] Zip extraction completed: $fileCount files extracted');

    // test_dart_cli.app 존재 확인
    final appPath = '${tempDir.path}/test_dart_cli.app';
    final appDir = Directory(appPath);
    if (!await appDir.exists()) {
      final errorMsg = 'Extracted app not found: $appPath';
      print('[Extractor] Error: $errorMsg');
      await tempDir.delete(recursive: true);
      return ExtractionResult(
        success: false,
        message: '압축 해제된 앱을 찾을 수 없습니다: $appPath',
      );
    }

    print('[Extractor] App verified at: $appPath');
    return ExtractionResult(
      success: true,
      extractedPath: tempDir.path,
      message: '압축 해제 성공: $fileCount개 파일 처리됨',
    );
  } catch (e) {
    print('[Extractor] Zip extraction failed: $e');
    // 실패 시 임시 디렉토리 정리
    if (tempDir != null && await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (cleanupError) {
        print('[Extractor] Failed to cleanup temp directory: $cleanupError');
      }
    }
    return ExtractionResult(
      success: false,
      message: '압축 해제 실패: $e',
    );
  }
}

/// Unix 권한을 복원합니다.
Future<void> _restorePermissions(
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
      print('[Extractor] Failed to set permissions for $filename: $e');
    }
  }
}

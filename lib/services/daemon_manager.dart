import 'dart:io';

class ProcessInfo {
  final int pid;
  final String status;
  final String? cpuUsage;
  final String? memUsage;

  ProcessInfo({
    required this.pid,
    required this.status,
    this.cpuUsage,
    this.memUsage,
  });
}

class BuildResult {
  final bool success;
  final String message;

  BuildResult({required this.success, required this.message});
}

class RunResult {
  final bool success;
  final int? pid;
  final String message;

  RunResult({required this.success, this.pid, required this.message});
}

class DaemonManager {
  // 프로젝트 루트 경로 (하드코딩)
  static const String projectRoot = '/Users/kihyun/Documents/GitHub/test_dart_cli';

  // Flutter 앱 번들 내 실행 파일 디렉토리
  String get appBundleDir => Directory(Platform.resolvedExecutable).parent.path;

  String get binSource => '$projectRoot/bin/daemon.dart';
  String get binaryPath => '$appBundleDir/daemon';  // 앱 번들 내부 경로
  String get logPath => '$projectRoot/logs/daemon_log.txt';
  String get flutterAppPath => '$projectRoot/build/macos/Build/Products/Debug/test_dart_cli.app';
  String get zipFilePath => '$projectRoot/app_out/test_dart_cli_updater.zip';  // 다운로드 받은 zip 파일 경로 (하드코딩)

  /// 데몬 프로세스 실행
  Future<RunResult> runDaemon() async {
    try {
      // 바이너리 파일 존재 확인
      final binary = File(binaryPath);
      if (!binary.existsSync()) {
        return RunResult(
          success: false,
          message: '❌ 바이너리 파일이 없습니다!\n\n'
              '앱 번들 경로: $appBundleDir\n'
              '바이너리 경로: $binaryPath\n\n'
              '다음 명령어로 바이너리를 빌드하고 복사하세요:\n'
              'dart compile exe bin/daemon.dart -o bin_output/daemon\n'
              'cp bin_output/daemon "$appBundleDir/daemon"',
        );
      }

      // Flutter 앱 존재 확인
      final flutterApp = Directory(flutterAppPath);
      if (!flutterApp.existsSync()) {
        return RunResult(
          success: false,
          message: '❌ Flutter 앱이 빌드되지 않았습니다!\n\n'
              '다음 명령어로 앱을 빌드하세요:\n'
              'flutter build macos --debug\n\n'
              '경로: $flutterAppPath',
        );
      }

      // 로그 디렉토리 생성
      final logsDir = Directory('$projectRoot/logs');
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }

      // 현재 프로세스 PID 가져오기
      final currentPid = pid;

      // detached 모드로 프로세스 시작 (부모 PID, 로그 경로, Flutter 앱 경로, zip 파일 경로를 인자로 전달)
      final process = await Process.start(
        binaryPath,
        ['$currentPid', logPath, flutterAppPath, zipFilePath], // 부모 PID + 로그 파일 + Flutter 앱 경로 + zip 파일 경로 전달
        mode: ProcessStartMode.detached,
        workingDirectory: projectRoot,
      );

      return RunResult(
        success: true,
        pid: process.pid,
        message: '✅ 데몬 시작됨 (PID: ${process.pid})\n1초 후 앱이 종료되고 데몬이 작업을 시작합니다.',
      );
    } catch (e) {
      return RunResult(success: false, message: '❌ 실행 오류: $e');
    }
  }

  /// 프로세스 상태 확인
  Future<ProcessInfo?> checkStatus() async {
    try {
      // ps aux | grep daemon | grep -v grep
      final result = await Process.run('sh', [
        '-c',
        'ps aux | grep daemon | grep -v grep',
      ], workingDirectory: projectRoot);

      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        final output = result.stdout.toString().trim();

        // 출력 파싱 (macOS ps aux 형식)
        // USER  PID  %CPU %MEM ... COMMAND
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains(binaryPath)) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length > 10) {
              return ProcessInfo(
                pid: int.parse(parts[1]),
                status: 'running',
                cpuUsage: parts[2],
                memUsage: parts[3],
              );
            }
          }
        }
      }

      return null; // 프로세스 없음
    } catch (e) {
      return null;
    }
  }

  /// 로그 파일 읽기
  Future<List<String>> readLogs({int lines = 10}) async {
    try {
      final logFile = File(logPath);
      if (!logFile.existsSync()) {
        return ['로그 파일이 없습니다.'];
      }

      final allLines = await logFile.readAsLines();

      // 마지막 N줄 반환
      if (allLines.length <= lines) {
        return allLines;
      } else {
        return allLines.sublist(allLines.length - lines);
      }
    } catch (e) {
      return ['로그 읽기 오류: $e'];
    }
  }

  /// 데몬 프로세스 종료
  Future<bool> killDaemon(int pid) async {
    try {
      final result = await Process.run('kill', [
        '-15',
        pid.toString(),
      ], workingDirectory: projectRoot);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 로그 파일 초기화
  Future<void> clearLogs() async {
    try {
      final logFile = File(logPath);
      if (logFile.existsSync()) {
        await logFile.delete();
      }
    } catch (e) {
      // 에러 무시
    }
  }
}

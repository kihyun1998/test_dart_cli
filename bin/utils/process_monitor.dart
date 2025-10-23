import 'dart:async';
import 'dart:io';

import 'logger.dart';

/// 프로세스가 살아있는지 확인합니다.
Future<bool> isProcessAlive(int pid) async {
  try {
    final result = await Process.run('ps', ['-p', '$pid']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

/// 부모 프로세스가 종료될 때까지 모니터링합니다.
Future<void> monitorParentProcess(File logFile, int parentPid) async {
  await writeLog(logFile, 'Starting parent process monitoring...');
  int checkCount = 0;
  while (await isProcessAlive(parentPid)) {
    checkCount++;
    await writeLog(logFile, 'Parent process check #$checkCount: still alive');
    await Future.delayed(Duration(seconds: 1));
  }
  await writeLog(logFile, 'Parent process exit detected!');
}

/// SIGTERM/SIGINT 시그널 핸들러를 설정합니다.
void setupSignalHandlers(File logFile) {
  ProcessSignal.sigterm.watch().listen((signal) async {
    await writeLog(logFile, 'Daemon received SIGTERM, shutting down...');
    exit(0);
  });

  ProcessSignal.sigint.watch().listen((signal) async {
    await writeLog(logFile, 'Daemon received SIGINT, shutting down...');
    exit(0);
  });
}

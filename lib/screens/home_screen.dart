import 'dart:io';

import 'package:flutter/material.dart';

import '../services/daemon_manager.dart';
import '../services/extractor_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DaemonManager _manager = DaemonManager();

  // 하드코딩된 버전 정보
  static const String appVersion = '5.0.3';
  static const String buildNumber = '1';

  String _statusMessage = '업데이트 대기 중...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startUpdate() async {
    // 1단계: Zip 압축 해제
    setState(() {
      _isLoading = true;
      _statusMessage = 'Zip 파일 압축 해제 중...\n경로: ${_manager.zipFilePath}';
    });

    print('===== Zip 압축 해제 시작 =====');
    print('Zip 파일 경로: ${_manager.zipFilePath}');

    final extractResult = await extractZipToTemp(_manager.zipFilePath);

    if (!extractResult.success) {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ 압축 해제 실패\n\n${extractResult.message}';
      });
      print('압축 해제 실패: ${extractResult.message}');
      return;
    }

    print('압축 해제 성공: ${extractResult.extractedPath}');
    print('==============================');

    // 2단계: Daemon 프로세스 시작
    setState(() {
      _statusMessage = '업데이트 프로세스 시작 중...\n압축 해제 완료: ${extractResult.message}';
    });

    final result = await _manager.runDaemon(extractResult.extractedPath!);

    // 콘솔에 로그 출력
    print('===== 업데이트 프로세스 시작 =====');
    print(result.message);
    print('바이너리 경로: ${_manager.binaryPath}');
    print('로그 파일 경로: ${_manager.logPath}');
    print('Flutter 앱 경로: ${_manager.flutterAppPath}');
    print('압축 해제된 폴더: ${extractResult.extractedPath}');
    print('=================================');

    setState(() {
      _isLoading = false;
      _statusMessage = result.message;
    });

    if (result.success) {
      // 1초 후 앱 종료
      print('1초 후 앱이 종료됩니다...');
      await Future.delayed(const Duration(seconds: 1));
      print('앱 종료 - 업데이트 프로세스가 백그라운드에서 실행됩니다.');
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('macOS Zip Updater Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 버전 정보 카드
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '버전 정보',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('현재 버전:', style: TextStyle(fontSize: 16)),
                        Text(
                          'v$appVersion',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('빌드 번호:', style: TextStyle(fontSize: 16)),
                        Text(
                          buildNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 업데이트 버튼
            SizedBox(
              height: 80,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('업데이트 진행 중...', style: TextStyle(fontSize: 18)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.system_update, size: 28),
                          SizedBox(width: 12),
                          Text(
                            '업데이트 시작',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // 업데이트 로그 영역
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '업데이트 로그',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../services/daemon_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DaemonManager _manager = DaemonManager();

  String _statusMessage = '대기 중...';
  ProcessInfo? _processInfo;
  List<String> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _runDaemon() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '실행 중...';
    });

    final result = await _manager.runDaemon();

    // 콘솔에 로그 출력
    print('===== 데몬 실행 결과 =====');
    print(result.message);
    print('바이너리 경로: ${_manager.binaryPath}');
    print('로그 파일 경로: ${_manager.logPath}');
    print('Flutter 앱 경로: ${_manager.flutterAppPath}');
    print('=========================');

    setState(() {
      _isLoading = false;
      _statusMessage = result.message;
    });

    if (result.success) {
      await _checkStatus();

      // 1초 후 앱 종료
      print('1초 후 앱이 종료됩니다...');
      await Future.delayed(const Duration(seconds: 1));
      print('앱 종료');
      exit(0);
    }
  }

  Future<void> _checkStatus() async {
    final info = await _manager.checkStatus();

    setState(() {
      _processInfo = info;
      if (info != null) {
        _statusMessage =
            '데몬 실행 중 (PID: ${info.pid}, CPU: ${info.cpuUsage}%, MEM: ${info.memUsage}%)';
      } else {
        _statusMessage = '데몬이 실행 중이지 않습니다.';
      }
    });
  }

  Future<void> _showLogs() async {
    final logs = await _manager.readLogs(lines: 20);

    setState(() {
      _logs = logs;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데몬 로그'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  logs[index],
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _killDaemon() async {
    if (_processInfo == null) {
      setState(() {
        _statusMessage = '종료할 프로세스가 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '프로세스 종료 중...';
    });

    final success = await _manager.killDaemon(_processInfo!.pid);

    setState(() {
      _isLoading = false;
      _statusMessage = success ? '프로세스 종료 성공' : '프로세스 종료 실패';
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _checkStatus();
  }

  Future<void> _clearLogs() async {
    await _manager.clearLogs();

    setState(() {
      _statusMessage = '로그 파일 초기화 완료';
      _logs = [];
    });
  }

  void _exitApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('Flutter 앱을 종료하시겠습니까?\n(데몬 프로세스는 계속 실행됩니다)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              exit(0);
            },
            child: const Text('종료', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daemon Process Experiment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상태 표시 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '프로세스 상태',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _processInfo != null
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _processInfo != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _processInfo != null
                                ? '실행 중 (PID: ${_processInfo!.pid})'
                                : '중지됨',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    if (_processInfo != null) ...[
                      const SizedBox(height: 8),
                      Text('CPU: ${_processInfo!.cpuUsage}%'),
                      Text('MEM: ${_processInfo!.memUsage}%'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 버튼 그리드
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _runDaemon,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('실행'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('상태 확인'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showLogs,
                  icon: const Icon(Icons.article),
                  label: const Text('로그 보기'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _killDaemon,
                  icon: const Icon(Icons.stop),
                  label: const Text('종료'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _clearLogs,
                  icon: const Icon(Icons.delete),
                  label: const Text('로그 초기화'),
                ),
                ElevatedButton.icon(
                  onPressed: _exitApp,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('앱 종료'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 작업 로그 영역
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '작업 로그',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 14),
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

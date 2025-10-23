# Daemon Process Experiment

Flutter 앱과 독립적으로 실행되는 Dart 바이너리 데몬 프로세스 실험 프로젝트입니다.

## 프로젝트 목적

Flutter 앱이 종료되어도 Dart 바이너리 프로세스가 계속 실행되는지 테스트합니다.

## 프로젝트 구조

```
test_dart_cli/
├── bin/
│   └── daemon.dart          # Dart CLI 데몬 소스
├── bin_output/
│   └── daemon              # 컴파일된 실행 파일
├── logs/
│   └── daemon_log.txt      # 데몬 로그 파일
├── lib/
│   ├── main.dart
│   ├── services/
│   │   └── daemon_manager.dart
│   └── screens/
│       └── home_screen.dart
```

## 빌드 방법

### 1. Dart 데몬 바이너리 빌드

프로젝트 루트에서 다음 명령어를 실행하세요:

```bash
dart compile exe bin/daemon.dart -o bin_output/daemon
```

이 명령어는 `bin/daemon.dart`를 컴파일하여 `bin_output/daemon` 실행 파일을 생성합니다.

### 2. Flutter 앱 실행

```bash
flutter run -d macos
```

## 사용 방법

### Flutter 앱 버튼 설명

1. **실행**: 데몬 프로세스를 백그라운드로 실행 (detached 모드)
2. **상태 확인**: 현재 실행 중인 데몬 프로세스 확인 (PID, CPU, MEM)
3. **로그 보기**: 데몬이 기록한 로그 파일 내용 확인 (마지막 20줄)
4. **종료**: 데몬 프로세스 종료 (SIGTERM)
5. **로그 초기화**: 로그 파일 삭제
6. **앱 종료**: Flutter 앱 종료 (데몬은 계속 실행됨)

### 실험 시나리오

1. 데몬 바이너리를 빌드합니다 (위 명령어 사용)
2. Flutter 앱을 실행합니다
3. **실행** 버튼을 눌러 데몬을 시작합니다
4. **로그 보기**로 데몬이 1초마다 heartbeat를 기록하는지 확인합니다
5. **앱 종료** 버튼으로 Flutter 앱을 종료합니다
6. Flutter 앱을 다시 실행합니다
7. **상태 확인**으로 데몬이 여전히 실행 중인지 확인합니다
8. **로그 보기**로 앱이 종료된 동안에도 로그가 계속 기록되었는지 확인합니다

✅ **결과**: Flutter 앱이 죽어도 Dart 바이너리는 독립적으로 계속 실행됩니다!

## 데몬 동작

데몬 프로세스는 다음과 같이 동작합니다:

- 1초마다 타임스탬프와 "Heartbeat" 메시지를 로그 파일에 기록
- `SIGTERM` 또는 `SIGINT` 시그널을 받으면 정상 종료
- 로그 파일: `logs/daemon_log.txt`

로그 형식:
```
[2025-10-23 14:45:01] Daemon started (PID: 12345)
[2025-10-23 14:45:02] Heartbeat
[2025-10-23 14:45:03] Heartbeat
...
```

## 기술 세부사항

### ProcessStartMode.detached

데몬이 Flutter 앱과 독립적으로 실행되는 핵심 기술:

```dart
final process = await Process.start(
  binaryPath,
  [logPath],
  mode: ProcessStartMode.detached,  // 부모 프로세스와 독립
  workingDirectory: getProjectRoot(),
);
```

- `detached` 모드: 부모 프로세스(Flutter 앱) 종료 시에도 자식 프로세스(데몬) 계속 실행
- `normal` 모드: 부모 종료 시 자식도 함께 종료

### 프로세스 확인

macOS에서 프로세스 검색:

```bash
ps aux | grep daemon | grep -v grep
```

### 경로 설정

macOS 샌드박스 환경에서 실행되므로 프로젝트 루트 경로가 하드코딩되어 있습니다.

다른 환경에서 실행하려면 `lib/services/daemon_manager.dart`의 `hardcodedPath`를 수정하세요:

```dart
const hardcodedPath = '/your/project/path/test_dart_cli';
```

## 요구사항

- Flutter SDK
- Dart SDK
- macOS (현재 macOS 기준으로 구현됨)

## 라이선스

MIT

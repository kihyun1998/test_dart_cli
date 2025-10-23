\.PHONY: all clean daemon flutter-build copy-daemon dmg updater-zip install-appdmg

# 앱 이름 및 경로
APP_NAME = test_dart_cli
DAEMON_SOURCE = bin/daemon.dart
DAEMON_BINARY = bin_output/daemon
FLUTTER_BUILD_DIR = build/macos/Build/Products/Release
APP_BUNDLE = $(FLUTTER_BUILD_DIR)/$(APP_NAME).app
APP_MACOS_DIR = $(APP_BUNDLE)/Contents/MacOS
DMG_OUTPUT = app_out/$(APP_NAME).dmg
UPDATER_ZIP = app_out/$(APP_NAME)_updater.zip

# 기본 타겟: 전체 빌드
all: daemon flutter-build copy-daemon dmg updater-zip
	@echo "✅ 빌드 완료: $(DMG_OUTPUT)"
	@echo "✅ 업데이터 ZIP 완료: $(UPDATER_ZIP)"

# 1. Dart 데몬 바이너리 컴파일
daemon:
	@echo "🔨 Dart 데몬 컴파일 중..."
	@mkdir -p bin_output
	dart compile exe $(DAEMON_SOURCE) -o $(DAEMON_BINARY)
	@echo "✅ 데몬 컴파일 완료: $(DAEMON_BINARY)"

# 2. Flutter macOS 앱 빌드
flutter-build:
	@echo "🔨 Flutter 앱 빌드 중..."
	flutter build macos --release
	@echo "✅ Flutter 빌드 완료: $(APP_BUNDLE)"

# 3. 데몬 바이너리를 .app 번들에 복사
copy-daemon:
	@echo "📦 데몬 바이너리를 앱 번들에 복사 중..."
	cp $(DAEMON_BINARY) $(APP_MACOS_DIR)/
	@echo "✅ 복사 완료: $(APP_MACOS_DIR)/daemon"

# 4. DMG 생성 (appdmg 사용)
dmg:
	@echo "💿 DMG 생성 중..."
	@mkdir -p app_out
	@rm -f $(DMG_OUTPUT)
	appdmg installer/config.json $(DMG_OUTPUT)
	@echo "✅ DMG 생성 완료: $(DMG_OUTPUT)"

# 5. 업데이터용 ZIP 생성
updater-zip:
	@echo "📦 업데이터 ZIP 생성 중..."
	@mkdir -p app_out
	@rm -f $(UPDATER_ZIP)
	cd $(FLUTTER_BUILD_DIR) && zip -r ../../../../../$(UPDATER_ZIP) $(APP_NAME).app
	@echo "✅ 업데이터 ZIP 생성 완료: $(UPDATER_ZIP)"

# appdmg 설치 (필요시)
install-appdmg:
	@echo "📥 appdmg 설치 중..."
	npm install -g appdmg

# 클린업
clean:
	@echo "🧹 빌드 파일 정리 중..."
	rm -rf build/
	rm -rf bin_output/
	rm -rf app_out/
	rm -rf logs/
	flutter clean
	@echo "✅ 정리 완료"

# 개발용: 데몬만 재컴파일
rebuild-daemon: daemon copy-daemon
	@echo "✅ 데몬 재빌드 완료"

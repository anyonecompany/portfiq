# Flutter 배포 설정

## Android (Play Store)

### 1회 설정 (수동)

1. Google Play Console → API 액세스 → 서비스 계정 생성
2. JSON 키 다운로드
3. GitHub Secrets에 추가:
   - `PLAY_STORE_JSON_KEY`: JSON 키 내용 전체
   - `ANDROID_PACKAGE_NAME`: com.portfiq.app (실제 패키지명)
   - `KEYSTORE_BASE64`: `base64 keystore.jks` 결과
   - `KEYSTORE_PASSWORD`: 키스토어 비밀번호
   - `KEY_ALIAS`: 키 별칭
   - `KEY_PASSWORD`: 키 비밀번호

### 자동 배포 흐름

`main` push → GitHub Actions:
1. flutter analyze + test
2. flutter build appbundle --release
3. fastlane internal (내부 테스트 트랙) — PLAY_STORE_JSON_KEY 설정 시

프로덕션 배포: Play Console에서 내부 → 프로덕션 승격 (수동)

## iOS (App Store)

### 현재 방식
- macOS 러너에서 `flutter build ios --release --no-codesign` (CI)
- 프로덕션 빌드: 로컬 macOS에서 Xcode로 Archive → App Store Connect 업로드

### 자동화 요구사항 (미구현)
- macOS self-hosted runner 또는 GitHub Actions macOS runner
- Apple Developer 인증서 + 프로비저닝 프로파일
- App Store Connect API Key
- Fastlane match 설정

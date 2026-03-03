# Google Maps API 키 발급 방법

## 1. Google Cloud Console 접속

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. Google 계정으로 로그인

## 2. 프로젝트 생성

1. 상단 메뉴에서 **프로젝트 선택** 클릭
2. **새 프로젝트** 클릭
3. 프로젝트 이름 입력 (예: `SafeTrip Maps`)
4. **만들기** 클릭
5. 프로젝트가 생성될 때까지 대기 (약 1-2분)

## 3. 결제 계정 설정

⚠️ **중요**: Google Maps API는 무료 할당량이 있지만, 결제 계정 등록이 필요합니다.

1. 좌측 메뉴에서 **결제** 클릭
2. **결제 계정 연결** 클릭
3. 신용카드 정보 입력 (무료 할당량 내에서는 요금이 청구되지 않음)
4. 결제 계정 생성 완료

**무료 할당량:**
- Maps SDK for Android: 월 $200 크레딧 (약 28,000회 로드)
- Maps SDK for iOS: 월 $200 크레딧 (약 28,000회 로드)
- 일반적으로 소규모 앱에서는 무료 할당량으로 충분합니다.

## 4. Maps SDK 활성화

### Android용

1. 좌측 메뉴에서 **API 및 서비스** > **라이브러리** 클릭
2. 검색창에 **"Maps SDK for Android"** 입력
3. **Maps SDK for Android** 선택
4. **사용 설정** 클릭

### iOS용 (나중에 필요 시)

1. 검색창에 **"Maps SDK for iOS"** 입력
2. **Maps SDK for iOS** 선택
3. **사용 설정** 클릭

## 5. API 키 생성

### Android용 API 키

1. 좌측 메뉴에서 **API 및 서비스** > **사용자 인증 정보** 클릭
2. 상단 **+ 사용자 인증 정보 만들기** > **API 키** 클릭
3. API 키가 생성됨 (복사해두기)
4. **제한사항 설정** 클릭 (보안을 위해 권장)

### API 키 제한 설정 (권장)

1. **애플리케이션 제한사항**:
   - **Android 앱** 선택
   - **+ 항목 추가** 클릭
   - 패키지 이름 입력: `com.example.test_app_mqtt`
   - SHA-1 인증서 지문 입력 (아래 참고)

2. **API 제한사항**:
   - **키 제한** 선택
   - **Maps SDK for Android** 체크
   - **저장** 클릭

### SHA-1 인증서 지문 확인 방법

**Windows (PowerShell):**
```powershell
cd C:\PROJECT\SafeTrip\TEST_APP_MQTT\android
.\gradlew signingReport
```

**macOS/Linux:**
```bash
cd TEST_APP_MQTT/android
./gradlew signingReport
```

출력에서 `SHA1:` 값을 복사합니다.

**또는 keytool 사용:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

## 6. AndroidManifest.xml에 API 키 추가

`TEST_APP_MQTT/android/app/src/main/AndroidManifest.xml` 파일을 열고:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="여기에_발급받은_API_키_입력"/>
```

## 7. iOS용 API 키 (선택사항)

### iOS용 API 키 생성

1. **API 및 서비스** > **사용자 인증 정보** 클릭
2. **+ 사용자 인증 정보 만들기** > **API 키** 클릭
3. **제한사항 설정** 클릭
4. **애플리케이션 제한사항**: **iOS 앱** 선택
5. **번들 ID** 입력: `com.example.testAppMqtt`
6. **API 제한사항**: **Maps SDK for iOS** 체크

### iOS 설정

`ios/Runner/AppDelegate.swift` 파일에 추가:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 8. API 키 보안 설정

### IP 주소 제한 (서버용)

서버에서 Google Maps API를 사용하는 경우:
1. **애플리케이션 제한사항**: **IP 주소** 선택
2. 서버 IP 주소 입력

### HTTP 리퍼러 제한 (웹용)

웹에서 사용하는 경우:
1. **애플리케이션 제한사항**: **HTTP 리퍼러(웹사이트)** 선택
2. 허용할 도메인 입력 (예: `https://yourdomain.com/*`)

## 9. 사용량 모니터링

1. 좌측 메뉴에서 **API 및 서비스** > **대시보드** 클릭
2. API 사용량 확인
3. 할당량 초과 시 알림 설정 가능

## 10. 문제 해결

### API 키 오류 발생 시

1. **API 키가 올바른지 확인**
2. **Maps SDK가 활성화되었는지 확인**
3. **API 키 제한 설정 확인** (패키지 이름, SHA-1 등)
4. **결제 계정이 연결되었는지 확인**

### 로그 확인

Android Logcat에서 확인:
```
E/Google Maps Android API: API key not found
```

### 테스트

1. 앱 재빌드: `flutter clean && flutter pub get`
2. 앱 실행: `flutter run`
3. 지도가 정상적으로 표시되는지 확인

## 참고 자료

- [Google Maps Platform 문서](https://developers.google.com/maps/documentation)
- [Maps SDK for Android 가이드](https://developers.google.com/maps/documentation/android-sdk/start)
- [API 키 보안 모범 사례](https://developers.google.com/maps/api-security-best-practices)


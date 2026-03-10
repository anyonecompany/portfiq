import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// FCM 푸시 알림 서비스.
///
/// Firebase Messaging 토큰을 관리하고 백엔드에 등록한다.
/// Firebase가 초기화되지 않은 경우 graceful하게 스킵한다.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  FirebaseMessaging? _messaging;
  String? _currentToken;

  /// Firebase Messaging 초기화 + 토큰 등록.
  ///
  /// 앱 시작 시 한 번 호출. Firebase 미설정 시 로그만 남기고 스킵.
  Future<void> initialize() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // 토큰 가져오기 + 백엔드 등록
      await _registerToken();

      // 토큰 갱신 리스너
      _messaging!.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('[PushService] Token refreshed');
        }
        _currentToken = newToken;
        _sendTokenToBackend(newToken);
      });

      // Foreground 메시지 수신 리스너
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      if (kDebugMode) {
        print('[PushService] Initialized, token: ${_currentToken?.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PushService] Firebase 미설정 또는 초기화 실패: $e');
      }
    }
  }

  /// OS 푸시 권한 요청.
  ///
  /// Returns true if permission was granted.
  Future<bool> requestPermission() async {
    if (_messaging == null) {
      if (kDebugMode) {
        print('[PushService] Firebase 미초기화, 권한 요청 스킵');
      }
      return false;
    }

    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        // 권한 획득 후 토큰 재등록 (iOS에서는 권한 후 토큰이 바뀔 수 있음)
        await _registerToken();
      }

      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('[PushService] 권한 요청 실패: $e');
      }
      return false;
    }
  }

  /// 현재 FCM 토큰.
  String? get currentToken => _currentToken;

  Future<void> _registerToken() async {
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        _currentToken = token;
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PushService] 토큰 가져오기 실패: $e');
      }
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient.instance.post(
        '/api/v1/etf/devices/register',
        data: {
          'device_id': ApiClient.instance.deviceId,
          'push_token': token,
        },
      );
      if (kDebugMode) {
        print('[PushService] 토큰 백엔드 등록 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PushService] 토큰 백엔드 등록 실패: $e');
      }
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('[PushService] Foreground message: ${message.notification?.title}');
    }
    // TODO: 인앱 알림 UI 표시 (snackbar 등)
  }
}

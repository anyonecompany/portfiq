import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'shared/services/api_client.dart';
import 'shared/services/push_service.dart';
import 'shared/tracking/event_tracker.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  AppConfig.initialize(Flavor.production);

  // Generate a stable device ID from platform
  final deviceIdInfo = await _getDeviceId();
  final deviceId = deviceIdInfo.$1;
  final isFirstOpen = deviceIdInfo.$2;
  ApiClient.instance.init(deviceId: deviceId);

  // Initialize event tracker with Hive persistence + 30s timer
  await EventTracker.instance.initialize(AppConfig.flavor, deviceId);
  EventTracker.instance.track('app_opened', properties: {
    'is_first_open': isFirstOpen,
    'platform': defaultTargetPlatform.name,
  });

  // Firebase 초기화 (미설정 시 graceful 스킵)
  await _initFirebase();

  // FCM 푸시 서비스 초기화 + 토큰 등록
  await PushService.instance.initialize();

  runApp(const PortfiqApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      print('[main] Firebase 초기화 완료');
    }
  } catch (e) {
    if (kDebugMode) {
      print('[main] Firebase 초기화 스킵 (미설정): $e');
    }
  }
}

Future<(String, bool)> _getDeviceId() async {
  final box = Hive.box('settings');
  var id = box.get('device_id') as String?;
  var isFirstOpen = false;
  if (id == null) {
    id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await box.put('device_id', id);
    isFirstOpen = true;
  }
  return (id, isFirstOpen);
}

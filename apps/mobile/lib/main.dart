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
  AppConfig.initialize(Flavor.local);

  // Generate a stable device ID from platform
  final deviceId = await _getDeviceId();
  ApiClient.instance.init(deviceId: deviceId);

  // Initialize event tracker with session management
  EventTracker.instance.initialize(AppConfig.flavor, deviceId);

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

Future<String> _getDeviceId() async {
  final box = Hive.box('settings');
  var id = box.get('device_id') as String?;
  if (id == null) {
    id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await box.put('device_id', id);
  }
  return id;
}

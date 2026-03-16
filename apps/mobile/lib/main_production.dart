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

  final settingsBox = Hive.box('settings');
  var deviceId = settingsBox.get('device_id') as String?;
  var isFirstOpen = false;
  if (deviceId == null) {
    deviceId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
    await settingsBox.put('device_id', deviceId);
    isFirstOpen = true;
  }
  ApiClient.instance.init(deviceId: deviceId);

  // Initialize event tracker with Hive persistence + 30s timer
  await EventTracker.instance.initialize(AppConfig.flavor, deviceId);
  EventTracker.instance.track('app_opened', properties: {
    'is_first_open': isFirstOpen,
    'platform': defaultTargetPlatform.name,
  });

  // Firebase 초기화
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) {
      print('[main_production] Firebase 초기화 스킵: $e');
    }
  }

  // FCM 푸시 서비스 초기화
  await PushService.instance.initialize();

  runApp(const PortfiqApp());
}

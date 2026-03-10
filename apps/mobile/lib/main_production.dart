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
  if (deviceId == null) {
    deviceId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
    await settingsBox.put('device_id', deviceId);
  }
  ApiClient.instance.init(deviceId: deviceId);

  // Initialize event tracker with session management
  EventTracker.instance.initialize(AppConfig.flavor, deviceId);

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

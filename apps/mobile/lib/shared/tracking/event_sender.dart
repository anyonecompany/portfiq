import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../services/api_client.dart';
import 'event_models.dart';

/// Sends batched tracking events to the analytics backend.
class EventSender {
  EventSender() : _dio = Dio();

  final Dio _dio;

  /// POST a batch of events to `/api/v1/analytics/events`.
  /// Failures are caught and logged — never crashes the app.
  Future<bool> sendBatch(List<TrackingEvent> events) async {
    if (events.isEmpty) return true;

    try {
      final deviceId = ApiClient.instance.deviceId;
      final response = await _postBatch(
        deviceId: deviceId,
        eventsPayload: events.map((e) => e.toJson()).toList(),
      );
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        try {
          final deviceId = ApiClient.instance.deviceId;
          final legacyResponse = await _postBatch(
            deviceId: deviceId,
            eventsPayload: events.map((e) => e.toLegacyJson()).toList(),
          );
          return legacyResponse.statusCode != null &&
              legacyResponse.statusCode! >= 200 &&
              legacyResponse.statusCode! < 300;
        } on DioException catch (retryError) {
          if (kDebugMode) {
            print(
              '[EventSender] Legacy retry failed: '
              '${retryError.response?.statusCode ?? retryError.message}',
            );
          }
        }
      }
      if (kDebugMode) {
        print(
          '[EventSender] Failed to send batch: '
          '${e.response?.statusCode ?? e.message}',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[EventSender] Unexpected error: $e');
      return false;
    }
  }

  Future<Response<dynamic>> _postBatch({
    required String? deviceId,
    required List<Map<String, dynamic>> eventsPayload,
  }) {
    return _dio.post(
      '${AppConfig.apiBaseUrl}/api/v1/analytics/events',
      data: {
        'device_id': deviceId,
        'events': eventsPayload,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (deviceId != null) 'X-Device-ID': deviceId,
        },
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }
}

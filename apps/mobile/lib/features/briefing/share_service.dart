import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service responsible for capturing a share card widget as PNG and sharing it.
class ShareService {
  ShareService._();

  /// Captures the [RepaintBoundary] identified by [repaintKey] as a PNG image,
  /// saves it to a temp file, and opens the system share sheet.
  ///
  /// Returns `true` if the share sheet was opened successfully.
  static Future<bool> captureAndShare(
    GlobalKey repaintKey,
    String briefingTitle,
  ) async {
    return captureAndShareWithText(
      repaintKey,
      '포트픽 AI 브리핑: $briefingTitle\n\n다운로드: https://portfiq.com',
      filePrefix: 'portfiq_briefing',
    );
  }

  /// Generic capture-and-share with custom share text and file prefix.
  ///
  /// Returns `true` if the share sheet was opened successfully.
  static Future<bool> captureAndShareWithText(
    GlobalKey repaintKey,
    String shareText, {
    String filePrefix = 'portfiq_share',
  }) async {
    try {
      // Find the render object
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        return false;
      }

      // Capture at 1x pixel ratio (the widget is already sized at target resolution)
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return false;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      // Share via system share sheet
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );

      return true;
    } catch (e) {
      if (kDebugMode) print('[ShareService] Error capturing/sharing: $e');
      return false;
    }
  }
}

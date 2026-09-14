import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DetectedYapePayment {
  final double amount;
  final String eventId;
  final DateTime detectedAt;
  final String? title;
  final String? text;

  const DetectedYapePayment({
    required this.amount,
    required this.eventId,
    required this.detectedAt,
    this.title,
    this.text,
  });

  factory DetectedYapePayment.fromMap(Map<Object?, Object?> map) {
    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.parse(rawAmount.toString());

    final timestamp = map['timestamp'];
    final detectedAt = timestamp is num
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())
        : DateTime.now();

    return DetectedYapePayment(
      amount: amount,
      eventId: map['eventId'].toString(),
      detectedAt: detectedAt,
      title: map['title']?.toString(),
      text: map['text']?.toString(),
    );
  }
}

class YapeDiagnostic {
  final String title;
  final String text;
  final String bigText;
  final DateTime? capturedAt;

  const YapeDiagnostic({
    required this.title,
    required this.text,
    required this.bigText,
    required this.capturedAt,
  });

  bool get isEmpty => title.isEmpty && text.isEmpty && bigText.isEmpty;

  factory YapeDiagnostic.fromMap(Map<Object?, Object?> map) {
    final rawTimestamp = map['timestamp'];
    return YapeDiagnostic(
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      bigText: map['bigText']?.toString() ?? '',
      capturedAt: rawTimestamp is num
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt())
          : null,
    );
  }
}

class YapeNotificationService {
  YapeNotificationService._();

  static final YapeNotificationService instance = YapeNotificationService._();

  static const MethodChannel _channel = MethodChannel(
    'motocaja/yape_notifications',
  );

  final ValueNotifier<int> pendingPaymentSignal = ValueNotifier<int>(0);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pendingYapePaymentAvailable') {
        pendingPaymentSignal.value++;
      }
    });
    _initialized = true;
  }

  Future<bool> isNotificationAccessGranted() async {
    return await _channel.invokeMethod<bool>('isNotificationAccessGranted') ??
        false;
  }

  Future<void> openNotificationAccessSettings() async {
    await _channel.invokeMethod<void>('openNotificationAccessSettings');
  }

  Future<bool> getDetectionEnabled() async {
    return await _channel.invokeMethod<bool>('getDetectionEnabled') ?? false;
  }

  Future<void> setDetectionEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setDetectionEnabled', {
      'enabled': enabled,
    });
  }

  Future<YapeDiagnostic?> getLastDiagnostic() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'getLastDiagnostic',
    );
    if (raw == null) return null;
    return YapeDiagnostic.fromMap(raw);
  }

  Future<DetectedYapePayment?> consumePendingPayment() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'consumePendingPayment',
    );
    if (raw == null) return null;
    return DetectedYapePayment.fromMap(raw);
  }
}

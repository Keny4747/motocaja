import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DetectedPayment {
  final double amount;
  final String eventId;
  final DateTime detectedAt;
  final String paymentMethod;
  final String sourceName;
  final String? title;
  final String? text;

  const DetectedPayment({
    required this.amount,
    required this.eventId,
    required this.detectedAt,
    required this.paymentMethod,
    required this.sourceName,
    this.title,
    this.text,
  });

  factory DetectedPayment.fromMap(Map<Object?, Object?> map) {
    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.parse(rawAmount.toString());

    final timestamp = map['timestamp'];
    final detectedAt = timestamp is num
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())
        : DateTime.now();

    final paymentMethod = map['paymentMethod']?.toString().trim();
    final sourceName = map['sourceName']?.toString().trim();

    return DetectedPayment(
      amount: amount,
      eventId: map['eventId'].toString(),
      detectedAt: detectedAt,
      paymentMethod:
          paymentMethod == null || paymentMethod.isEmpty ? 'Yape' : paymentMethod,
      sourceName: sourceName == null || sourceName.isEmpty
          ? (paymentMethod == null || paymentMethod.isEmpty
              ? 'Yape'
              : paymentMethod)
          : sourceName,
      title: map['title']?.toString(),
      text: map['text']?.toString(),
    );
  }
}

class PaymentDiagnostic {
  final String sourceName;
  final String packageName;
  final String title;
  final String text;
  final String bigText;
  final DateTime? capturedAt;

  const PaymentDiagnostic({
    required this.sourceName,
    required this.packageName,
    required this.title,
    required this.text,
    required this.bigText,
    required this.capturedAt,
  });

  bool get isEmpty => title.isEmpty && text.isEmpty && bigText.isEmpty;

  factory PaymentDiagnostic.fromMap(Map<Object?, Object?> map) {
    final rawTimestamp = map['timestamp'];
    return PaymentDiagnostic(
      sourceName: map['sourceName']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      bigText: map['bigText']?.toString() ?? '',
      capturedAt: rawTimestamp is num
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt())
          : null,
    );
  }
}

class PaymentDiagnosticEvent {
  final String sourceName;
  final String packageName;
  final String appLabel;
  final String title;
  final String text;
  final String details;
  final String decision;
  final DateTime? capturedAt;
  final DateTime? postedAt;
  final DateTime? notificationWhen;
  final int notificationId;
  final String tag;
  final String channelId;
  final String category;
  final double? amount;

  const PaymentDiagnosticEvent({
    required this.sourceName,
    required this.packageName,
    required this.appLabel,
    required this.title,
    required this.text,
    required this.details,
    required this.decision,
    required this.capturedAt,
    required this.postedAt,
    required this.notificationWhen,
    required this.notificationId,
    required this.tag,
    required this.channelId,
    required this.category,
    required this.amount,
  });

  factory PaymentDiagnosticEvent.fromMap(Map<Object?, Object?> map) {
    DateTime? timestamp(Object? value) {
      if (value is num && value.toInt() > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    final rawAmount = map['amount'];
    return PaymentDiagnosticEvent(
      sourceName: map['sourceName']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      appLabel: map['appLabel']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      decision: map['decision']?.toString() ?? '',
      capturedAt: timestamp(map['capturedAt']),
      postedAt: timestamp(map['postedAt']),
      notificationWhen: timestamp(map['notificationWhen']),
      notificationId: map['notificationId'] is num
          ? (map['notificationId'] as num).toInt()
          : -1,
      tag: map['tag']?.toString() ?? '',
      channelId: map['channelId']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      amount: rawAmount is num ? rawAmount.toDouble() : null,
    );
  }
}

// Alias de compatibilidad con el nombre usado en versiones anteriores.
typedef DetectedYapePayment = DetectedPayment;
typedef YapeDiagnostic = PaymentDiagnostic;

class YapeNotificationService {
  YapeNotificationService._();

  static final YapeNotificationService instance = YapeNotificationService._();

  // El nombre del canal se conserva para no romper instalaciones existentes.
  static const MethodChannel _channel = MethodChannel(
    'motocaja/yape_notifications',
  );

  final ValueNotifier<int> pendingPaymentSignal = ValueNotifier<int>(0);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pendingPaymentAvailable' ||
          call.method == 'pendingYapePaymentAvailable') {
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

  Future<PaymentDiagnostic?> getLastDiagnostic() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'getLastDiagnostic',
    );
    if (raw == null) return null;
    return PaymentDiagnostic.fromMap(raw);
  }

  Future<DateTime> startRawDiagnosticCapture({
    Duration duration = const Duration(minutes: 2),
  }) async {
    final until = await _channel.invokeMethod<int>('startRawDiagnosticCapture', {
      'durationMs': duration.inMilliseconds,
    });
    return until == null
        ? DateTime.now().add(duration)
        : DateTime.fromMillisecondsSinceEpoch(until);
  }

  Future<void> stopRawDiagnosticCapture() async {
    await _channel.invokeMethod<void>('stopRawDiagnosticCapture');
  }

  Future<bool> isRawDiagnosticCaptureActive() async {
    return await _channel.invokeMethod<bool>('isRawDiagnosticCaptureActive') ??
        false;
  }

  Future<List<PaymentDiagnosticEvent>> getDiagnosticHistory() async {
    final raw = await _channel.invokeListMethod<Object?>(
      'getDiagnosticHistory',
    );
    if (raw == null) return const [];

    return raw
        .whereType<Map<Object?, Object?>>()
        .map(PaymentDiagnosticEvent.fromMap)
        .toList(growable: false);
  }

  Future<void> clearDiagnosticHistory() async {
    await _channel.invokeMethod<void>('clearDiagnosticHistory');
  }

  Future<DetectedPayment?> consumePendingPayment() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'consumePendingPayment',
    );
    if (raw == null) return null;
    return DetectedPayment.fromMap(raw);
  }
}

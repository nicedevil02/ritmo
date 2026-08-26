import 'package:ritmo/core/logging/ritmo_logger.dart';

/// Safely runs synchronous [body], catching, logging, and tolerating non-fatal exceptions (P-A).
/// Returns [fallback] (defaulting to null) if an exception is thrown.
T? tolerate<T>(
  T Function() body, {
  required String context,
  T? fallback,
}) {
  try {
    return body();
  } catch (e, st) {
    RitmoLog.warning(context, 'Tolerated non-fatal exception: $e', e, st);
    return fallback;
  }
}

/// Safely runs asynchronous [body], catching, logging, and tolerating non-fatal exceptions (P-A).
/// Returns [fallback] (defaulting to null) if an exception is thrown.
Future<T?> tolerateAsync<T>(
  Future<T> Function() body, {
  required String context,
  T? fallback,
}) async {
  try {
    return await body();
  } catch (e, st) {
    RitmoLog.warning(context, 'Tolerated non-fatal async exception: $e', e, st);
    return fallback;
  }
}

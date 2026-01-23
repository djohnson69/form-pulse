import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Centralized error logging utility.
///
/// Use this instead of silent catch blocks or print statements.
/// Provides consistent error handling across the app.
class ErrorLogger {
  ErrorLogger._();

  /// Log an error with context information.
  ///
  /// [error] - The error or exception that occurred
  /// [stackTrace] - Optional stack trace
  /// [context] - Description of where/why the error occurred
  /// [fatal] - If true, this is a critical error that may affect app stability
  static void log(
    Object error, {
    StackTrace? stackTrace,
    required String context,
    bool fatal = false,
  }) {
    final message = '[$context] ${fatal ? "FATAL: " : ""}$error';

    // Always log to developer console
    developer.log(
      message,
      error: error,
      stackTrace: stackTrace,
      name: 'ErrorLogger',
      level: fatal ? 1000 : 900,
    );

    // In debug mode, also print to console for visibility
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (stackTrace != null) {
        debugPrint('Stack trace:\n$stackTrace');
      }
    }

    // TODO: In production, send to error reporting service (Sentry, Crashlytics, etc.)
    // if (!kDebugMode) {
    //   ErrorReportingService.captureException(error, stackTrace: stackTrace);
    // }
  }

  /// Log a warning (non-fatal issue that should be investigated)
  static void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    required String context,
  }) {
    final fullMessage = '[$context] WARNING: $message';

    developer.log(
      fullMessage,
      error: error,
      stackTrace: stackTrace,
      name: 'ErrorLogger',
      level: 800,
    );

    if (kDebugMode) {
      debugPrint('WARN: $fullMessage');
    }
  }

  /// Log info-level messages (useful for debugging)
  static void info(String message, {required String context}) {
    developer.log(
      '[$context] $message',
      name: 'ErrorLogger',
      level: 500,
    );
  }

  /// Wrap an async operation with error logging.
  ///
  /// Returns null and logs the error if the operation fails.
  /// Use this instead of try-catch with empty catch blocks.
  static Future<T?> tryAsync<T>(
    Future<T> Function() operation, {
    required String context,
    T? fallback,
  }) async {
    try {
      return await operation();
    } catch (e, st) {
      log(e, stackTrace: st, context: context);
      return fallback;
    }
  }

  /// Wrap a sync operation with error logging.
  ///
  /// Returns null and logs the error if the operation fails.
  static T? trySync<T>(
    T Function() operation, {
    required String context,
    T? fallback,
  }) {
    try {
      return operation();
    } catch (e, st) {
      log(e, stackTrace: st, context: context);
      return fallback;
    }
  }
}

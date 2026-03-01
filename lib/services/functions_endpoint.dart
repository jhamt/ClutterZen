import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FunctionsConfigException implements Exception {
  FunctionsConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FunctionsRequestException implements Exception {
  FunctionsRequestException({
    required this.message,
    this.statusCode,
    this.uri,
    this.serverMessage,
  });

  final String message;
  final int? statusCode;
  final Uri? uri;
  final String? serverMessage;

  @override
  String toString() => message;
}

class FunctionsEndpoint {
  static Uri buildUri({
    required String baseUrl,
    required String path,
  }) {
    final trimmedBase = baseUrl.trim();
    if (trimmedBase.isEmpty) {
      throw FunctionsConfigException(
        'FIREBASE_FUNCTIONS_URL is not configured. Set it in --dart-define or .env.public.',
      );
    }

    final baseUri = Uri.tryParse(trimmedBase);
    if (baseUri == null ||
        !(baseUri.isScheme('https') || baseUri.isScheme('http')) ||
        baseUri.host.isEmpty) {
      throw FunctionsConfigException(
        'FIREBASE_FUNCTIONS_URL is invalid. Use a full URL like https://<region>-<project>.cloudfunctions.net/api',
      );
    }

    final normalizedBasePath = _normalizeBasePath(baseUri.path);
    final normalizedPath = _normalizeEndpointPath(path);
    final mergedPath = [normalizedBasePath, normalizedPath]
        .where((segment) => segment.isNotEmpty)
        .join('/');

    return baseUri.replace(path: '/$mergedPath');
  }

  static bool isLikelyHtml(http.Response response) {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final body = response.body.toLowerCase();
    return contentType.contains('text/html') ||
        body.contains('<html') ||
        body.contains('<!doctype html');
  }

  static FunctionsRequestException buildRequestException({
    required http.Response response,
    required Uri uri,
    String? fallbackMessage,
  }) {
    final userMessage = toUserMessage(
      response: response,
      fallbackMessage: fallbackMessage,
    );
    final serverMessage = _extractServerMessage(response);

    if (kDebugMode) {
      final raw = response.body.trim();
      if (raw.isNotEmpty) {
        debugPrint(
          'Functions endpoint failed (${response.statusCode}) $uri: ${_sanitize(raw, maxLength: 500)}',
        );
      }
    }

    return FunctionsRequestException(
      message: userMessage,
      statusCode: response.statusCode,
      uri: uri,
      serverMessage: serverMessage,
    );
  }

  static String toUserMessage({
    required http.Response response,
    String? fallbackMessage,
  }) {
    final statusCode = response.statusCode;
    if (statusCode == 404) {
      return 'Server endpoint not found (404). Check FIREBASE_FUNCTIONS_URL and deployed Cloud Functions.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Authentication failed. Please sign in again.';
    }
    if (statusCode >= 500) {
      return 'Server is temporarily unavailable ($statusCode). Please try again.';
    }

    final serverMessage = _extractServerMessage(response);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return 'Request failed ($statusCode): $serverMessage';
    }

    if (fallbackMessage != null && fallbackMessage.trim().isNotEmpty) {
      return '$fallbackMessage ($statusCode).';
    }
    return 'Request failed ($statusCode). Please try again.';
  }

  static String _normalizeBasePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    return trimmed.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  static String _normalizeEndpointPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    return trimmed.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  static String? _extractServerMessage(http.Response response) {
    if (isLikelyHtml(response)) return null;

    final raw = response.body.trim();
    if (raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return _sanitize(error);
        }
        if (error is Map<String, dynamic>) {
          final nestedMessage = error['message'];
          if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
            return _sanitize(nestedMessage);
          }
        }

        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _sanitize(message);
        }
      }
    } catch (_) {
      // Ignore parsing failures and fallback below.
    }

    return _sanitize(raw);
  }

  static String _sanitize(String value, {int maxLength = 220}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength)}...';
  }
}

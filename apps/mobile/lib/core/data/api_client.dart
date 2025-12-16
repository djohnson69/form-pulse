import 'package:dio/dio.dart';
import 'package:shared/shared.dart';

/// Simple API client wrapper around Dio that targets the Form Bridge backend.
class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstants.baseUrlDev,
              connectTimeout: ApiConstants.connectionTimeout,
              receiveTimeout: ApiConstants.receiveTimeout,
              headers: {
                ApiConstants.acceptHeader: ApiConstants.jsonContentType,
              },
            ),
          );

  final Dio _dio;

  Dio get raw => _dio;
}

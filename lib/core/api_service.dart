import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final int statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, int statusCode) {
    String msg = json['message'] ?? '';
    if (json['errors'] != null && json['errors'] is Map) {
      final Map errorsMap = json['errors'];
      final List<String> errMsgs = [];
      errorsMap.forEach((key, val) {
        if (val is List && val.isNotEmpty) {
          errMsgs.add(val.first.toString());
        } else if (val != null) {
          errMsgs.add(val.toString());
        }
      });
      if (errMsgs.isNotEmpty) {
        msg = errMsgs.join(' ');
      }
    }

    return ApiResponse(
      success: json['success'] ?? (statusCode >= 200 && statusCode < 300),
      message: msg.isNotEmpty
          ? msg
          : (statusCode >= 200 && statusCode < 300 ? 'Success' : 'Request failed ($statusCode)'),
      data: json['data'],
      statusCode: statusCode,
    );
  }
}

class ApiService {
  static Map<String, String> _getHeaders({bool withAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static ApiResponse _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      StorageService.clearSession();
    }
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiResponse.fromJson(json, response.statusCode);
    } catch (_) {
      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: response.statusCode >= 200 && response.statusCode < 300
            ? 'Success'
            : 'Server error (${response.statusCode})',
        data: null,
        statusCode: response.statusCode,
      );
    }
  }

  static Future<ApiResponse> get(String url, {bool withAuth = true}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _getHeaders(withAuth: withAuth))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Unable to connect to server.',
        statusCode: 500,
      );
    }
  }

  static Future<ApiResponse> post(String url, {Map<String, dynamic>? body, bool withAuth = true}) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _getHeaders(withAuth: withAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Unable to connect to server.',
        statusCode: 500,
      );
    }
  }

  static Future<ApiResponse> put(String url, {Map<String, dynamic>? body, bool withAuth = true}) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: _getHeaders(withAuth: withAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Unable to connect to server.',
        statusCode: 500,
      );
    }
  }

  static Future<ApiResponse> patch(String url, {Map<String, dynamic>? body, bool withAuth = true}) async {
    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: _getHeaders(withAuth: withAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Unable to connect to server.',
        statusCode: 500,
      );
    }
  }

  static Future<ApiResponse> delete(String url, {bool withAuth = true}) async {
    try {
      final response = await http
          .delete(Uri.parse(url), headers: _getHeaders(withAuth: withAuth))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: Unable to connect to server.',
        statusCode: 500,
      );
    }
  }

  static Future<ApiResponse> multipartPost(
    String url, {
    Map<String, String>? fields,
    List<File>? files,
    String fileParamName = 'images[]',
    bool withAuth = true,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));

      // Add headers
      final headers = _getHeaders(withAuth: withAuth);
      headers.remove('Content-Type'); // Let MultipartRequest handle boundary
      request.headers.addAll(headers);

      // Add text fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Add files
      if (files != null) {
        for (final file in files) {
          request.files.add(await http.MultipartFile.fromPath(fileParamName, file.path));
        }
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error during upload.',
        statusCode: 500,
      );
    }
  }
}

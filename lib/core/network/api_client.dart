import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'api_exception.dart';

class ApiClient {
  final http.Client _client;
  final String baseUrl;

  ApiClient({
    http.Client? client,
    this.baseUrl = 'https://api.templateapp.com', // Place-holder API URL
  }) : _client = client ?? http.Client();

  /// Generic GET request wrapper
  Future<dynamic> get(String path) async {
    // Intercept mock API calls to simulate fetching JSON from an API
    if (baseUrl.contains('api.templateapp.com')) {
      return await _simulateMockApiCall(path);
    }

    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      return _processResponse(response);
    } on http.ClientException {
      throw NetworkException('Unable to reach server. Check connection.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('An unexpected network error occurred: $e');
    }
  }

  /// Simulates a backend API call with generic mock responses
  Future<dynamic> _simulateMockApiCall(String path) async {
    final uri = Uri.parse(path);
    
    // Simulate network delay (1.0 second)
    await Future.delayed(const Duration(milliseconds: 1000));

    final pathSegments = uri.pathSegments;

    // Fetch user dashboard status payload: /status
    if (pathSegments.length == 1 && pathSegments[0] == 'status') {
      return {
        'status': 'healthy',
        'active_users': 1420,
        'system_load': '0.08',
        'version': '1.0.0+1'
      };
    }

    // Fetch list of generic template items: /items (Loads from app json file)
    if (pathSegments.length == 1 && pathSegments[0] == 'items') {
      try {
        final jsonString = await rootBundle.loadString('assets/config/dashboard_items.json');
        final List<dynamic> itemsList = json.decode(jsonString);
        return {'data': itemsList};
      } catch (e) {
        throw Exception('Failed to load assets/config/dashboard_items.json: $e');
      }
    }

    throw Exception('Mock API Endpoint not found: $path');
  }

  /// Process HTTP Response and map to correct ApiException
  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return json.decode(response.body);
      } catch (e) {
        throw ApiException('Failed to parse response body as JSON');
      }
    }
    
    switch (statusCode) {
      case 400:
        throw BadRequestException('Bad request parameters.', statusCode);
      case 401:
      case 403:
        throw UnauthorizedException('Unauthorized access.', statusCode);
      case 404:
        throw BadRequestException('Resource not found.', statusCode);
      default:
        if (statusCode >= 500) {
          throw ServerException('Server error: Internal error.', statusCode);
        } else {
          throw ApiException('Error occurred with Status Code: $statusCode', statusCode);
        }
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/register_request.dart';
import '../models/register_response.dart';
import '../models/user.dart';
import '../models/user_list_response.dart';
import '../models/update_user_request.dart';
import '../models/show.dart';
import '../models/show_list_response.dart';
import '../models/performance.dart';
import '../models/order.dart';
import '../models/order_list_response.dart';
import '../models/create_order_request.dart';
import '../models/ticket.dart';
import '../models/institution.dart';
import '../models/genre.dart';
import '../models/recommendation.dart';
import '../models/validate_ticket_request.dart';
import '../models/validate_ticket_response.dart';
import '../models/create_payment_intent_request.dart';
import '../models/create_payment_intent_response.dart';
import '../models/confirm_payment_request.dart';
import '../models/review.dart';
import '../models/sales_report.dart';
import '../models/popularity_report.dart';
import 'storage_service.dart';

class ApiService {
  // API adresa - 10.0.2.2 za Android Emulator, localhost za ostale platforme
  static String get baseUrl {
    // Provjeri da li je platforma Android
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api'; //5169
    }
    // Za Windows, iOS, Web koristi localhost
    return 'http://localhost:5000/api'; //5169
  }

  static String get _platformHeaderValue {
    if (kIsWeb) return 'mobile';
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return 'desktop';
    return 'mobile';
  }

  // Timeout za HTTP zahtjeve - kratak timeout za brzi feedback (5 sekundi)
  // Smanjeni timeout za brži feedback korisniku
  static const Duration _connectTimeout = Duration(seconds: 5);
  static const Duration _receiveTimeout = Duration(seconds: 5);
  static const Duration _sendTimeout = Duration(seconds: 5);
  // Total timeout - još kraći za garantovano prekidanje
  static const Duration _totalTimeout = Duration(seconds: 5);

  // Singleton Dio client sa timeout konfiguracijom
  static Dio? _dioClientInstance;
  static Dio get _dioClient {
    if (_dioClientInstance != null) {
      return _dioClientInstance!;
    }

    _dioClientInstance = Dio(BaseOptions(
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      sendTimeout: _sendTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
      // Eksplicitno postavi validateStatus da prima sve status kodove
      validateStatus: (status) => status != null && status < 500,
    ));
    
    // Dodaj error handler za bolje error poruke
    _dioClientInstance!.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        String errorMessage = 'Greška u komunikaciji sa serverom';
        
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Request timeout: Server nije odgovorio na vrijeme (5s). Provjerite da li je backend API pokrenut i dostupan.';
        } else if (error.type == DioExceptionType.connectionError) {
          errorMessage = 'Connection error: Nije moguće povezati se sa serverom. Provjerite da li je backend API pokrenut.';
        }
        
        final customError = DioException(
          requestOptions: error.requestOptions,
          error: Exception(errorMessage),
          type: error.type,
          response: error.response,
        );
        
        return handler.next(customError);
      },
    ));
    
    return _dioClientInstance!;
  }
  
  static Future<String?> _getToken() async {
    final raw = await StorageService.getToken();
    final token = raw?.trim();
    if (token == null || token.isEmpty) return null;

    // Ako je JWT istekao, očisti storage da UI može vratiti korisnika na login.
    if (_isJwtExpired(token)) {
      await StorageService.clearAll();
      return null;
    }

    return token;
  }

  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded);
      if (map is! Map<String, dynamic>) return false;
      final exp = map['exp'];
      if (exp is! num) return false;
      final expUtc = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return DateTime.now().toUtc().isAfter(expUtc);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _clearAuth() async {
    await StorageService.clearAll();
  }

  // Helper metoda za kreiranje options sa autorizacijom
  static Options _getOptions({String? token}) {
    final headers = <String, dynamic>{
      'X-Platform': _platformHeaderValue, // Dodaj X-Platform header za sve zahtjeve
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return Options(headers: headers);
  }

  // Helper metoda za rukovanje DioException greškama
  static Exception _handleDioError(DioException e, {String defaultMessage = 'An error occurred'}) {
    if (e.response != null) {
      final data = e.response!.data;

      // Backend može vratiti:
      // - { message: "..." }
      // - { data: ..., message: "..." }
      // - [ { ... } ] (lista grešaka)
      // - string/plain text
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg != null) return Exception(msg.toString());
        // fallback: ako je greška ugniježđena
        final inner = data['data'];
        if (inner is Map<String, dynamic> && inner['message'] != null) {
          return Exception(inner['message'].toString());
        }
        return Exception(defaultMessage);
      }

      if (data is List && data.isNotEmpty) {
        // pokušaj izvući "message" iz prve stavke, ili stringify listu
        final first = data.first;
        if (first is Map<String, dynamic> && first['message'] != null) {
          return Exception(first['message'].toString());
        }
        return Exception(defaultMessage);
      }

      if (data is String && data.isNotEmpty) {
        return Exception(data);
      }

      return Exception(defaultMessage);
    }

    return Exception(e.message ?? defaultMessage);
  }

  /// Upload slike (multipart/form-data). Vraća relativnu putanju npr. `/images/shows/abc.jpg`.
  /// folder: `shows` | `institutions` | `misc`
  static Future<String> uploadImage({
    required String filePath,
    String folder = 'misc',
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');

    try {
      final fileName = filePath.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dioClient.post(
        '$baseUrl/images/upload',
        queryParameters: {'folder': folder},
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'X-Platform': _platformHeaderValue,
          },
          contentType: 'multipart/form-data',
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final path = data['path']?.toString();
        if (path == null || path.isEmpty) {
          throw Exception('Server nije vratio putanju slike.');
        }
        return path;
      }

      throw _handleDioError(
        DioException(requestOptions: RequestOptions(path: ''), response: response),
        defaultMessage: 'Greška pri upload-u slike',
      );
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Greška pri upload-u slike');
    }
  }

  static Future<LoginResponse> login(LoginRequest request) async {
    try {
      // Eksplicitni timeout wrapper - garantovano aktivira nakon 5 sekundi
      final completer = Completer<Response>();
      Timer? timeoutTimer;
      
      // Postavi timeout timer
      timeoutTimer = Timer(_totalTimeout, () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException(
            'Request timeout: Server nije odgovorio na vrijeme (5s). Provjerite da li je backend API pokrenut i dostupan.',
            _totalTimeout,
          ));
        }
      });
      
      // Pokreni zahtjev sa X-Platform header (mobile/desktop)
      _dioClient.post(
        '$baseUrl/auth/login',
        data: request.toJson(),
        options: Options(headers: {'X-Platform': _platformHeaderValue}),
      ).then((response) {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      }).catchError((error) {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });
      
      final response = await completer.future;

      if (response.statusCode == 200) {
        final loginResponse = LoginResponse.fromJson(response.data as Map<String, dynamic>);
        
        // Sačuvaj token
        await StorageService.saveToken(loginResponse.token);
        await StorageService.saveUser(jsonEncode(loginResponse.user.toJson()));
        
        return loginResponse;
      } else {
        throw _handleDioError(
          DioException(requestOptions: RequestOptions(path: ''), response: response),
          defaultMessage: 'Login failed',
        );
      }
    } on DioException catch (e) {
      // Ako je timeout ili connection error, baci eksplicitnu grešku
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(e.error?.toString() ?? 'Request timeout: Server nije odgovorio na vrijeme (5s).');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Connection error: Nije moguće povezati se sa serverom. Provjerite da li je backend API pokrenut.');
      } else if (e.response != null) {
        throw _handleDioError(e, defaultMessage: 'Login failed');
      } else {
        throw Exception(e.message ?? e.error?.toString() ?? 'Network error occurred');
      }
    } on TimeoutException {
      throw Exception('Request timeout: Server nije odgovorio na vrijeme (5s). Provjerite da li je backend API pokrenut i dostupan.');
    }
  }

  static Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final futureResponse = _dioClient.post(
        '$baseUrl/auth/register',
        data: request.toJson(),
      );
      
      final response = await futureResponse.timeout(
        _totalTimeout,
      ).catchError((e) {
        if (e is TimeoutException) {
          throw TimeoutException(
            'Request timeout: Server nije odgovorio na vrijeme (5s). Provjerite da li je backend API pokrenut i dostupan.',
            _totalTimeout,
          );
        }
        throw e;
      });

      if (response.statusCode == 200) {
        return RegisterResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw _handleDioError(
          DioException(requestOptions: RequestOptions(path: ''), response: response),
          defaultMessage: 'Registration failed',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timeout: Server nije odgovorio na vrijeme (5s).');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Connection error: Nije moguće povezati se sa serverom. Provjerite da li je backend API pokrenut.');
      } else if (e.response != null) {
        throw _handleDioError(e, defaultMessage: 'Registration failed');
      } else {
        throw Exception(e.message ?? 'Network error occurred');
      }
    } on TimeoutException {
      throw Exception('Request timeout: Server nije odgovorio na vrijeme (5s). Provjerite da li je backend API pokrenut i dostupan.');
    }
  }

  static Future<User> getCurrentUser() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final futureResponse = _dioClient.get(
        '$baseUrl/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      final response = await futureResponse.timeout(
        _totalTimeout,
      ).catchError((e) {
        if (e is TimeoutException) {
          throw TimeoutException(
            'Request timeout: Server nije odgovorio na vrijeme (5s). Provjerite da li je backend API pokrenut i dostupan.',
            _totalTimeout,
          );
        }
        throw e;
      });

      if (response.statusCode == 200) {
        return User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get current user');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timeout: Server nije odgovorio na vrijeme (5s).');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Connection error: Nije moguće povezati se sa serverom. Provjerite da li je backend API pokrenut.');
      } else if (e.response != null) {
        throw Exception('Failed to get current user: ${e.response!.statusCode}');
      } else {
        throw Exception(e.message ?? 'Network error occurred');
      }
    } on TimeoutException {
      throw Exception('Request timeout: Server nije odgovorio na vrijeme (5s). Provjerite da li je backend API pokrenut i dostupan.');
    }
  }

  static Future<User> updateProfile(UpdateUserRequest request) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.put(
        '$baseUrl/users/me',
        data: request.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw _handleDioError(
          DioException(requestOptions: RequestOptions(path: ''), response: response),
          defaultMessage: 'Failed to update profile',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw _handleDioError(e, defaultMessage: 'Failed to update profile');
      } else {
        throw Exception(e.message ?? 'Network error occurred');
      }
    }
  }

  // Users Management (CRUD)
  static Future<UserListResponse> getUsers({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dioClient.get(
        '$baseUrl/users',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return UserListResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get users: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get users');
    }
  }

  static Future<User> createUser(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.post(
        '$baseUrl/users',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        Map<String, dynamic>? asMap(dynamic value) {
          if (value is Map<String, dynamic>) return value;
          if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
          if (value is List && value.isNotEmpty) return asMap(value.first);
          return null;
        }

        final root = asMap(response.data);
        final inner = root != null && root['data'] != null ? asMap(root['data']) : null;
        final userMap = inner ?? root;
        if (userMap == null) {
          throw Exception('Invalid response format');
        }
        return User.fromJson(userMap);
      } else {
        throw Exception('Failed to create user: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create user');
    }
  }

  static Future<User> updateUser(String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.put(
        '$baseUrl/users/$id',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic>? asMap(dynamic value) {
          if (value is Map<String, dynamic>) return value;
          if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
          if (value is List && value.isNotEmpty) return asMap(value.first);
          return null;
        }

        final root = asMap(response.data);
        final inner = root != null && root['data'] != null ? asMap(root['data']) : null;
        final userMap = inner ?? root;
        if (userMap == null) {
          throw Exception('Invalid response format');
        }
        return User.fromJson(userMap);
      } else {
        throw Exception('Failed to update user: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to update user');
    }
  }

  static Future<void> deleteUser(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.delete(
        '$baseUrl/users/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete user: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to delete user');
    }
  }

  static Future<User> updateUserRoles(String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.put(
        '$baseUrl/users/$id/roles',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic>? asMap(dynamic value) {
          if (value is Map<String, dynamic>) return value;
          if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
          if (value is List && value.isNotEmpty) return asMap(value.first);
          return null;
        }

        final root = asMap(response.data);
        final inner = root != null && root['data'] != null ? asMap(root['data']) : null;
        final userMap = inner ?? root;
        if (userMap == null) {
          throw Exception('Invalid response format');
        }
        return User.fromJson(userMap);
      } else {
        throw Exception('Failed to update user roles: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to update user roles');
    }
  }

  static Future<List<String>> getAvailableRoles() async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.get(
        '$baseUrl/users/roles',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        // Ukloni duplikate
        return jsonList.map((r) => r as String).toSet().toList();
      } else {
        throw Exception('Failed to get available roles: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get available roles');
    }
  }

  static Future<void> logout() async {
    await StorageService.clearAll();
  }

  // Shows
  static Future<ShowListResponse> getShows({
    int pageNumber = 1,
    int pageSize = 10,
    int? institutionId,
    int? genreId,
    String? searchTerm,
  }) async {
    final token = await _getToken();
    final queryParams = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (institutionId != null) {
      queryParams['institutionId'] = institutionId;
    }
    if (genreId != null) {
      queryParams['genreId'] = genreId;
    }
    if (searchTerm != null && searchTerm.isNotEmpty) {
      queryParams['searchTerm'] = searchTerm;
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/shows',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return ShowListResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get shows: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get shows');
    }
  }

  static Future<ShowListResponse> getShowsForManagement({
    int pageNumber = 1,
    int pageSize = 10,
    int? institutionId,
    int? genreId,
    String? searchTerm,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Sesija je istekla. Molimo prijavite se ponovo.');

    final queryParams = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (institutionId != null) {
      queryParams['institutionId'] = institutionId;
    }
    if (genreId != null) {
      queryParams['genreId'] = genreId;
    }
    if (searchTerm != null && searchTerm.isNotEmpty) {
      queryParams['searchTerm'] = searchTerm;
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/shows/management',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return ShowListResponse.fromJson(response.data as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        await _clearAuth();
        throw Exception('Sesija je istekla. Molimo prijavite se ponovo.');
      } else if (response.statusCode == 403) {
        throw Exception('Nemate ovlaštenje za upravljanje predstavama.');
      } else {
        throw Exception('Failed to get shows: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get shows');
    }
  }

  static Future<Show> getShowById(int id) async {
    final token = await _getToken();
    try {
      final response = await _dioClient.get(
        '$baseUrl/shows/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return Show.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get show: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get show');
    }
  }

  static Future<Show> createShow(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.post(
        '$baseUrl/shows',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        return Show.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to create show: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create show');
    }
  }

  static Future<Show> updateShow(int id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.put(
        '$baseUrl/shows/$id',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        return Show.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update show: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to update show');
    }
  }

  static Future<void> deleteShow(int id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.delete(
        '$baseUrl/shows/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete show: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to delete show');
    }
  }

  // Performances
  static Future<List<Performance>> getPerformances({
    int pageNumber = 1,
    int pageSize = 100,
    int? showId,
    int? institutionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();
    final queryParams = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (showId != null) {
      queryParams['showId'] = showId;
    }
    if (institutionId != null) {
      queryParams['institutionId'] = institutionId;
    }
    if (startDate != null) {
      queryParams['startDate'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['endDate'] = endDate.toIso8601String();
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/performances',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        return jsonList.map((p) => Performance.fromJson(p as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get performances: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get performances');
    }
  }

  static Future<Performance> getPerformanceById(int id) async {
    final token = await _getToken();
    try {
      final response = await _dioClient.get(
        '$baseUrl/performances/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        Map<String, dynamic>? asMap(dynamic value) {
          if (value is Map<String, dynamic>) return value;
          if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
            return value.first as Map<String, dynamic>;
          }
          return null;
        }

        if (data is Map<String, dynamic>) {
          final inner = data['data'];
          final innerMap = asMap(inner);
          if (innerMap != null) return Performance.fromJson(innerMap);
          final rootMap = asMap(data);
          if (rootMap != null) return Performance.fromJson(rootMap);
        }

        final listMap = asMap(data);
        if (listMap != null) return Performance.fromJson(listMap);

        throw Exception('Invalid performance response format');
      } else {
        throw Exception('Failed to get performance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get performance');
    }
  }

  static Future<Performance> createPerformance(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.post(
        '$baseUrl/performances',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        return Performance.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to create performance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create performance');
    }
  }

  static Future<Performance> updatePerformance(int id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.put(
        '$baseUrl/performances/$id',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        return Performance.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update performance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to update performance');
    }
  }

  static Future<void> deletePerformance(int id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.delete(
        '$baseUrl/performances/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete performance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to delete performance');
    }
  }

  // Institutions
  static Future<List<Institution>> getInstitutions() async {
    final token = await _getToken();
    try {
      final response = await _dioClient.get(
        '$baseUrl/institutions',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        return jsonList.map((i) => Institution.fromJson(i as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get institutions: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get institutions');
    }
  }

  static Future<Institution> createInstitution(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.post(
        '$baseUrl/institutions',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        return Institution.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to create institution: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create institution');
    }
  }

  static Future<Institution> updateInstitution(int id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.put(
        '$baseUrl/institutions/$id',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        return Institution.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update institution: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to update institution');
    }
  }

  static Future<void> deleteInstitution(int id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.delete(
        '$baseUrl/institutions/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete institution: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to delete institution');
    }
  }

  // Genres
  static Future<List<Genre>> getGenres() async {
    final token = await _getToken();
    try {
      final response = await _dioClient.get(
        '$baseUrl/genres',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        return jsonList.map((g) => Genre.fromJson(g as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get genres: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get genres');
    }
  }

  static Future<Genre> createGenre(Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.post(
        '$baseUrl/genres',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>;
        return Genre.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to create genre: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create genre');
    }
  }

  static Future<Genre> updateGenre(int id, Map<String, dynamic> data) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.put(
        '$baseUrl/genres/$id',
        data: data,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;
        return Genre.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update genre: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to update genre');
    }
  }

  static Future<void> deleteGenre(int id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.delete(
        '$baseUrl/genres/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete genre: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to delete genre');
    }
  }

  // Orders
  static Future<Order> createOrder(CreateOrderRequest request) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.post(
        '$baseUrl/orders',
        data: request.toJson(),
        options: _getOptions(token: token),
      );

      if (response.statusCode == 201) {
        final responseData = response.data;

        Map<String, dynamic>? asMap(dynamic value) {
          if (value is Map<String, dynamic>) return value;
          if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
            return value.first as Map<String, dynamic>;
          }
          return null;
        }

        // Prefer nested "data" if present
        if (responseData is Map<String, dynamic>) {
          final inner = responseData['data'];
          final innerMap = asMap(inner);
          if (innerMap != null) {
            return Order.fromJson(innerMap);
          }
          final rootMap = asMap(responseData);
          if (rootMap != null) {
            return Order.fromJson(rootMap);
          }
        }

        // Fallback if backend returned a bare array
        final listMap = asMap(responseData);
        if (listMap != null) {
          return Order.fromJson(listMap);
        }

        throw Exception('Invalid order response format');
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to create order');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create order');
    }
  }

  static Future<OrderListResponse> getOrders({
    int pageNumber = 1,
    int pageSize = 10,
    String? searchTerm,
    int? institutionId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    final queryParams = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (searchTerm != null && searchTerm.isNotEmpty) {
      queryParams['searchTerm'] = searchTerm;
    }
    if (institutionId != null) {
      queryParams['institutionId'] = institutionId;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (startDate != null) {
      queryParams['startDate'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['endDate'] = endDate.toIso8601String();
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/orders',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return OrderListResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get orders: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get orders');
    }
  }

  static Future<Order> getOrderById(int id) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/orders/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return Order.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get order: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get order');
    }
  }

  static Future<Order> cancelOrder(int id) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.post(
        '$baseUrl/orders/$id/cancel',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return Order.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to cancel order');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to cancel order');
    }
  }

  static Future<Order> refundOrder(int id, {String reason = 'Korisnički zahtjev'}) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.post(
        '$baseUrl/orders/$id/refund',
        data: {'reason': reason},
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final orderData = data['data'] ?? data;
        return Order.fromJson(orderData);
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to refund order');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to refund order');
    }
  }

  // Tickets
  static Future<List<Ticket>> getMyTickets() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/tickets/my-tickets',
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        return jsonList.map((t) => Ticket.fromJson(t as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get tickets: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get tickets');
    }
  }

  // Recommendations
  static Future<List<Recommendation>> getRecommendations({int count = 10}) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/recommendations',
        queryParameters: {'count': count},
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final recommendationsJson = data['recommendations'] as List<dynamic>;
        return recommendationsJson
            .map((json) => Recommendation.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to get recommendations');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get recommendations');
    }
  }

  // Ticket Validation
  // Backend automatski određuje InstitutionId iz uloge korisnika
  static Future<ValidateTicketResponse> validateTicket(String qrCode) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Sesija je istekla. Molimo prijavite se ponovo.');
    }

    try {
      final request = ValidateTicketRequest(qrCode: qrCode);
      final response = await _dioClient.post(
        '$baseUrl/tickets/validate',
        data: request.toJson(),
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200 || response.statusCode == 400) {
        return ValidateTicketResponse.fromJson(response.data as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        await _clearAuth();
        throw Exception('Sesija je istekla. Molimo prijavite se ponovo.');
      } else if (response.statusCode == 403) {
        throw Exception('Nemate ovlaštenje za validaciju karte.');
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to validate ticket');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to validate ticket');
    }
  }

  static Future<Ticket> getTicketByQRCode(String qrCode) async {
    try {
      final response = await _dioClient.get(
        '$baseUrl/tickets/qr/$qrCode',
      );

      if (response.statusCode == 200) {
        return Ticket.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get ticket: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get ticket');
    }
  }

  // Payment
  static Future<CreatePaymentIntentResponse> createPaymentIntent(int orderId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final request = CreatePaymentIntentRequest(orderId: orderId);
      final response = await _dioClient.post(
        '$baseUrl/payments/create-intent',
        data: request.toJson(),
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        Map<String, dynamic>? asMap(dynamic value) {
          if (value is Map<String, dynamic>) return value;
          if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
            return value.first as Map<String, dynamic>;
          }
          return null;
        }

        if (data is Map<String, dynamic>) {
          final inner = data['data'];
          final innerMap = asMap(inner);
          if (innerMap != null) return CreatePaymentIntentResponse.fromJson(innerMap);
          final rootMap = asMap(data);
          if (rootMap != null) return CreatePaymentIntentResponse.fromJson(rootMap);
        }

        final listMap = asMap(data);
        if (listMap != null) return CreatePaymentIntentResponse.fromJson(listMap);

        throw Exception('Invalid payment intent response format');
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to create payment intent');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create payment intent');
    }
  }

  static Future<Order> confirmPayment(int orderId, String paymentIntentId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final request = ConfirmPaymentRequest(
        orderId: orderId,
        paymentIntentId: paymentIntentId,
      );
      final response = await _dioClient.post(
        '$baseUrl/payments/confirm',
        data: request.toJson(),
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        Map<String, dynamic>? asMap(dynamic value) {
          if (value is Map<String, dynamic>) return value;
          if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
            return value.first as Map<String, dynamic>;
          }
          return null;
        }

        if (data is Map<String, dynamic>) {
          final inner = data['data'];
          final innerMap = asMap(inner);
          if (innerMap != null) return Order.fromJson(innerMap);
          final rootMap = asMap(data);
          if (rootMap != null) return Order.fromJson(rootMap);
        }

        final listMap = asMap(data);
        if (listMap != null) return Order.fromJson(listMap);

        throw Exception('Invalid confirm payment response format');
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to confirm payment');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to confirm payment');
    }
  }

  // Reviews
  static Future<List<Review>> getReviews({int? showId}) async {
    final queryParams = <String, dynamic>{};
    if (showId != null) {
      queryParams['showId'] = showId;
    }

    try {
      final response = await _dioClient.get(
        // Public endpoint: dostupno svima (bez tokena)
        '$baseUrl/reviews',
        queryParameters: queryParams,
        options: Options(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        return jsonList.map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get reviews: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get reviews');
    }
  }

  // Reviews Management (for Admin)
  static Future<List<Review>> getReviewsForManagement({
    int? showId,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final queryParams = <String, dynamic>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      };
      if (showId != null) {
        queryParams['showId'] = showId;
      }

      final response = await _dioClient.get(
        '$baseUrl/reviews/management',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is List) {
          // Backend vraća direktno listu
          final jsonList = responseData;
          return jsonList.map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();
        } else if (responseData is Map<String, dynamic>) {
          final responseDataMap = responseData;
          if (responseDataMap.containsKey('data')) {
            final data = responseDataMap['data'];
            if (data is List) {
              final jsonList = data;
              return jsonList.map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();
            }
          }
        }
        // Fallback: pokušaj parsirati kao listu
        final List<dynamic> jsonList = response.data as List<dynamic>;
        return jsonList.map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get reviews: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get reviews');
    }
  }

  static Future<Review> createReview(CreateReviewRequest request) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No token found');
    }

    try {
      final response = await _dioClient.post(
        '$baseUrl/reviews',
        data: request.toJson(),
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        // Backend vraća { data: Review, message: "..." }
        if (data.containsKey('data')) {
          return Review.fromJson(data['data'] as Map<String, dynamic>);
        }
        return Review.fromJson(data);
      } else {
        throw _handleDioError(DioException(requestOptions: RequestOptions(path: ''), response: response), defaultMessage: 'Failed to create review');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to create review');
    }
  }

  static Future<bool> canReviewShow(int showId) async {
    final token = await _getToken();
    if (token == null) {
      return false;
    }

    try {
      final info = await canReviewShowInfo(showId);
      return info['canReview'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> canReviewShowInfo(int showId) async {
    final token = await _getToken();
    if (token == null) {
      return {'canReview': false, 'message': 'Korisnik nije prijavljen.'};
    }

    try {
      final response = await _dioClient.get(
        '$baseUrl/reviews/can-review',
        queryParameters: {'showId': showId},
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return {
            'canReview': (data['canReview'] as bool?) ?? false,
            'message': data['message']?.toString() ?? '',
          };
        }
        return {'canReview': false, 'message': ''};
      } else if (response.statusCode == 401) {
        await _clearAuth();
        return {'canReview': false, 'message': 'Sesija je istekla. Prijavite se ponovo.'};
      } else {
        return {'canReview': false, 'message': ''};
      }
    } catch (e) {
      return {'canReview': false, 'message': ''};
    }
  }

  static Future<void> deleteReview(int id) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.delete(
        '$baseUrl/reviews/$id',
        options: _getOptions(token: token),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete review: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to delete review');
    }
  }

  static Future<Review> updateReviewVisibility(int id, bool isVisible) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final response = await _dioClient.put(
        '$baseUrl/reviews/$id/visibility',
        data: isVisible,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return Review.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update review visibility: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to update review visibility');
    }
  }

  // Tickets Management (for Blagajnik/Admin)
  static Future<List<Ticket>> getScannedTickets({
    int? institutionId,
    String? status,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Sesija je istekla. Molimo prijavite se ponovo.');
    
    try {
      final queryParams = <String, dynamic>{};
      if (institutionId != null) {
        queryParams['institutionId'] = institutionId;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      // Backend endpoint treba biti implementiran
      // Za sada koristimo getMyTickets kao placeholder
      // TODO: Implementirati backend endpoint GET /api/tickets/scanned?institutionId=...
      final response = await _dioClient.get(
        '$baseUrl/tickets/scanned',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data as List<dynamic>;
        return jsonList.map((t) => Ticket.fromJson(t as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else if (response.statusCode == 401) {
        await _clearAuth();
        throw Exception('Sesija je istekla. Molimo prijavite se ponovo.');
      } else if (response.statusCode == 403) {
        throw Exception('Nemate ovlaštenje za pregled karata.');
      } else {
        throw Exception('Failed to get scanned tickets: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Ako endpoint ne postoji, koristimo fallback
      if (e.response?.statusCode == 404) {
        // Fallback: vrati praznu listu ili koristi getMyTickets
        return [];
      }
      throw _handleDioError(e, defaultMessage: 'Failed to get scanned tickets');
    }
  }

  // Reports
  static Future<SalesReport> getSalesReport({
    DateTime? startDate,
    DateTime? endDate,
    int? institutionId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (institutionId != null) {
        queryParams['institutionId'] = institutionId;
      }

      final response = await _dioClient.get(
        '$baseUrl/reports/sales',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return SalesReport.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get sales report: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get sales report');
    }
  }

  static Future<PopularityReport> getPopularityReport({
    DateTime? startDate,
    DateTime? endDate,
    int? institutionId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (institutionId != null) {
        queryParams['institutionId'] = institutionId;
      }

      final response = await _dioClient.get(
        '$baseUrl/reports/popularity',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return PopularityReport.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get popularity report: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get popularity report');
    }
  }

  // Orders Management (for Admin)
  static Future<OrderListResponse> getInstitutionOrders({
    int? institutionId,
    int pageNumber = 1,
    int pageSize = 10,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('No token found');
    
    try {
      final queryParams = <String, dynamic>{
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      };
      if (institutionId != null) {
        queryParams['institutionId'] = institutionId;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final response = await _dioClient.get(
        '$baseUrl/orders',
        queryParameters: queryParams,
        options: _getOptions(token: token),
      );

      if (response.statusCode == 200) {
        return OrderListResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get institution orders: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e, defaultMessage: 'Failed to get institution orders');
    }
  }
}


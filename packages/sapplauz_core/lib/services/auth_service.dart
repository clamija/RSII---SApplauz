import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/register_request.dart';
import '../models/update_user_request.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  // Singleton instance
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }
  
  // Privatni konstruktor za singleton
  AuthService._internal();
  
  // Javni konstruktor koji vraća singleton instance
  factory AuthService() => instance;

  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> initialize() async {
    final token = await StorageService.getToken();
    if (token != null) {
      try {
        _currentUser = await ApiService.getCurrentUser();
        _isAuthenticated = true;
      } catch (e) {
        // Token je nevažeći, obriši ga
        await StorageService.clearAll();
        _isAuthenticated = false;
      }
    }
  }

  Future<LoginResponse> login(String email, String password) async {
    final request = LoginRequest(email: email, password: password);
    final response = await ApiService.login(request);
    
    _currentUser = response.user;
    _isAuthenticated = true;
    
    return response;
  }

  Future<LoginResponse> register(
    String firstName,
    String lastName,
    String email,
    String password,
    String confirmPassword,
  ) async {
    final request = RegisterRequest(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
    
    // Prvo registruj korisnika
    await ApiService.register(request);
    
    // Automatski prijavi korisnika nakon uspješne registracije
    final loginRequest = LoginRequest(email: email, password: password);
    final loginResponse = await ApiService.login(loginRequest);
    
    // Postavi currentUser i isAuthenticated
    _currentUser = loginResponse.user;
    _isAuthenticated = true;
    
    return loginResponse;
  }

  Future<void> logout() async {
    await ApiService.logout();
    _currentUser = null;
    _isAuthenticated = false;
  }

  Future<void> refreshUser() async {
    if (_isAuthenticated) {
      try {
        _currentUser = await ApiService.getCurrentUser();
      } catch (e) {
        await logout();
        rethrow;
      }
    }
  }

  Future<User> updateProfile(UpdateUserRequest request) async {
    final updatedUser = await ApiService.updateProfile(request);
    _currentUser = updatedUser;
    return updatedUser;
  }
}


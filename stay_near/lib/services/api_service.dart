import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:stay_near/components/pin_pointer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String imgURL;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.imgURL,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? 'Unbekannter Benutzer',
      email: json['email'] ?? '',
      imgURL: json['imgURL'] ?? 'https://i.ibb.co/wWXyqpt/test.png',
    );
  }
}

class FriendLocation {
  final int userId;
  final String username;
  final String imgURL;
  final double lat;
  final double lng;

  FriendLocation({
    required this.userId,
    required this.username,
    required this.imgURL,
    required this.lat,
    required this.lng,
  });

  factory FriendLocation.fromJson(Map<String, dynamic> json) {
    return FriendLocation(
      userId: json['user_id'],
      username: json['username'],
      imgURL: json['imgURL'],
      lat: json['position']['lat'].toDouble(),
      lng: json['position']['lng'].toDouble(),
    );
  }
}

class SearchResult {
  final int id;
  final String username;
  final String imgURL;
  final bool isFriend;

  SearchResult({
    required this.id,
    required this.username,
    required this.imgURL,
    required this.isFriend,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'],
      username: json['username'],
      imgURL: json['imgURL'],
      isFriend: json['isFriend'],
    );
  }
}

class FriendRequest {
  final int id;
  final int fromUser;
  final String fromUsername;
  final String fromUserImage;
  final String createdAt;
  final String status;

  FriendRequest({
    required this.id,
    required this.fromUser,
    required this.fromUsername,
    required this.fromUserImage,
    required this.createdAt,
    required this.status,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      fromUser: json['from_user'],
      fromUsername: json['from_username'],
      fromUserImage: json['from_user_image'],
      createdAt: json['created_at'],
      status: json['status'],
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
  });
}

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000'; //http://10.0.2.2:5000
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';

  Function? onFriendsUpdate;

  final http.Client _client;
  
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Token Management
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Registriere Callback
  void setOnFriendsUpdateCallback(Function callback) {
    onFriendsUpdate = callback;
  }

  // Entferne Callback
  void removeOnFriendsUpdateCallback() {
    onFriendsUpdate = null;
  }

  // Authentication
  Future<ApiResponse<User>> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/login'),
        headers: await _getHeaders(withAuth: false),
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);
        return ApiResponse(
          success: true,
          data: User.fromJson(data['user']),
        );
      }
      return ApiResponse(
        success: false,
        message: 'Login fehlgeschlagen: ${response.body}',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<void>> register(String username, String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/register'),
        headers: await _getHeaders(withAuth: false),
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return ApiResponse(success: true);
      }
      return ApiResponse(
        success: false,
        message: 'Registrierung fehlgeschlagen: ${response.body}',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<void>> logout() async {
    try {
      // Damit Konsole Logout bestätigt, an sich keine Funktion
      // ignore: unused_local_variable
      final response = await _client.post(
        Uri.parse('$baseUrl/logout'),
        headers: await _getHeaders(),
      );

      // Token und User-Daten lokal löschen
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(userKey);

      return ApiResponse(success: true);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Fehler beim Logout: $e',
      );
    }
  }

  // Search Management
  Future<ApiResponse<List<SearchResult>>> searchUsers(String username) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/users/search/$username'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final results = jsonData.map((json) => SearchResult.fromJson(json)).toList();
        return ApiResponse(success: true, data: results);
      }
      return ApiResponse(
        success: false,
        message: 'Suche konnte nicht durchgeführt werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  // Location Management
  Future<ApiResponse<void>> updatePosition(double lat, double lng) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/position'),
        headers: await _getHeaders(),
        body: json.encode({
          'lat': lat,
          'lng': lng,
        }),
      );

      if (response.statusCode == 200) {
        return ApiResponse(success: true);
      }
      return ApiResponse(
        success: false,
        message: 'Position konnte nicht aktualisiert werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<List<FriendLocation>>> getFriendsLocations() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/positions/friends'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final locations = jsonData.map((json) => FriendLocation.fromJson(json)).toList();
        return ApiResponse(success: true, data: locations);
      }
      return ApiResponse(
        success: false,
        message: 'Freundespositionen konnten nicht geladen werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<List<User>>> getAllFriends() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/friends/all'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final friends = jsonData.map((json) => User.fromJson({
          'id': json['id'] ?? 0,
          'username': json['username'] ?? '',
          'email': json['email'] ?? '',
          'imgURL': json['imgURL'] ?? 'https://i.ibb.co/wWXyqpt/test.png',
        })).toList();
        return ApiResponse(success: true, data: friends);
      }
      
      final errorData = json.decode(response.body);
      return ApiResponse(
        success: false,
        message: errorData['message'] ?? 'Freunde konnten nicht geladen werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  // Friend Management
  Future<ApiResponse<void>> addFriend(int friendId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/friends/add/$friendId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return ApiResponse(success: true);
      }
      return ApiResponse(
        success: false,
        message: 'Freund konnte nicht hinzugefügt werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<void>> removeFriend(int friendId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/friends/remove/$friendId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        if (onFriendsUpdate != null) {
          final locationsResponse = await getFriendsLocations();
          if (locationsResponse.success) {
            onFriendsUpdate!(locationsResponse.data);
          }
        }
        return ApiResponse(success: true);
      }
      return ApiResponse(
        success: false,
        message: 'Freund konnte nicht entfernt werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<void>> sendFriendRequest(int userId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/friends/request/$userId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return ApiResponse(success: true);
      }
      
      final data = json.decode(response.body);
      return ApiResponse(
        success: false,
        message: data['message'] ?? 'Fehler beim Senden der Anfrage',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<List<FriendRequest>>> getPendingFriendRequests() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/friends/requests/pending'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final requests = jsonData
            .map((json) => FriendRequest.fromJson(json))
            .toList();
        return ApiResponse(success: true, data: requests);
      }
      return ApiResponse(
        success: false,
        message: 'Freundschaftsanfragen konnten nicht geladen werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  Future<ApiResponse<void>> respondToFriendRequest(int requestId, bool accept) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/friends/requests/$requestId/${accept ? 'accept' : 'reject'}'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        if (accept && onFriendsUpdate != null) {
          final locationsResponse = await getFriendsLocations();
          if (locationsResponse.success) {
            onFriendsUpdate!(locationsResponse.data);
          }
        }
        return ApiResponse(success: true);
      }
      return ApiResponse(
        success: false,
        message: 'Anfrage konnte nicht bearbeitet werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  // Profile Management
  Future<ApiResponse<String>> updateProfileImage(String filePath) async {
    try {
      final request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/profile/image'));
      final headers = await _getHeaders();
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApiResponse(success: true, data: data['imgURL']);
      }
      return ApiResponse(
        success: false,
        message: 'Profilbild konnte nicht aktualisiert werden',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Netzwerkfehler: $e',
      );
    }
  }

  // Helper Methods
  List<Marker> friendLocationsToMarkers(List<FriendLocation> friends) {
    return friends.map((friend) => Marker(
      point: LatLng(friend.lat, friend.lng),
      child: PinPointer(imgUrl: friend.imgURL),
    )).toList();
  }

  void dispose() {
    removeOnFriendsUpdateCallback();
    _client.close();
  }
}
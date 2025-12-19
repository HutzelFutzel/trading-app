import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account_data.dart';
import '../models/portfolio_history.dart';
import '../models/seasonal_trade.dart';
import '../models/seasonal_strategy_settings.dart';
import '../models/seasonal_strategy_user_settings.dart';
import '../models/user.dart';
import '../models/executed_seasonal_trade.dart';
import 'auth_service.dart';

class UserSaveException implements Exception {
  final String message;
  final User? updatedUser;
  UserSaveException(this.message, {this.updatedUser});
  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl;
  final AuthService _authService = AuthService();

  ApiService({required this.baseUrl});

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      _authService.signOut();
      throw Exception('Unauthorized: Session expired or invalid');
    }
    if (response.statusCode == 500) {
      final body = json.decode(response.body);
      throw Exception('Server Error: ${body['error'] ?? 'Unknown error'}');
    }
  }

  Future<Account> getAccountSummary(String accountType, {String? accountId}) async {
    String url = '$baseUrl/api/accounts/$accountType/summary';
    if (accountId != null) {
      url += '?accountId=$accountId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      return Account.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load account summary');
    }
  }

  Future<List<Position>> getPositions(String accountType, {String? accountId}) async {
    String url = '$baseUrl/api/accounts/$accountType/positions';
    if (accountId != null) {
      url += '?accountId=$accountId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Position.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load positions');
    }
  }

  Future<List<Order>> getOrders(String accountType, {String? status, String? accountId}) async {
    String url = '$baseUrl/api/accounts/$accountType/orders';
    List<String> queryParams = [];
    if (status != null) queryParams.add('status=$status');
    if (accountId != null) queryParams.add('accountId=$accountId');
    
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<List<Order>> getTrades(String accountType, {String? accountId}) async {
    String url = '$baseUrl/api/accounts/$accountType/trades';
    if (accountId != null) {
      url += '?accountId=$accountId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Order.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load trades');
    }
  }

  Future<void> cancelOrder(String accountType, String orderId, {String? accountId}) async {
    String url = '$baseUrl/api/accounts/$accountType/orders/$orderId';
    if (accountId != null) {
      url += '?accountId=$accountId';
    }
    
    final response = await http.delete(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      final body = json.decode(response.body);
      throw Exception('Failed to cancel order: ${body['error'] ?? 'Unknown error'}');
    }
  }

  Future<void> closePosition(String accountType, String symbol, {String? accountId}) async {
    String url = '$baseUrl/api/accounts/$accountType/positions/$symbol';
    if (accountId != null) {
      url += '?accountId=$accountId';
    }
    
    final response = await http.delete(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      final body = json.decode(response.body);
      throw Exception('Failed to close position: ${body['error'] ?? 'Unknown error'}');
    }
  }

  Future<PortfolioHistory> getPortfolioHistory(String accountType, {
    String? accountId,
    String? period,
    String? timeframe,
    String? dateEnd,
    bool? extendedHours,
  }) async {
    String url = '$baseUrl/api/accounts/$accountType/history';
    List<String> queryParams = [];
    if (accountId != null) queryParams.add('accountId=$accountId');
    if (period != null) queryParams.add('period=$period');
    if (timeframe != null) queryParams.add('timeframe=$timeframe');
    if (dateEnd != null) queryParams.add('date_end=$dateEnd');
    if (extendedHours != null) queryParams.add('extended_hours=$extendedHours');

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      return PortfolioHistory.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load portfolio history');
    }
  }

  Future<List<SeasonalTrade>> getSeasonalTrades() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/seasonal-trades'),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => SeasonalTrade.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load seasonal trades');
    }
  }

  Future<SeasonalTrade> createSeasonalTrade(SeasonalTrade trade) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/seasonal-trades'),
      headers: await _getHeaders(),
      body: json.encode(trade.toJson()),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 201) {
      return SeasonalTrade.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create seasonal trade');
    }
  }

  Future<void> updateSeasonalTrade(String id, SeasonalTrade trade) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/seasonal-trades/$id'),
      headers: await _getHeaders(),
      body: json.encode(trade.toJson()),
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update seasonal trade');
    }
  }

  Future<void> deleteSeasonalTrade(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/seasonal-trades/$id'),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete seasonal trade');
    }
  }

  // Seasonal Rules (Global)
  Future<SeasonalStrategySettings> getSeasonalTradeRules() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/seasonal-trades/config/settings'),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      return SeasonalStrategySettings.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load seasonal trade rules');
    }
  }

  Future<void> saveSeasonalTradeRules(SeasonalStrategySettings rules) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/seasonal-trades/config/settings'),
      headers: await _getHeaders(),
      body: json.encode(rules.toJson()),
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to save seasonal trade rules');
    }
  }

  // Executed Trades
  Future<List<ExecutedSeasonalTrade>> getExecutedSeasonalTrades({String? accountId}) async {
    String url = '$baseUrl/api/seasonal-trades/activity/executed';
    if (accountId != null) {
      url += '?accountId=$accountId';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ExecutedSeasonalTrade.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load executed seasonal trades');
    }
  }

  // User Settings - Strategy
  Future<SeasonalStrategyUserSettings> getSeasonalStrategyUserSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/user/strategy'),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      return SeasonalStrategyUserSettings.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load strategy user settings');
    }
  }

  Future<void> saveSeasonalStrategyUserSettings(SeasonalStrategyUserSettings settings) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/strategy'),
      headers: await _getHeaders(),
      body: json.encode(settings.toJson()),
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to save strategy user settings');
    }
  }

  Future<SeasonalStrategyUserSettings> updateThreadAssignment(String tradeId, int targetThread) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/strategy/thread'),
      headers: await _getHeaders(),
      body: json.encode({
        'tradeId': tradeId,
        'targetThread': targetThread,
      }),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      return SeasonalStrategyUserSettings.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update thread assignment');
    }
  }

  // User (Alpaca Settings)
  Future<User> getUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/user'),
      headers: await _getHeaders(),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load user settings');
    }
  }

  Future<User> saveUser(User user) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user'),
      headers: await _getHeaders(),
      body: json.encode(user.toJson()),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      User? savedUser;
      if (body['user'] != null) {
        savedUser = User.fromJson(body['user']);
      }
      
      if (body['error'] != null) {
          throw UserSaveException(body['error'], updatedUser: savedUser);
      }
      
      return savedUser ?? user;
    } else {
      throw Exception('Failed to save user settings');
    }
  }

  Future<Map<String, dynamic>> verifyAlpacaAccount(String accountId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/user/verify-account'),
      headers: await _getHeaders(),
      body: json.encode({'accountId': accountId}),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 400) {
      final data = json.decode(response.body);
      return data;
    } else {
      throw Exception('Failed to verify account');
    }
  }


  // Device Tokens
  Future<void> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api$endpoint'),
      headers: await _getHeaders(),
      body: json.encode(body),
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('API Error ${response.statusCode} for $endpoint: ${response.body}');
      throw Exception('Failed to post to $endpoint: ${response.statusCode}');
    }
  }
}

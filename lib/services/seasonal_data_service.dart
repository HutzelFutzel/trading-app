import 'package:flutter/foundation.dart';
import '../models/seasonal_trade.dart';
import '../models/seasonal_strategy_user_settings.dart';
import '../models/user.dart';
import '../models/seasonal_trade_statistic.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';

class SeasonalDataService extends ChangeNotifier {
  static final SeasonalDataService _instance = SeasonalDataService._internal();
  factory SeasonalDataService() => _instance;

  late final ApiService _apiService;

  List<SeasonalTrade> _trades = [];
  Map<String, List<SeasonalTradeSingleStatistic>> _tradeStatistics = {};
  Map<String, String?> _tradeStatisticsErrors = {};
  Set<String> _loadingStatistics = {};
  
  Map<String, List<Map<String, dynamic>>> _seasonalEquity = {};
  Set<String> _loadingEquity = {};
  
  SeasonalStrategyUserSettings? _userSettings;
  User? _user;
  
  bool _isLoading = false;
  String? _error;

  // Getters
  List<SeasonalTrade> get trades => List.unmodifiable(_trades);
  List<SeasonalTradeSingleStatistic> getStatistics(String tradeId) => List.unmodifiable(_tradeStatistics[tradeId] ?? []);
  String? getStatisticsError(String tradeId) => _tradeStatisticsErrors[tradeId];
  bool isStatisticsLoading(String tradeId) => _loadingStatistics.contains(tradeId);
  List<Map<String, dynamic>>? getSeasonalEquity(String tradeId) => _seasonalEquity[tradeId];
  bool isEquityLoading(String tradeId) => _loadingEquity.contains(tradeId);
  SeasonalStrategyUserSettings? get userSettings => _userSettings;
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SeasonalDataService._internal() {
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
  }

  Future<void> fetchData({bool forceRefresh = false}) async {
    if (_trades.isNotEmpty && _userSettings != null && _user != null && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final futures = <Future<dynamic>>[
        _apiService.getSeasonalTrades(),
        _apiService.getSeasonalStrategyUserSettings(),
        _apiService.getUser(),
      ];
      
      final results = await Future.wait(futures);

      _trades = results[0] as List<SeasonalTrade>;
      _userSettings = results[1] as SeasonalStrategyUserSettings;
      _user = results[2] as User;
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllStatistics() async {
    final tradesToFetch = _trades.where((t) => 
      t.id != null && 
      !_tradeStatistics.containsKey(t.id) && 
      !_loadingStatistics.contains(t.id)
    ).toList();

    if (tradesToFetch.isEmpty) return;

    // Mark all as loading immediately to prevent duplicate fetches
    for (var t in tradesToFetch) {
      _loadingStatistics.add(t.id!);
    }
    notifyListeners();

    // Process in batches to avoid overwhelming the API
    const int batchSize = 5;
    for (var i = 0; i < tradesToFetch.length; i += batchSize) {
      final end = (i + batchSize < tradesToFetch.length) ? i + batchSize : tradesToFetch.length;
      final batch = tradesToFetch.sublist(i, end);
      
      await Future.wait(batch.map((trade) async {
        try {
          final stats = await _apiService.getSeasonalTradeStatistics(trade.id!);
          _tradeStatistics[trade.id!] = stats;
        } catch (e) {
          print('Error fetching stats for ${trade.id}: $e');
          _tradeStatisticsErrors[trade.id!] = e.toString();
        } finally {
          _loadingStatistics.remove(trade.id!);
        }
      }));
      // Notify after each batch to show partial results
      notifyListeners();
    }
  }

  Future<void> fetchStatistics(String tradeId) async {
    if (_tradeStatistics.containsKey(tradeId) || _loadingStatistics.contains(tradeId)) return;
    
    _loadingStatistics.add(tradeId);
    _tradeStatisticsErrors[tradeId] = null;
    notifyListeners();

    try {
      final stats = await _apiService.getSeasonalTradeStatistics(tradeId);
      _tradeStatistics[tradeId] = stats;
    } catch (e) {
      print('Error fetching stats for $tradeId: $e');
      _tradeStatisticsErrors[tradeId] = e.toString();
    } finally {
      _loadingStatistics.remove(tradeId);
      notifyListeners();
    }
  }

  Future<void> fetchSeasonalEquity(String tradeId) async {
    if (_seasonalEquity.containsKey(tradeId) || _loadingEquity.contains(tradeId)) return;
    
    _loadingEquity.add(tradeId);
    notifyListeners();

    try {
      final data = await _apiService.getSeasonalEquity(tradeId);
      _seasonalEquity[tradeId] = data;
    } catch (e) {
      print('Error fetching equity for $tradeId: $e');
    } finally {
      _loadingEquity.remove(tradeId);
      notifyListeners();
    }
  }

  void clearStatisticsCache(String tradeId) {
    _tradeStatistics.remove(tradeId);
    _seasonalEquity.remove(tradeId);
    _tradeStatisticsErrors.remove(tradeId);
    notifyListeners();
  }

  Future<void> subscribe(String tradeId) async {
    if (_userSettings == null) return;
    
    final oldSettings = _userSettings;
    final newSettings = _userSettings!.subscribe(tradeId);
    _userSettings = newSettings;
    notifyListeners();

    try {
      await _apiService.saveSeasonalStrategyUserSettings(newSettings);
      
      // Auto-enable short trading
      final trade = _trades.firstWhere((t) => t.id == tradeId, orElse: () => SeasonalTrade(openDate: '', closeDate: '', symbol: '', direction: ''));
      if (trade.id != null && trade.direction == 'Short') {
         await enableShortTrading();
      }
    } catch (e) {
      _userSettings = oldSettings;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unsubscribe(String tradeId) async {
    if (_userSettings == null) return;

    final oldSettings = _userSettings;
    final newSettings = _userSettings!.unsubscribe(tradeId);
    _userSettings = newSettings;
    notifyListeners();

    try {
      await _apiService.saveSeasonalStrategyUserSettings(newSettings);
    } catch (e) {
      _userSettings = oldSettings;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateThread(String tradeId, int thread) async {
    if (_userSettings == null) return;

    final oldSettings = _userSettings;
    final newSettings = _userSettings!.assignTradeToThread(tradeId, thread);
    _userSettings = newSettings;
    notifyListeners();

    try {
      final updated = await _apiService.updateThreadAssignment(tradeId, thread);
      _userSettings = updated;
      notifyListeners();
    } catch (e) {
      _userSettings = oldSettings;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setMode(String tradeId, bool isLive) async {
    if (_userSettings == null) return;
    
    // Check verification
    if (isLive) {
      if (!(_user?.alpacaLiveAccount?.verified ?? false)) throw Exception('Live account not verified');
    } else {
       if (!(_user?.alpacaPaperAccount?.verified ?? false)) throw Exception('Paper account not verified');
    }

    final oldSettings = _userSettings;
    var newSettings = _userSettings!;
    
    if (isLive) {
        newSettings = newSettings.toggleLive(tradeId, true);
        newSettings = newSettings.togglePaper(tradeId, false);
    } else {
        newSettings = newSettings.togglePaper(tradeId, true);
        newSettings = newSettings.toggleLive(tradeId, false);
    }
    
    _userSettings = newSettings;
    notifyListeners();

    try {
      await _apiService.saveSeasonalStrategyUserSettings(newSettings);
    } catch (e) {
      _userSettings = oldSettings;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> switchTradesTo(bool toLive) async {
    if (_userSettings == null) return;
    
    final oldSettings = _userSettings;
    
    try {
      SeasonalStrategyUserSettings newRules;
      
      if (toLive) {
        final currentPaper = Set<String>.from(_userSettings!.paperTradeIds);
        final currentLive = Set<String>.from(_userSettings!.liveTradeIds);
        currentLive.addAll(currentPaper);
        newRules = _userSettings!.copyWith(
          liveTradeIds: currentLive.toList(),
          paperTradeIds: [],
        );
      } else {
        final currentPaper = Set<String>.from(_userSettings!.paperTradeIds);
        final currentLive = Set<String>.from(_userSettings!.liveTradeIds);
        currentPaper.addAll(currentLive);
        newRules = _userSettings!.copyWith(
          paperTradeIds: currentPaper.toList(),
          liveTradeIds: [],
        );
      }
      
      _userSettings = newRules;
      notifyListeners();
      
      await _apiService.saveSeasonalStrategyUserSettings(newRules);
    } catch (e) {
      _userSettings = oldSettings;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> enableShortTrading() async {
    if (_user == null) return;
    
    var paper = _user!.alpacaPaperAccount;
    var live = _user!.alpacaLiveAccount;
    bool needsUpdate = false;

    if (paper != null && !paper.allowShortTrading) {
        paper = paper.copyWith(allowShortTrading: true);
        needsUpdate = true;
    }
    if (live != null && !live.allowShortTrading) {
        live = live.copyWith(allowShortTrading: true);
        needsUpdate = true;
    }

    if (needsUpdate) {
        final updatedUser = _user!.copyWith(
            alpacaPaperAccount: paper,
            alpacaLiveAccount: live,
        );
        _user = updatedUser;
        notifyListeners();
        
        try {
            final saved = await _apiService.saveUser(updatedUser);
            _user = saved;
            notifyListeners();
        } catch (e) {
            // Revert silently or log
            print('Failed to auto-enable short trading: $e');
        }
    }
  }
  
  SeasonalTradeAggregateStatistic calculateAggregate(List<SeasonalTradeSingleStatistic> stats) {
      return SeasonalTradeAggregateStatistic.fromSingleStats(stats);
  }
}

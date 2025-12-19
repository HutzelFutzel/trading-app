import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/seasonal_trade.dart';
import '../../models/seasonal_strategy_user_settings.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/seasonal_trade_view.dart';
import '../../screens/account_screen.dart';
import '../common/custom_text_field.dart';

class SeasonalTradesUserView extends StatefulWidget {
  const SeasonalTradesUserView({super.key});

  @override
  State<SeasonalTradesUserView> createState() => _SeasonalTradesUserViewState();
}

enum SortOption { comingNext, openDate, symbol, thread }
enum TradeViewMode { subscribed, unsubscribed }

class _SeasonalTradesUserViewState extends State<SeasonalTradesUserView> {
  List<SeasonalTrade> _trades = [];
  
  bool _isLoading = true;
  String? _error;
  late ApiService _apiService;
  
  SeasonalStrategyUserSettings? _userRules;
  User? _user;

  // Filter & Sort State
  String _filterText = '';
  bool _showPaperActive = false;
  bool _showLiveActive = false;
  int? _filterThread; // Null means all threads
  SortOption _sortBy = SortOption.comingNext;
  TradeViewMode _viewMode = TradeViewMode.subscribed;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    _init();
  }

  Future<void> _init() async {
    try {
      await Future.wait([
        _fetchTrades(),
        _fetchRules(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTrades() async {
    try {
      setState(() => _isLoading = true);
      
      final trades = await _apiService.getSeasonalTrades();
      
      if (mounted) {
        setState(() {
          _trades = trades;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load trades: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRules() async {
    try {
      final results = await Future.wait([
        _apiService.getSeasonalTradeRules(),
        _apiService.getSeasonalStrategyUserSettings(),
        _apiService.getUser(),
      ]);
      
      if (mounted) {
        setState(() {
            _userRules = results[1] as SeasonalStrategyUserSettings;
            _user = results[2] as User;
        });
      }
    } catch (_) {
      // Fail silently for rules
    }
  }

  Future<void> _openTrade(SeasonalTrade trade) async {
    if (trade.id == null) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonalTradeView(trade: trade, userSettings: _userRules),
      ),
    );
    _fetchRules(); // Refresh settings after return
  }

  Future<void> _subscribe(SeasonalTrade trade) async {
    if (_userRules == null || trade.id == null) return;
    
    // Optimistic Update
    final oldRules = _userRules;
    final newRules = _userRules!.subscribe(trade.id!);
    
    setState(() => _userRules = newRules);

    try {
      await _apiService.saveSeasonalStrategyUserSettings(newRules);
      
      // Auto-enable short trading for Short trades
      if (trade.direction == 'Short') {
         await _enableShortTrading();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userRules = oldRules);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to subscribe: $e')),
        );
      }
    }
  }

  Future<void> _enableShortTrading() async {
    try {
      // Fetch fresh user data to avoid overwriting other changes
      final user = await _apiService.getUser();
      
      bool needsUpdate = false;
      
      var paper = user.alpacaPaperAccount;
      var live = user.alpacaLiveAccount;

      if (paper != null && !paper.allowShortTrading) {
        paper = paper.copyWith(allowShortTrading: true);
        needsUpdate = true;
      }
      
      if (live != null && !live.allowShortTrading) {
        live = live.copyWith(allowShortTrading: true);
        needsUpdate = true;
      }

      if (needsUpdate) {
          final updatedUser = user.copyWith(
            alpacaPaperAccount: paper,
            alpacaLiveAccount: live,
          );
          await _apiService.saveUser(updatedUser);
          if (mounted) {
            setState(() => _user = updatedUser);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Automatically enabled Short Trading for your Alpaca accounts')),
            );
          }
      } else {
         if (mounted) setState(() => _user = user);
      }
    } catch (_) {
       // Fail silently on secondary update
    }
  }

  Future<void> _switchTradesTo(bool toLive) async {
    if (_userRules == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      SeasonalStrategyUserSettings newRules;
      
      if (toLive) {
        // Move Paper -> Live
        final currentPaper = Set<String>.from(_userRules!.paperTradeIds);
        final currentLive = Set<String>.from(_userRules!.liveTradeIds);
        
        // Add all paper to live
        currentLive.addAll(currentPaper);
        
        // Remove all from paper (Move logic)
        // Or should we keep them? "Make... to live" implies changing the target.
        // I will clear paper to avoid double execution if paper is ever re-enabled unexpectedly.
        
        newRules = _userRules!.copyWith(
          liveTradeIds: currentLive.toList(),
          paperTradeIds: [], // Clear paper
        );
      } else {
        // Move Live -> Paper
        final currentPaper = Set<String>.from(_userRules!.paperTradeIds);
        final currentLive = Set<String>.from(_userRules!.liveTradeIds);
        
        currentPaper.addAll(currentLive);
        
        newRules = _userRules!.copyWith(
          paperTradeIds: currentPaper.toList(),
          liveTradeIds: [], // Clear live
        );
      }
      
      await _apiService.saveSeasonalStrategyUserSettings(newRules);
      
      if (mounted) {
        setState(() {
          _userRules = newRules;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Successfully moved all trades to ${toLive ? "Live" : "Paper"}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to switch trades: $e')),
        );
      }
    }
  }

  bool _isOngoing(SeasonalTrade trade) {
    final now = DateTime.now();
    try {
      final openParts = trade.openDate.split('-');
      final closeParts = trade.closeDate.split('-');
      
      final openMonth = int.parse(openParts[0]);
      final openDay = int.parse(openParts[1]);
      final closeMonth = int.parse(closeParts[0]);
      final closeDay = int.parse(closeParts[1]);

      if (closeMonth < openMonth) {
        final currentMD = now.month * 100 + now.day;
        final openMD = openMonth * 100 + openDay;
        final closeMD = closeMonth * 100 + closeDay;
        
        return currentMD >= openMD || currentMD <= closeMD;
      } else {
        final currentMD = now.month * 100 + now.day;
        final openMD = openMonth * 100 + openDay;
        final closeMD = closeMonth * 100 + closeDay;
        return currentMD >= openMD && currentMD <= closeMD;
      }
    } catch (e) {
      return false;
    }
  }

  int _daysUntilOpen(String dateStr) {
    try {
      final now = DateTime.now();
      final parts = dateStr.split('-');
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      
      var nextDate = DateTime(now.year, month, day);
      if (nextDate.isBefore(now.subtract(const Duration(days: 1)))) { 
        nextDate = DateTime(now.year + 1, month, day);
      }
      return nextDate.difference(now).inDays;
    } catch (_) {
      return 999;
    }
  }
  
  int _getThreadForTrade(String? tradeId) {
    if (tradeId == null || _userRules == null) return 1;
    return _userRules!.getThreadForTrade(tradeId);
  }
  
  bool _getPaperActive(String? tradeId) {
    if (tradeId == null || _userRules == null) return false;
    return _userRules!.isPaperActive(tradeId);
  }
  
  bool _getLiveActive(String? tradeId) {
    if (tradeId == null || _userRules == null) return false;
    return _userRules!.isLiveActive(tradeId);
  }

  List<int> get _availableThreads {
    final threads = _trades.map((e) => _getThreadForTrade(e.id)).toSet().toList();
    threads.sort();
    return threads;
  }

  List<SeasonalTrade> get _filteredTrades {
    var list = _trades.where((t) {
      if (!t.verifiedByApi) return false;

      final paperActive = _getPaperActive(t.id);
      final liveActive = _getLiveActive(t.id);
      final thread = _getThreadForTrade(t.id);
      final isSubscribed = paperActive || liveActive; // Simplified subscription check

      // View Mode Filter
      if (_viewMode == TradeViewMode.subscribed && !isSubscribed) return false;
      if (_viewMode == TradeViewMode.unsubscribed && isSubscribed) return false;

      final matchesText = t.symbol.toLowerCase().contains(_filterText.toLowerCase());
      
      // Secondary Filters (Only apply in Subscribed mode)
      bool matchesSecondary = true;
      if (_viewMode == TradeViewMode.subscribed) {
         final matchesPaper = !_showPaperActive || paperActive;
         final matchesLive = !_showLiveActive || liveActive;
         final matchesThread = _filterThread == null || thread == _filterThread;
         matchesSecondary = matchesPaper && matchesLive && matchesThread;
      }

      return matchesText && matchesSecondary;
    }).toList();

    list.sort((a, b) {
      final ongoingA = _isOngoing(a);
      final ongoingB = _isOngoing(b);

      if (ongoingA && !ongoingB) return -1;
      if (!ongoingA && ongoingB) return 1;

      switch (_sortBy) {
        case SortOption.comingNext:
          return _daysUntilOpen(a.openDate).compareTo(_daysUntilOpen(b.openDate));
        case SortOption.openDate:
           return a.openDate.compareTo(b.openDate);
        case SortOption.symbol:
          return a.symbol.compareTo(b.symbol);
        case SortOption.thread:
          return _getThreadForTrade(a.id).compareTo(_getThreadForTrade(b.id));
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: AppTextStyles.bodyLarge));

    final displayTrades = _filteredTrades;

          final paperAccount = _user?.alpacaPaperAccount;
    final isPaperEnabled = paperAccount?.enabled ?? false;
    final isPaperVerified = paperAccount?.verified ?? false;
    final isPaperReady = paperAccount != null && isPaperEnabled && isPaperVerified;

    final liveAccount = _user?.alpacaLiveAccount;
    final isLiveEnabled = liveAccount?.enabled ?? false;
    final isLiveVerified = liveAccount?.verified ?? false;
    final isLiveReady = liveAccount != null && isLiveEnabled && isLiveVerified;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          if (_userRules != null && _user != null)
             _buildAccountWarnings(),
          Expanded(
            child: displayTrades.isEmpty && _viewMode == TradeViewMode.subscribed 
                ? _buildEmptyState()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: displayTrades.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trade = displayTrades[index];
                final thread = _getThreadForTrade(trade.id);
                final paperActive = _getPaperActive(trade.id);
                final liveActive = _getLiveActive(trade.id);
                final isSubscribed = paperActive || liveActive;
                
                return _UserTradeCard(
                    trade: trade, 
                    thread: thread,
                    paperActive: paperActive,
                    liveActive: liveActive,
                    isSubscribed: isSubscribed,
                    onTap: () => _openTrade(trade), 
                    onSubscribe: () => _subscribe(trade),
                    userRules: _userRules,
                    isPaperReady: isPaperReady,
                    isLiveReady: isLiveReady,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountWarnings() {
    final paperCount = _userRules?.paperTradeIds.length ?? 0;
    final liveCount = _userRules?.liveTradeIds.length ?? 0;
    
    // Check Paper Status
    final paperAccount = _user?.alpacaPaperAccount;
    final isPaperEnabled = paperAccount?.enabled ?? false;
    final isPaperVerified = paperAccount?.verified ?? false;
    final isPaperReady = paperAccount != null && isPaperEnabled && isPaperVerified;

    // Check Live Status
    final liveAccount = _user?.alpacaLiveAccount;
    final isLiveEnabled = liveAccount?.enabled ?? false;
    final isLiveVerified = liveAccount?.verified ?? false;
    final isLiveReady = liveAccount != null && isLiveEnabled && isLiveVerified;

    List<Widget> warnings = [];

    // Warning 1: Paper Active but Broken
    if (paperCount > 0 && !isPaperReady) {
       warnings.add(_buildWarningBanner(
         title: 'Paper Trading Issue',
         message: 'You have $paperCount paper trades, but your Paper account is ${!isPaperEnabled ? "disabled" : "not verified"}.',
         actionLabel: 'Switch to Live',
         canSwitch: isLiveReady,
         onSwitch: () => _switchTradesTo(true),
       ));
    }

    // Warning 2: Live Active but Broken
    if (liveCount > 0 && !isLiveReady) {
       warnings.add(_buildWarningBanner(
         title: 'Live Trading Issue',
         message: 'You have $liveCount live trades, but your Live account is ${!isLiveEnabled ? "disabled" : "not verified"}.',
         actionLabel: 'Switch to Paper',
         canSwitch: isPaperReady,
         onSwitch: () => _switchTradesTo(false),
       ));
    }

    if (warnings.isEmpty) return const SizedBox.shrink();

    return Column(children: warnings);
  }

  Widget _buildWarningBanner({
    required String title,
    required String message,
    required String actionLabel,
    required bool canSwitch,
    required VoidCallback onSwitch,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const AccountScreen())
                ).then((_) => _fetchRules()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Settings', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              if (canSwitch)
                FilledButton(
                  onPressed: onSwitch,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textDisabled.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No Active Trades',
            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Subscribe to seasonal trades to track them here.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => setState(() => _viewMode = TradeViewMode.unsubscribed),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Discover Trades'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16, 
        right: 16, 
        bottom: 16, 
        top: MediaQuery.of(context).padding.top + 16
      ),
      child: Column(
        children: [
          CustomTextField(
            hint: 'Search Symbol',
            prefixIcon: const Icon(Icons.search),
            onChanged: (val) => setState(() => _filterText = val),
          ),
          const SizedBox(height: 16),
          
          // View Toggle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildViewToggleBtn('My Trades', TradeViewMode.subscribed)),
                Expanded(child: _buildViewToggleBtn('Discover', TradeViewMode.unsubscribed)),
              ],
            ),
          ),
          
          if (_viewMode == TradeViewMode.subscribed) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortMenu(),
                  const SizedBox(width: 8),
                  _buildThreadFilter(),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Paper', 
                    isActive: _showPaperActive, 
                    onChanged: (val) => setState(() {
                      _showPaperActive = val;
                      if (val) _showLiveActive = false;
                    }),
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Live', 
                    isActive: _showLiveActive, 
                    onChanged: (val) => setState(() {
                      _showLiveActive = val;
                      if (val) _showPaperActive = false;
                    }),
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewToggleBtn(String label, TradeViewMode mode) {
    final isSelected = _viewMode == mode;
    
    // Count trades for each mode
    final count = _trades.where((t) {
      if (!t.verifiedByApi) return false;
      final isSubscribed = _getPaperActive(t.id) || _getLiveActive(t.id);
      return mode == TradeViewMode.subscribed ? isSubscribed : !isSubscribed;
    }).length;

    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceHighlight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Text(
                  count.toString(),
                  key: ValueKey<int>(count),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortMenu() {
     return MenuAnchor(
      builder: (context, controller, child) {
        return _buildChip(
          label: _getSortLabel(_sortBy),
          icon: Icons.sort,
          onTap: () {
             if (controller.isOpen) controller.close(); else controller.open();
          },
        );
      },
      menuChildren: [
        MenuItemButton(onPressed: () => setState(() => _sortBy = SortOption.comingNext), child: const Text('Coming Next')),
        MenuItemButton(onPressed: () => setState(() => _sortBy = SortOption.openDate), child: const Text('Sort by Date')),
        MenuItemButton(onPressed: () => setState(() => _sortBy = SortOption.symbol), child: const Text('Sort by Symbol')),
        MenuItemButton(onPressed: () => setState(() => _sortBy = SortOption.thread), child: const Text('Sort by Thread')),
      ],
    );
  }

  Widget _buildThreadFilter() {
    return MenuAnchor(
      builder: (context, controller, child) {
        return _buildChip(
          label: _filterThread == null ? 'All Threads' : 'Thread $_filterThread',
          icon: Icons.layers,
          onTap: () {
            if (controller.isOpen) controller.close(); else controller.open();
          },
          isActive: _filterThread != null,
        );
      },
       menuChildren: [
         MenuItemButton(onPressed: () => setState(() => _filterThread = null), child: const Text('All Threads')),
         ..._availableThreads.map((t) => 
            MenuItemButton(onPressed: () => setState(() => _filterThread = t), child: Text('Thread $t'))
         )
       ],
    );
  }
  
  Widget _buildChip({required String label, required IconData icon, required VoidCallback onTap, bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required bool isActive, required Function(bool) onChanged, required Color color}) {
    return InkWell(
      onTap: () => onChanged(!isActive),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
             Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: isActive ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isActive ? Colors.transparent : AppColors.textDisabled, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.comingNext: return 'Coming Next';
      case SortOption.openDate: return 'Date';
      case SortOption.symbol: return 'Symbol';
      case SortOption.thread: return 'Thread';
    }
  }
}

class _UserTradeCard extends StatelessWidget {
  final SeasonalTrade trade;
  final int thread;
  final bool paperActive;
  final bool liveActive;
  final bool isSubscribed;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  final SeasonalStrategyUserSettings? userRules;
  final bool isPaperReady;
  final bool isLiveReady;

  const _UserTradeCard({
      required this.trade, 
      required this.thread,
      required this.paperActive,
      required this.liveActive,
      required this.isSubscribed,
      required this.onTap, 
      required this.onSubscribe,
      this.userRules,
      this.isPaperReady = true,
      this.isLiveReady = true,
  });
  
  Color _getThreadColor(int thread) {
    if (AppTheme.threadColors.containsKey(thread)) return AppTheme.threadColors[thread]!;
    return Colors.primaries[thread % Colors.primaries.length];
  }

  String _formatDatePretty(String mmdd) {
    try {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final parts = mmdd.split('-');
      final m = int.parse(parts[0]);
      final d = int.parse(parts[1]);
      return '${months[m - 1]} $d';
    } catch (_) {
      return mmdd;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSubscribed) {
      return _buildSubscribedCard();
    } else {
      return _buildUnsubscribedCard();
    }
  }

  Widget _buildSubscribedCard() {
    final threadColor = _getThreadColor(thread);
    final isLong = trade.direction == 'Long';

    // Determine if disabled based on account status
    // If trade uses paper but paper is not ready -> disabled
    // If trade uses live but live is not ready -> disabled
    // If trade uses both, disabled if EITHER is not ready? Or only if BOTH are not ready?
    // "respective environment... is !enabled"
    // Let's say if ANY active environment is broken, we dim it.
    final paperBroken = paperActive && !isPaperReady;
    final liveBroken = liveActive && !isLiveReady;
    final isBroken = paperBroken || liveBroken;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isBroken 
            ? Border.all(color: AppColors.error.withOpacity(0.5))
            : Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          if (isBroken)
             BoxShadow(
                color: AppColors.error.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
             ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: isBroken ? 0.7 : 1.0,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Thread Strip
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: threadColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _buildHeader(isLong),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDates(),
                              Row(
                                children: [
                                  if (paperActive) ...[
                                    _buildIndicator(
                                      label: 'PAPER', 
                                      color: paperBroken ? AppColors.textDisabled : AppColors.accent,
                                      isError: paperBroken
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (liveActive)
                                    _buildIndicator(
                                      label: 'LIVE', 
                                      color: liveBroken ? AppColors.textDisabled : AppColors.error,
                                      isError: liveBroken
                                    ),
                                  
                                  if (!paperActive && !liveActive)
                                    Text(
                                      'Inactive',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textDisabled,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnsubscribedCard() {
    final isLong = trade.direction == 'Long';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildHeader(isLong),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDates(),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6)
                        ),
                        child: Row(
                            children: [
                                const Icon(Icons.lock_outline, size: 12, color: AppColors.textDisabled),
                                const SizedBox(width: 4),
                                Text('Not Subscribed', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                            ],
                        ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Strip
          InkWell(
            onTap: onSubscribe,
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                   const SizedBox(width: 8),
                   Text(
                     'Subscribe to Trade',
                     style: TextStyle(
                       color: AppColors.primary,
                       fontWeight: FontWeight.bold,
                       fontSize: 14,
                     ),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isLong) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  trade.symbol,
                  style: AppTextStyles.headlineLarge.copyWith(fontSize: 18),
                ),
                const SizedBox(width: 8),
                if (trade.name != null)
                  Expanded(
                    child: Text(
                      trade.name!,
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: (isLong ? AppColors.long : AppColors.short).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isLong ? Icons.trending_up : Icons.trending_down,
              size: 20,
              color: isLong ? AppColors.long : AppColors.short,
            ),
          ),
        ],
      );
  }

  Widget _buildDates() {
      return Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            '${_formatDatePretty(trade.openDate)} - ${_formatDatePretty(trade.closeDate)}',
            style: AppTextStyles.monoMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      );
  }

  Widget _buildIndicator({required String label, required Color color, bool isError = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
           color: isError ? AppColors.error : color.withOpacity(0.5), 
           width: isError ? 1.0 : 0.5
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isError) ...[
             const Icon(Icons.warning, size: 10, color: AppColors.error),
             const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isError ? AppColors.error : color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/seasonal_trade.dart';
import '../../models/seasonal_strategy_user_settings.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/seasonal_trade_view.dart';

class SeasonalTradesUserView extends StatefulWidget {
  const SeasonalTradesUserView({super.key});

  @override
  State<SeasonalTradesUserView> createState() => _SeasonalTradesUserViewState();
}

enum SortOption { comingNext, openDate, symbol, thread }

class _SeasonalTradesUserViewState extends State<SeasonalTradesUserView> {
  List<SeasonalTrade> _trades = [];
  
  bool _isLoading = true;
  String? _error;
  late ApiService _apiService;
  
  SeasonalStrategyUserSettings? _userRules;

  // Filter & Sort State
  String _filterText = '';
  bool _showPaperActive = false;
  bool _showLiveActive = false;
  int? _filterThread; // Null means all threads
  SortOption _sortBy = SortOption.comingNext;

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
      ]);
      
      if (mounted) {
        setState(() {
            _userRules = results[1] as SeasonalStrategyUserSettings;
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

      final matchesText = t.symbol.toLowerCase().contains(_filterText.toLowerCase());
      final matchesPaper = !_showPaperActive || paperActive;
      final matchesLive = !_showLiveActive || liveActive;
      final matchesThread = _filterThread == null || thread == _filterThread;
      return matchesText && matchesPaper && matchesLive && matchesThread;
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: displayTrades.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trade = displayTrades[index];
                final thread = _getThreadForTrade(trade.id);
                final paperActive = _getPaperActive(trade.id);
                final liveActive = _getLiveActive(trade.id);
                
                return _UserTradeCard(
                    trade: trade, 
                    thread: thread,
                    paperActive: paperActive,
                    liveActive: liveActive,
                    onTap: () => _openTrade(trade), 
                    userRules: _userRules,
                );
              },
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
          TextField(
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search Symbol',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => _filterText = val),
          ),
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
                  onChanged: (val) => setState(() => _showPaperActive = val),
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Live', 
                  isActive: _showLiveActive, 
                  onChanged: (val) => setState(() => _showLiveActive = val),
                  color: AppColors.error,
                ),
              ],
            ),
          ),
        ],
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
  final VoidCallback onTap;
  final SeasonalStrategyUserSettings? userRules;

  const _UserTradeCard({
      required this.trade, 
      required this.thread,
      required this.paperActive,
      required this.liveActive,
      required this.onTap, 
      this.userRules,
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
    final threadColor = _getThreadColor(thread);
    final isLong = trade.direction == 'Long';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Thread Indicator Strip
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Symbol
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trade.symbol,
                                  style: AppTextStyles.headlineLarge,
                                ),
                                if (trade.name != null)
                                  Text(
                                    trade.name!,
                                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          
                          // Direction Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isLong ? AppColors.long : AppColors.short).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (isLong ? AppColors.long : AppColors.short).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              trade.direction.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isLong ? AppColors.long : AppColors.short,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Dates and Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '${_formatDatePretty(trade.openDate)} - ${_formatDatePretty(trade.closeDate)}',
                                style: AppTextStyles.monoMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          
                          // Active Indicators
                          Row(
                            children: [
                              if (paperActive) ...[
                                _buildIndicator(label: 'PAPER', color: AppColors.accent),
                                const SizedBox(width: 8),
                              ],
                              if (liveActive)
                                _buildIndicator(label: 'LIVE', color: AppColors.error),
                              
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
    );
  }
  
  Widget _buildIndicator({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

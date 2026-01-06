import 'package:flutter/material.dart';
import '../../models/seasonal_trade.dart';
import '../../models/seasonal_strategy_user_settings.dart';
import '../../models/user.dart';
import '../../services/seasonal_data_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/seasonal_trade_view.dart';
import '../../screens/account_screen.dart';
import '../common/custom_text_field.dart';
import 'seasonal_trades_calendar.dart';

class SeasonalTradesUserView extends StatefulWidget {
  const SeasonalTradesUserView({super.key});

  @override
  State<SeasonalTradesUserView> createState() => _SeasonalTradesUserViewState();
}

enum SortOption { comingNext, openDate, symbol, thread }
enum TradeViewMode { subscribed, unsubscribed }

class _SeasonalTradesUserViewState extends State<SeasonalTradesUserView> {
  // Filter & Sort State
  String _filterText = '';
  bool _showPaperActive = false;
  bool _showLiveActive = false;
  int? _filterThread; 
  SortOption _sortBy = SortOption.comingNext;
  TradeViewMode _viewMode = TradeViewMode.subscribed;
  String? _loadingTradeId;

  @override
  void initState() {
    super.initState();
    // Trigger fetch on init
    SeasonalDataService().fetchData().then((_) {
      if (mounted) {
        SeasonalDataService().fetchAllStatistics();
      }
    });
  }

  Future<void> _openTrade(SeasonalTrade trade) async {
    if (trade.id == null) return;
    
    setState(() {
      _loadingTradeId = trade.id;
    });

    try {
      await Future.wait([
        SeasonalDataService().fetchStatistics(trade.id!),
        SeasonalDataService().fetchSeasonalEquity(trade.id!),
      ]);
    } catch (_) {
      // Ignore errors, let view handle
    }

    if (!mounted) return;

    setState(() {
      _loadingTradeId = null;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonalTradeView(trade: trade),
      ),
    );
  }

  // Helpers Logic
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SeasonalDataService(),
      builder: (context, _) {
        final service = SeasonalDataService();
        final trades = service.trades;
        final userRules = service.userSettings;
        final user = service.user;
        final isLoading = service.isLoading && trades.isEmpty;
        final error = service.error;

        if (isLoading) return const Center(child: CircularProgressIndicator());
        if (error != null && trades.isEmpty) return Center(child: Text(error, style: AppTextStyles.bodyLarge));

        // Logic Helpers using current data
        int getThreadForTrade(String? tradeId) {
          if (tradeId == null || userRules == null) return 1;
          return userRules.getThreadForTrade(tradeId);
        }
        
        bool getPaperActive(String? tradeId) {
          if (tradeId == null || userRules == null) return false;
          return userRules.isPaperActive(tradeId);
        }
        
        bool getLiveActive(String? tradeId) {
          if (tradeId == null || userRules == null) return false;
          return userRules.isLiveActive(tradeId);
        }

        List<int> availableThreads = [];
        if (trades.isNotEmpty) {
           availableThreads = trades.map((e) => getThreadForTrade(e.id)).toSet().toList();
           availableThreads.sort();
        }

        // Filtering
        var displayTrades = trades.where((t) {
          if (!t.verifiedByApi) return false;

          final paperActive = getPaperActive(t.id);
          final liveActive = getLiveActive(t.id);
          final thread = getThreadForTrade(t.id);
          final isSubscribed = paperActive || liveActive;

          if (_viewMode == TradeViewMode.subscribed && !isSubscribed) return false;
          if (_viewMode == TradeViewMode.unsubscribed && isSubscribed) return false;

          final matchesText = t.symbol.toLowerCase().contains(_filterText.toLowerCase());
          
          bool matchesSecondary = true;
          if (_viewMode == TradeViewMode.subscribed) {
             final matchesPaper = !_showPaperActive || paperActive;
             final matchesLive = !_showLiveActive || liveActive;
             final matchesThread = _filterThread == null || thread == _filterThread;
             matchesSecondary = matchesPaper && matchesLive && matchesThread;
          }

          return matchesText && matchesSecondary;
        }).toList();

        displayTrades.sort((a, b) {
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
              return getThreadForTrade(a.id).compareTo(getThreadForTrade(b.id));
          }
        });

        // Account Status
        final paperAccount = user?.alpacaPaperAccount;
        final isPaperReady = paperAccount != null && paperAccount.enabled && paperAccount.verified;
        final liveAccount = user?.alpacaLiveAccount;
        final isLiveReady = liveAccount != null && liveAccount.enabled && liveAccount.verified;

        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

        if (isLandscape) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: trades.isNotEmpty 
                ? SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SeasonalTradesCalendar(
                        trades: trades, 
                        userSettings: userRules
                      ),
                    ),
                  )
                : _buildEmptyState(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(trades)),
              
              if (userRules != null && user != null)
                 SliverToBoxAdapter(child: _buildAccountWarnings(userRules, user, isPaperReady, isLiveReady)),
              
              if (trades.isNotEmpty)
                 SliverToBoxAdapter(
                   child: Container(
                     margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                     decoration: BoxDecoration(
                       color: AppColors.surface,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: 0.2),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                     clipBehavior: Clip.antiAlias,
                     child: SeasonalTradesCalendar(
                       trades: trades, 
                       userSettings: userRules
                     ),
                   ),
                 ),

              if (displayTrades.isEmpty && _viewMode == TradeViewMode.subscribed)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trade = displayTrades[index];
                        final thread = getThreadForTrade(trade.id);
                        final paperActive = getPaperActive(trade.id);
                        final liveActive = getLiveActive(trade.id);
                        final isSubscribed = paperActive || liveActive;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _UserTradeCard(
                              trade: trade, 
                              thread: thread,
                              paperActive: paperActive,
                              liveActive: liveActive,
                              isSubscribed: isSubscribed,
                              isLoading: _loadingTradeId == trade.id,
                              onTap: () => _openTrade(trade), 
                              onSubscribe: () async {
                                 try {
                                   await SeasonalDataService().subscribe(trade.id!);
                                 } catch (e) {
                                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                 }
                              },
                              userRules: userRules,
                              isPaperReady: isPaperReady,
                              isLiveReady: isLiveReady,
                          ),
                        );
                      },
                      childCount: displayTrades.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildAccountWarnings(SeasonalStrategyUserSettings rules, User user, bool isPaperReady, bool isLiveReady) {
    final paperCount = rules.paperTradeIds.length;
    final liveCount = rules.liveTradeIds.length;
    final paperEnabled = user.alpacaPaperAccount?.enabled ?? false;
    final liveEnabled = user.alpacaLiveAccount?.enabled ?? false;

    List<Widget> warnings = [];

    if (paperCount > 0 && !isPaperReady) {
       warnings.add(_buildWarningBanner(
         title: 'Paper Trading Issue',
         message: 'You have $paperCount paper trades, but your Paper account is ${!paperEnabled ? "disabled" : "not verified"}.',
         actionLabel: 'Switch to Live',
         canSwitch: isLiveReady,
         onSwitch: () => SeasonalDataService().switchTradesTo(true),
       ));
    }

    if (liveCount > 0 && !isLiveReady) {
       warnings.add(_buildWarningBanner(
         title: 'Live Trading Issue',
         message: 'You have $liveCount live trades, but your Live account is ${!liveEnabled ? "disabled" : "not verified"}.',
         actionLabel: 'Switch to Paper',
         canSwitch: isPaperReady,
         onSwitch: () => SeasonalDataService().switchTradesTo(false),
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
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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
                ).then((_) => SeasonalDataService().fetchData(forceRefresh: true)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textDisabled.withValues(alpha: 0.5)),
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

  Widget _buildHeader(List<SeasonalTrade> trades) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildViewToggleBtn('My Trades', TradeViewMode.subscribed, trades)),
                Expanded(child: _buildViewToggleBtn('Discover', TradeViewMode.unsubscribed, trades)),
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
                  _buildThreadFilter(trades),
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

  Widget _buildViewToggleBtn(String label, TradeViewMode mode, List<SeasonalTrade> trades) {
    final isSelected = _viewMode == mode;
    
    final userRules = SeasonalDataService().userSettings;
    
    // Count trades for each mode
    final count = trades.where((t) {
      if (!t.verifiedByApi || t.id == null) return false;
      if (userRules == null) return mode == TradeViewMode.unsubscribed;
      
      final isSubscribed = userRules.isPaperActive(t.id!) || userRules.isLiveActive(t.id!);
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
                  color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
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

  Widget _buildThreadFilter(List<SeasonalTrade> trades) {
    final userRules = SeasonalDataService().userSettings;
    List<int> threads = [];
    if (userRules != null) {
        threads = trades.map((e) => userRules.getThreadForTrade(e.id ?? '')).toSet().toList();
        threads.sort();
    }

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
         ...threads.map((t) => 
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
          color: isActive ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
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
          color: isActive ? color.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.white.withValues(alpha: 0.1),
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
  final bool isLoading;
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
      this.isLoading = false,
      required this.onTap, 
      required this.onSubscribe,
      this.userRules,
      this.isPaperReady = true,
      this.isLiveReady = true,
  });
  
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

  Color _getThreadColor(int thread) {
    if (AppTheme.threadColors.containsKey(thread)) return AppTheme.threadColors[thread]!;
    return Colors.primaries[thread % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    final service = SeasonalDataService();
    final stats = service.getStatistics(trade.id ?? '');
    final agg = service.calculateAggregate(stats);
    final isStatsLoading = service.isStatisticsLoading(trade.id ?? '');
    
    final isLong = trade.direction == 'Long';
    final directionColor = isLong ? AppColors.long : AppColors.short;
    
    // Status Logic
    final paperBroken = paperActive && !isPaperReady;
    final liveBroken = liveActive && !isLiveReady;
    final isBroken = (paperActive || liveActive) && (paperBroken || liveBroken);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
             color: isBroken ? AppColors.error.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Symbol
                    Text(
                      trade.symbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Direction Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: directionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLong ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 10,
                            color: directionColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            isLong ? 'LONG' : 'SHORT',
                            style: TextStyle(
                              color: directionColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Thread Badge (Only if subscribed)
                    if (isSubscribed) ...[
                      const SizedBox(width: 8),
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getThreadColor(thread).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getThreadColor(thread).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'T$thread',
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold,
                            color: _getThreadColor(thread),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Dates
                    Text(
                      '${_formatDatePretty(trade.openDate)} - ${_formatDatePretty(trade.closeDate)}',
                      style: AppTextStyles.monoMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Bottom Row: Stats & Action/Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Stats
                    Expanded(
                      child: isStatsLoading 
                        ? Row(
                            children: [
                              SizedBox(
                                width: 12, height: 12, 
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.textSecondary.withValues(alpha: 0.5)))
                              ),
                              const SizedBox(width: 6),
                              Text('Loading...', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11)),
                            ],
                          )
                        : (agg.totalTrades > 0)
                            ? Row(
                                children: [
                                  _buildStat('WIN', '${agg.winRate.toStringAsFixed(0)}%', AppColors.success),
                                  const SizedBox(width: 12),
                                  _buildStat(
                                    'AVG', 
                                    '${agg.averageProfitPercentage > 0 ? '+' : ''}${agg.averageProfitPercentage.toStringAsFixed(1)}%', 
                                    agg.averageProfitPercentage >= 0 ? AppColors.success : AppColors.error
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStat('YRS', '${agg.totalTrades}', AppColors.textSecondary),
                                ],
                              )
                            : Text('No stats', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11)),
                    ),
                    
                    // Right Side: Status (if subscribed) OR Subscribe Button
                    if (isSubscribed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (paperActive) ...[
                            _buildStatusDot('P', paperBroken ? AppColors.textDisabled : AppColors.accent, paperBroken),
                            if (liveActive) const SizedBox(width: 6),
                          ],
                          if (liveActive)
                            _buildStatusDot('L', liveBroken ? AppColors.textDisabled : AppColors.error, liveBroken),
                          
                          if (!paperActive && !liveActive)
                             Text('Inactive', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                        ],
                      )
                    else 
                      InkWell(
                        onTap: onSubscribe,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Subscribe',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatusDot(String label, Color color, bool isError) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: isError ? AppColors.error : color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isError ? AppColors.error : color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

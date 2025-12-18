import 'package:flutter/material.dart';
import '../../models/seasonal_trade.dart';
import '../../models/seasonal_strategy_user_settings.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/admin_seasonal_trade_edit_view.dart';
import '../../screens/admin_seasonal_trade_create_view.dart';
import 'seasonal_calendar_view.dart';

class SeasonalTradesAdminView extends StatefulWidget {
  const SeasonalTradesAdminView({super.key});

  @override
  State<SeasonalTradesAdminView> createState() => _SeasonalTradesAdminViewState();
}

enum SortOption { comingNext, openDate, symbol }

class _SeasonalTradesAdminViewState extends State<SeasonalTradesAdminView> {
  List<SeasonalTrade> _trades = [];
  
  bool _isLoading = true;
  String? _error;
  late ApiService _apiService;
  
  SeasonalStrategyUserSettings? _userRules;

  bool _isCalendarView = false;
  
  // Filter & Sort State
  String _filterText = '';
  // Removed paper/live active filters since they were removed from trade model
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
        _apiService.getSeasonalTradeRules(), // Not used here? Maybe clean up later
        _apiService.getSeasonalStrategyUserSettings()
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

  Future<void> _addTrade() async {
    if (_userRules == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminSeasonalTradeCreateView(userSettings: _userRules!)
      ),
    );

    if (result == true) {
      _init(); // Refresh all
    }
  }

  Future<void> _editTrade(SeasonalTrade trade) async {
    if (trade.id == null || _userRules == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminSeasonalTradeEditView(
          trade: trade,
          userSettings: _userRules!,
        )
      ),
    );

    if (result == true) {
      _init(); // Refresh all
    }
  }

  Future<void> _deleteTrade(SeasonalTrade trade) async {
    if (trade.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trade'),
        content: Text('Are you sure you want to delete ${trade.symbol}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      await _apiService.deleteSeasonalTrade(trade.id!);
      await _init(); // Refresh
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
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

  List<SeasonalTrade> get _filteredTrades {
    var list = _trades.where((t) {
      final matchesText = t.symbol.toLowerCase().contains(_filterText.toLowerCase());
      return matchesText;
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
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final displayTrades = _filteredTrades;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTrade,
        icon: const Icon(Icons.add),
        label: const Text('New Trade'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: _isCalendarView 
              ? SeasonalCalendarView(
                  trades: _trades, 
                  onEditTrade: _editTrade,
                  userRules: _userRules,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayTrades.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final trade = displayTrades[index];
                    return AdminTradeCard(
                        trade: trade, 
                        onEdit: () => _editTrade(trade), 
                        onDelete: () => _deleteTrade(trade),
                        userRules: _userRules,
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search Symbol',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _filterText = val),
                ),
              ),
              const SizedBox(width: 12),
              // View Toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildViewToggle(Icons.list, !_isCalendarView, () => setState(() => _isCalendarView = false)),
                    _buildViewToggle(Icons.calendar_month, _isCalendarView, () => setState(() => _isCalendarView = true)),
                  ],
                ),
              ),
            ],
          ),
          if (!_isCalendarView) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortMenu(),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildViewToggle(IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: isSelected ? BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ) : null,
        child: Icon(
          icon, 
          size: 20, 
          color: isSelected ? Colors.white : AppColors.textSecondary
        ),
      ),
    );
  }

  Widget _buildSortMenu() {
     return MenuAnchor(
      builder: (context, controller, child) {
        return FilterChip(
          label: Text(
            _getSortLabel(_sortBy),
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          avatar: const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), 
            side: BorderSide(color: Colors.white.withOpacity(0.1))
          ),
          onSelected: (_) {
             if (controller.isOpen) controller.close(); else controller.open();
          },
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: () => setState(() => _sortBy = SortOption.comingNext), 
          child: Text('Coming Next', style: AppTextStyles.bodyMedium)
        ),
        MenuItemButton(
          onPressed: () => setState(() => _sortBy = SortOption.openDate), 
          child: Text('Sort by Date', style: AppTextStyles.bodyMedium)
        ),
        MenuItemButton(
          onPressed: () => setState(() => _sortBy = SortOption.symbol), 
          child: Text('Sort by Symbol', style: AppTextStyles.bodyMedium)
        ),
      ],
    );
  }
  
  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.comingNext: return 'Coming Next';
      case SortOption.openDate: return 'Date';
      case SortOption.symbol: return 'Symbol';
    }
  }
}

class AdminTradeCard extends StatelessWidget {
  final SeasonalTrade trade;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final SeasonalStrategyUserSettings? userRules;

  const AdminTradeCard({
      super.key, 
      required this.trade, 
      required this.onEdit, 
      required this.onDelete,
      this.userRules,
  });

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
    final isOngoing = _isOngoing(trade);
    
    // We removed paper/live active state from global settings tracking in admin view
    // Since it's now per-user preference in SeasonalTradeUserSettings
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOngoing 
          ? AppColors.primary.withOpacity(0.05) 
          : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOngoing 
            ? AppColors.primary.withOpacity(0.5) 
            : Colors.white.withOpacity(0.05),
          width: isOngoing ? 1.5 : 1
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Main Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trade.symbol,
                          style: AppTextStyles.headlineLarge.copyWith(fontSize: 16),
                        ),
                        if (trade.name != null && trade.name!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              trade.name!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: trade.direction == 'Long' 
                              ? AppTheme.long.withOpacity(0.1) 
                              : AppTheme.short.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: trade.direction == 'Long' 
                                ? AppTheme.long.withOpacity(0.3) 
                                : AppTheme.short.withOpacity(0.3),
                            )
                          ),
                          child: Text(
                            trade.direction.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: trade.direction == 'Long' ? AppTheme.long : AppTheme.short,
                            ),
                          ),
                        ),
                        if (trade.verifiedByApi) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.verified, size: 16, color: AppColors.primary),
                        ] else ...[
                          const SizedBox(width: 8),
                          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDatePretty(trade.openDate)}  →  ${_formatDatePretty(trade.closeDate)}',
                      style: AppTextStyles.monoMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    if (!trade.verifiedByApi) ...[
                      const SizedBox(height: 4),
                      Text(
                        !trade.symbolExists 
                            ? 'Symbol not found in API' 
                            : (!trade.tradeDirectionPossible ? 'Trade direction not allowed' : 'Verification failed'),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isOngoing) ...[
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'ONGOING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                  ],
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

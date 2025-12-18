import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../models/executed_seasonal_trade.dart';
import '../../services/api_service.dart';
import '../common/glass_container.dart';

enum TradeStatusFilter { all, open, closed }

class ExecutedTradesView extends StatefulWidget {
  const ExecutedTradesView({super.key});

  @override
  State<ExecutedTradesView> createState() => _ExecutedTradesViewState();
}

class _ExecutedTradesViewState extends State<ExecutedTradesView> {
  List<ExecutedSeasonalTrade> _trades = [];
  bool _isLoading = true;
  String? _error;
  late ApiService _apiService;
  TradeStatusFilter _filter = TradeStatusFilter.all;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accountId = prefs.getString('selected_account_id');

      final String response = await rootBundle.loadString('assets/config/app_config.json');
      final data = json.decode(response);
      final baseUrl = data['apiBaseUrl'];
      _apiService = ApiService(baseUrl: baseUrl);
      _fetchTrades();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load config: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTrades() async {
    try {
      setState(() => _isLoading = true);
      // Fetch using the optional accountId
      final trades = await _apiService.getExecutedSeasonalTrades(accountId: _accountId);
      
      List<ExecutedSeasonalTrade> filteredTrades = trades;
      
      // Filter based on selected status
      if (_filter == TradeStatusFilter.open) {
        filteredTrades = trades.where((t) => !t.completed).toList();
      } else if (_filter == TradeStatusFilter.closed) {
        filteredTrades = trades.where((t) => t.completed).toList();
      }

      if (mounted) {
        setState(() {
          _trades = filteredTrades;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Text('Filter:', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          _buildFilterChip('All', TradeStatusFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Open', TradeStatusFilter.open),
          const SizedBox(width: 8),
          _buildFilterChip('Closed', TradeStatusFilter.closed),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, TradeStatusFilter status) {
    final isSelected = _filter == status;
    return InkWell(
      onTap: () {
        setState(() {
          _filter = status;
        });
        _fetchTrades();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.textDisabled.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchTrades, child: const Text('Retry'))
          ],
        ),
      );
    }
    
    if (_trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 64, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text('No executed trades found', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 8),
            Text('Try changing the filter or executing trades', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTrades,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _trades.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildTradeCard(_trades[index]),
      ),
    );
  }

  Widget _buildTradeCard(ExecutedSeasonalTrade trade) {
    final isProfit = (trade.profit ?? 0) >= 0;
    final profitColor = isProfit ? AppColors.success : AppColors.error;
    final currencyFormat = NumberFormat.simpleCurrency();
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');

    // Calculate outcome color
    final outcomeIsProfit = (trade.outcome ?? 0) >= 0;
    final outcomeColor = outcomeIsProfit ? AppColors.long : AppColors.short;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Symbol + Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  (trade.symbol ?? '?').substring(0, 1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trade.symbol ?? 'Unknown',
                          style: AppTextStyles.headlineLarge.copyWith(fontSize: 16),
                        ),
                        if (trade.direction != null) ...[
                          const SizedBox(width: 8),
                           Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: trade.direction == 'Long' ? AppColors.long.withOpacity(0.1) : AppColors.short.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              trade.direction!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: trade.direction == 'Long' ? AppColors.long : AppColors.short,
                              ),
                            ),
                          )
                        ]
                      ],
                    ),
                    if (trade.name != null)
                      Text(
                        trade.name!,
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.visible, // Ensure text wraps instead of truncating
                      ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: (trade.completed ? AppColors.textDisabled : AppColors.primary).withOpacity(0.1),
                   borderRadius: BorderRadius.circular(6),
                   border: Border.all(color: (trade.completed ? AppColors.textDisabled : AppColors.primary).withOpacity(0.3))
                 ),
                 child: Text(
                    trade.completed ? 'CLOSED' : 'OPEN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trade.completed ? AppColors.textDisabled : AppColors.primary,
                    ),
                  ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Dates Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPENED',
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(trade.actualOpenDate),
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'CLOSED',
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trade.actualCloseDate != null ? dateFormat.format(trade.actualCloseDate!) : '-',
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: trade.actualCloseDate != null ? null : AppColors.textDisabled),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats Grid
          Row(
            children: [
              _buildStat('Invested', currencyFormat.format(trade.invested)),
              _buildStat('Assets', '${trade.qty ?? trade.numberAssets}'),
              if (trade.outcome != null)
                 _buildStat(
                   'Outcome', 
                   currencyFormat.format(trade.outcome!),
                   valueColor: outcomeColor,
                 ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Performance Bar
          if (trade.profit != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: profitColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isProfit ? Icons.trending_up : Icons.trending_down,
                        color: profitColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        percentFormat.format(trade.profit! / 100), 
                        style: TextStyle(
                          color: profitColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (trade.maxRise != null || trade.maxDrop != null)
                    Row(
                      children: [
                        if (trade.maxDrop != null)
                          Text(
                            '↓${trade.maxDrop!.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        if (trade.maxDrop != null && trade.maxRise != null)
                           const SizedBox(width: 8),
                        if (trade.maxRise != null)
                          Text(
                            '↑${trade.maxRise!.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AppColors.success, fontSize: 12),
                          ),
                      ],
                    )
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
  
  Widget _buildStat(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600, 
              fontSize: 14,
              color: valueColor
            ),
          ),
        ],
      ),
    );
  }
}

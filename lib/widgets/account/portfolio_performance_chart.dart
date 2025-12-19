import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/portfolio_history.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';

class PortfolioPerformanceChart extends StatefulWidget {
  final String accountType;
  final String accountId;

  const PortfolioPerformanceChart({
    super.key,
    required this.accountType,
    required this.accountId,
  });

  @override
  State<PortfolioPerformanceChart> createState() => _PortfolioPerformanceChartState();
}

class _PortfolioPerformanceChartState extends State<PortfolioPerformanceChart> {
  late ApiService _apiService;
  PortfolioHistory? _history;
  bool _isLoading = false;
  String? _error;
  String _selectedTimeframe = '1M'; // Default 30 days

  // Mapping for UI labels to API params
  final Map<String, Map<String, String>> _timeframeConfig = {
    '1D': {'period': '1D', 'timeframe': '5Min'},
    '1W': {'period': '1W', 'timeframe': '1H'},
    '1M': {'period': '1M', 'timeframe': '1D'},
    '3M': {'period': '3M', 'timeframe': '1D'},
    '1Y': {'period': '1A', 'timeframe': '1D'},
    'All': {'period': 'all', 'timeframe': '1D'},
  };

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    _fetchHistory();
  }

  @override
  void didUpdateWidget(covariant PortfolioPerformanceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId || oldWidget.accountType != widget.accountType) {
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = _timeframeConfig[_selectedTimeframe]!;
      final history = await _apiService.getPortfolioHistory(
        widget.accountType,
        accountId: widget.accountId,
        period: config['period'],
        timeframe: config['timeframe'],
        extendedHours: true,
      );

      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onTimeframeChanged(String timeframe) {
    if (_selectedTimeframe != timeframe) {
      setState(() {
        _selectedTimeframe = timeframe;
      });
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Portfolio Performance',
                 style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (_history != null && _history!.equity.isNotEmpty)
                _buildProfitLossBadge(),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _buildContent(),
          ),
          const SizedBox(height: 24),
          _buildTimeframeSelector(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load chart',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_history == null || _history!.equity.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    return _buildChart();
  }

  Widget _buildProfitLossBadge() {
    if (_history!.equity.isEmpty) return const SizedBox.shrink();
    
    // Calculate P/L based on first and last point of the loaded history
    final first = _history!.equity.first;
    final last = _history!.equity.last;
    final diff = last - first;
    final pct = first != 0 ? (diff / first) * 100 : 0.0;
    final isProfit = diff >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isProfit ? AppTheme.profit : AppTheme.loss).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isProfit ? '+' : ''}${NumberFormat.simpleCurrency().format(diff)} (${pct.toStringAsFixed(2)}%)',
        style: TextStyle(
          color: isProfit ? AppTheme.profit : AppTheme.loss,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < _history!.equity.length; i++) {
        // Filter out 0 or nulls if needed, though API should be clean
        if (_history!.equity[i] > 0) {
            spots.add(FlSpot(i.toDouble(), _history!.equity[i]));
        }
    }

    if (spots.isEmpty) return const Center(child: Text('No valid data points'));

    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    // Add some padding
    final range = maxY - minY;
    final padding = range == 0 ? maxY * 0.1 : range * 0.1; // Handle flat line

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minY - padding,
        maxY: maxY + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.brandPrimary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.brandPrimary.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  NumberFormat.simpleCurrency().format(spot.y),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _timeframeConfig.keys.map((tf) {
          final isSelected = _selectedTimeframe == tf;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tf),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) _onTimeframeChanged(tf);
              },
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selectedColor: AppTheme.brandPrimary,
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }
}





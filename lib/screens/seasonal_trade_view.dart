import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/seasonal_trade.dart';
import '../models/seasonal_strategy_user_settings.dart';
import '../services/seasonal_data_service.dart';
import '../theme/app_theme.dart';
import '../models/seasonal_trade_statistic.dart';

class SeasonalTradeView extends StatefulWidget {
  final SeasonalTrade trade;

  const SeasonalTradeView({super.key, required this.trade});

  @override
  State<SeasonalTradeView> createState() => _SeasonalTradeViewState();
}

class _SeasonalTradeViewState extends State<SeasonalTradeView> {
  bool _showAllThreads = false;
  bool _isYearlyStatsExpanded = false;
  Timer? _debounceTimer;
  int? _startYearFilter;
  int? _selectedComparisonYear;
  
  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _selectedComparisonYear = DateTime.now().year;
    WidgetsBinding.instance.addPostFrameCallback((_) {
        SeasonalDataService().fetchData();
        if (widget.trade.id != null) {
          SeasonalDataService().fetchStatistics(widget.trade.id!);
          SeasonalDataService().fetchSeasonalEquity(widget.trade.id!);
        }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateThread(int thread) async {
    if (widget.trade.id == null) return;
    try {
      await SeasonalDataService().updateThread(widget.trade.id!, thread);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to save thread: $e')),
        );
      }
    }
  }

  Future<void> _setMode(bool isLive) async {
    if (widget.trade.id == null) return;
    try {
      await SeasonalDataService().setMode(widget.trade.id!, isLive);
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
         );
      }
    }
  }

  Future<void> _subscribe() async {
    if (widget.trade.id == null) return;
    try {
      await SeasonalDataService().subscribe(widget.trade.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to subscribe: $e')),
        );
      }
    }
  }

  Future<void> _unsubscribe() async {
      if (widget.trade.id == null) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Unsubscribe?', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text('This will remove the trade from all execution lists and threads.', style: TextStyle(color: AppColors.textSecondary)),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false), 
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true), 
                  child: const Text('Unsubscribe', style: TextStyle(color: AppColors.error))
                ),
            ],
        ),
      );
      
      if (confirmed != true) return;

      try {
        await SeasonalDataService().unsubscribe(widget.trade.id!);
      if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to unsubscribe: $e')),
          );
        }
      }
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 2) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        if (month >= 1 && month <= 12) {
          return '${_months[month - 1]} $day';
        }
      } else if (parts.length == 3) {
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        if (month >= 1 && month <= 12) {
          return '${_months[month - 1]} $day';
        }
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SeasonalDataService(),
      builder: (context, _) {
        final service = SeasonalDataService();
        final userSettings = service.userSettings;
        final user = service.user;
        
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.trade.symbol, style: AppTextStyles.headlineLarge),
        backgroundColor: AppColors.background,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withValues(alpha: 0.05),
            height: 1,
          ),
        ),
      ),
          body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDetailsSection(),
                  const SizedBox(height: 24),
                  _buildYearlyStatisticsSection(),
                  const SizedBox(height: 24),
                  _buildConfigSection(userSettings, user),
            ],
          ),
        ),
        );
      }
    );
  }

  int _dateToIndex(String mmDd) {
    try {
      final parts = mmDd.split('-');
      final m = int.parse(parts[0]);
      final d = int.parse(parts[1]);
      return DateTime(2024, m, d).difference(DateTime(2024, 1, 1)).inDays;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildSeasonalTrendChart() {
    final service = SeasonalDataService();
    final tradeId = widget.trade.id ?? '';
    final equityData = service.getSeasonalEquity(tradeId);
    final isLoading = service.isEquityLoading(tradeId);

    if (isLoading) {
        return const Center(child: CircularProgressIndicator());
    }

    if (equityData == null || equityData.isEmpty) {
        return const SizedBox(
            height: 100,
            child: Center(child: Text('No seasonal data available', style: TextStyle(color: AppColors.textSecondary))),
        );
    }

    // Prepare available years for dropdown
    final availableYears = equityData.map((e) => e['year'] as int).toSet().toList()..sort((a, b) => b.compareTo(a));
    
    // Initialize selection if needed or ensure validity
    if (_selectedComparisonYear == null || !availableYears.contains(_selectedComparisonYear)) {
       if (availableYears.contains(DateTime.now().year)) {
          _selectedComparisonYear = DateTime.now().year;
       } else if (availableYears.isNotEmpty) {
          _selectedComparisonYear = availableYears.first;
       }
    }
    
    final currentYear = DateTime.now().year;
    final displayYear = _selectedComparisonYear ?? currentYear;

    // Default start year if filter not set is min year in data, or use existing filter logic
    // The filter logic in buildDetailsSection sets _startYearFilter. 
    // We should probably rely on _startYearFilter if set, or calculate it here.
    // Ideally _startYearFilter is state shared.
    final startYear = _startYearFilter ?? 2000;
    
    // Aggregation Arrays (366 days)
    final List<double> dailySum = List.filled(366, 0.0);
    final List<int> dailyCount = List.filled(366, 0);
    
    // Helper to map MM-DD string to 0-365 index
    // Implemented as _dateToIndex

    bool hasComparisonYearData = false;
    
    // Optimize: Filter locally instead of refetching
    // We already have 'equityData' which contains ALL years.
    // The filter only applies to the 'average' calculation.
    
    for (var yearEntry in equityData) {
      final year = yearEntry['year'] as int;
      final changes = (yearEntry['data'] as List).cast<Map<String, dynamic>>();
      
      if (year == displayYear) {
         hasComparisonYearData = true;
      }
      
      // Average Calculation: Range startYear to currentYear - 1
      if (year >= startYear && year < currentYear) {
         for (var d in changes) {
             final idx = _dateToIndex(d['md']);
             if (idx >= 0 && idx < 366) {
                 dailySum[idx] += (d['pct'] as num).toDouble();
                 dailyCount[idx]++;
             }
         }
      }
    }

    // Build Average Line
    final List<FlSpot> averageSpots = [];
    double avgVal = 100.0;
    averageSpots.add(const FlSpot(0, 100));
    
    for (int i = 0; i < 366; i++) {
       double change = 0;
       if (dailyCount[i] > 0) {
           change = dailySum[i] / dailyCount[i];
       }
       avgVal = avgVal * (1 + change / 100.0);
       averageSpots.add(FlSpot(i.toDouble(), avgVal));
    }

    // Build Comparison Year Line
    final List<FlSpot> comparisonSpots = [];
    
    if (hasComparisonYearData) {
        double currVal = 100.0;
        comparisonSpots.add(const FlSpot(0, 100));
        
        // We need the specific changes for current year
        final currYearData = equityData.firstWhere((e) => e['year'] == displayYear);
        final changes = (currYearData['data'] as List).cast<Map<String, dynamic>>();
        final Map<int, double> changeMap = {};
        for(var c in changes) changeMap[_dateToIndex(c['md'])] = (c['pct'] as num).toDouble();
        
        // Actually we should stop at "today" ONLY if it is the current year
        int stopIdx = 365;
        if (displayYear == DateTime.now().year) {
            stopIdx = _dateToIndex('${DateTime.now().month}-${DateTime.now().day}');
        }
        
        for (int i = 0; i <= stopIdx; i++) {
            if (changeMap.containsKey(i)) {
                currVal = currVal * (1 + changeMap[i]! / 100.0);
            }
            // Even if no data (weekend), carry over previous value
            comparisonSpots.add(FlSpot(i.toDouble(), currVal));
        }
    }

    // Calculate Y Range
    double minY = 100, maxY = 100;
    for (var s in averageSpots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
    }
    for (var s in comparisonSpots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
    }
    final range = (maxY - minY).abs(); // Ensure positive
    final padding = range == 0 ? 5.0 : range * 0.1;
    minY -= padding;
    maxY += padding;

    final openIdx = _dateToIndex(widget.trade.openDate);
    final closeIdx = _dateToIndex(widget.trade.closeDate);

    // Range Highlight
    // We want to highlight the region between Open and Close.
    // If Close < Open (year wrap), we highlight Open -> 365 AND 0 -> Close.
    
    final highlightColor = AppColors.primary.withValues(alpha: 0.05);
    
    List<LineChartBarData> highlightBars = [];
    
    if (closeIdx > openIdx) {
       // Single range
       highlightBars.add(
         LineChartBarData(
           spots: [FlSpot(openIdx.toDouble(), maxY), FlSpot(closeIdx.toDouble(), maxY)],
           color: Colors.transparent,
           barWidth: 0,
           belowBarData: BarAreaData(show: true, color: highlightColor, cutOffY: minY, applyCutOffY: true),
           dotData: const FlDotData(show: false),
         )
       );
    } else {
       // Wrap around
       highlightBars.add(
         LineChartBarData(
           spots: [FlSpot(openIdx.toDouble(), maxY), FlSpot(365, maxY)],
           color: Colors.transparent,
           barWidth: 0,
           belowBarData: BarAreaData(show: true, color: highlightColor, cutOffY: minY, applyCutOffY: true),
           dotData: const FlDotData(show: false),
         )
       );
       highlightBars.add(
         LineChartBarData(
           spots: [FlSpot(0, maxY), FlSpot(closeIdx.toDouble(), maxY)],
           color: Colors.transparent,
           barWidth: 0,
           belowBarData: BarAreaData(show: true, color: highlightColor, cutOffY: minY, applyCutOffY: true),
           dotData: const FlDotData(show: false),
         )
       );
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('SEASONAL TREND', style: AppTextStyles.headlineLarge.copyWith(fontSize: 14, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('Avg vs $displayYear', style: AppTextStyles.headlineLarge),
                        ]
                    ),
                    // Legend
                    Row(
                        children: [
                            _buildLegendItem('Avg', AppColors.primary),
                            const SizedBox(width: 12),
                            Container(
                                height: 24,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                        value: displayYear,
                                        dropdownColor: const Color(0xFF2A2A2A),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                        isDense: true,
                                        items: availableYears.map((y) => DropdownMenuItem(
                                            value: y,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                 Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                                 const SizedBox(width: 6),
                                                 Text('$y'),
                                              ],
                                            )
                                        )).toList(),
                                        onChanged: (val) {
                                            if (val != null) setState(() => _selectedComparisonYear = val);
                                        }
                                    ),
                                ),
                            ),
                        ]
                    )
                ]
            ),
            const SizedBox(height: 24),
            SizedBox(
                height: 250,
                child: LineChart(
                    LineChartData(
                        minY: minY,
                        maxY: maxY,
                        minX: 0,
                        maxX: 365,
                        lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (spot) => Colors.black.withValues(alpha: 0.8),
                                getTooltipItems: (spots) {
                                    return spots.map((spot) {
                                        // Skip tooltips for highlight bars (transparent or zero width)
                                        if (spot.bar.color == Colors.transparent || spot.bar.barWidth == 0) {
                                            return null;
                                        }
                                        
                                        final isComparison = spot.bar.color == Colors.white;
                                        final isAvg = spot.bar.color == AppColors.primary;
                                        
                                        // Only show for Avg and Comparison lines
                                        if (!isComparison && !isAvg) return null;
                                        
                                        // Date from X
                                        final dt = DateTime(2024, 1, 1).add(Duration(days: spot.x.toInt()));
                                        final dateStr = '${_months[dt.month-1]} ${dt.day}';
                                        
                                        return LineTooltipItem(
                                            '${isComparison ? displayYear : "Avg"}\n$dateStr\n${spot.y.toStringAsFixed(1)}',
                                            TextStyle(
                                                color: isComparison ? Colors.white : AppColors.primary,
                                                fontWeight: FontWeight.bold
                                            )
                                        );
                                    }).toList();
                                }
                            )
                        ),
                        gridData: FlGridData(
                            show: true, 
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 30.5, // ~One month
                                    reservedSize: 30,
                                    getTitlesWidget: (val, meta) {
                                        final idx = val.toInt();
                                        if (idx > 365) return const SizedBox.shrink(); // Use 365
                                        // We want Jan at 0, Feb at ~31, etc.
                                        // Let's create a date from 2024-01-01 + idx days
                                        final dt = DateTime(2024, 1, 1).add(Duration(days: idx));
                                        
                                        return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(_months[dt.month-1], style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10))
                                        );
                                    }
                                )
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 35,
                                    getTitlesWidget: (val, meta) {
                                        return Text(val.toStringAsFixed(0), style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10));
                                    }
                                )
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        extraLinesData: ExtraLinesData(
                            verticalLines: [
                                VerticalLine(
                                    x: openIdx.toDouble(),
                                    color: AppColors.success.withValues(alpha: 0.5),
                                    strokeWidth: 1,
                                    dashArray: [4, 4],
                                    label: VerticalLineLabel(show: true, alignment: Alignment.topRight, labelResolver: (line) => 'OPEN', style: TextStyle(color: AppColors.success, fontSize: 9))
                                ),
                                VerticalLine(
                                    x: closeIdx.toDouble(),
                                    color: AppColors.error.withValues(alpha: 0.5),
                                    strokeWidth: 1,
                                    dashArray: [4, 4],
                                    label: VerticalLineLabel(show: true, alignment: Alignment.topRight, labelResolver: (line) => 'CLOSE', style: TextStyle(color: AppColors.error, fontSize: 9))
                                ),
                            ]
                        ),
                        lineBarsData: [
                            // Background Highlights
                            ...highlightBars,
                            // Average Line
                            LineChartBarData(
                                spots: averageSpots,
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                            AppColors.primary.withValues(alpha: 0.2),
                                            AppColors.primary.withValues(alpha: 0.0),
                                        ]
                                    )
                                ),
                            ),
                            // Comparison Year
                            if (comparisonSpots.isNotEmpty)
                                LineChartBarData(
                                    spots: comparisonSpots,
                                    isCurved: true,
                                    color: Colors.white,
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                    shadow: const Shadow(color: Colors.black, blurRadius: 4),
                                ),
                        ]
                    )
                )
            ),
        ]
    );
  }

  Widget _buildLegendItem(String label, Color color) {
      return Row(
          children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
          ]
      );
  }

  Widget _buildDetailsSection() {
    final service = SeasonalDataService();
    final tradeId = widget.trade.id ?? '';
    final userSettings = service.userSettings;
    final liveActive = userSettings?.isLiveActive(tradeId) ?? false;
    final paperActive = userSettings?.isPaperActive(tradeId) ?? false;
    
    String badgeLabel = 'NOT SUBSCRIBED';
    Color badgeColor = AppColors.textSecondary;
    
    if (liveActive) {
      badgeLabel = 'LIVE';
      badgeColor = AppColors.error;
    } else if (paperActive) {
      badgeLabel = 'PAPER';
      badgeColor = AppColors.accent;
    }

    final allStats = service.getStatistics(tradeId);
    
    // Filter out ongoing trades for aggregation
    final validStats = allStats.where((s) => !widget.trade.isOngoingForYear(s.year)).toList();
    
    // Determine min/max years from DATA
    int minYear = 0;
    int maxYear = 0;
    if (validStats.isNotEmpty) {
      minYear = validStats.fold(validStats.first.year, (prev, curr) => curr.year < prev ? curr.year : prev);
      maxYear = validStats.fold(validStats.first.year, (prev, curr) => curr.year > prev ? curr.year : prev);
    }
    
    // Calculate slider limits based on DATA
    final maxSelectableYear = maxYear - 3;
    final sliderEnabled = validStats.isNotEmpty && minYear <= maxSelectableYear;
    
    // Initialize or correct _startYearFilter
    if (_startYearFilter == null) {
      _startYearFilter = minYear;
    } else {
      if (sliderEnabled) {
        if (_startYearFilter! < minYear) _startYearFilter = minYear;
        if (_startYearFilter! > maxSelectableYear) _startYearFilter = maxSelectableYear;
      } else {
        _startYearFilter = minYear;
      }
    }
    
    final effectiveStartYear = _startYearFilter!;
    
    // Apply filter for aggregation
    final filteredStats = validStats.where((s) => s.year >= effectiveStartYear).toList();
    final aggregate = service.calculateAggregate(filteredStats);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.trade.symbol, style: AppTextStyles.displayMedium.copyWith(height: 1.0)),
                      const SizedBox(width: 8),
                      Icon(
                        widget.trade.verifiedByApi ? Icons.check_circle : Icons.warning_amber,
                        size: 20,
                        color: widget.trade.verifiedByApi ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (widget.trade.name != null)
                    Text(
                      widget.trade.name!, 
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.trade.direction == 'Long' ? AppColors.long.withValues(alpha: 0.15) : AppColors.short.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.trade.direction == 'Long' ? AppColors.long.withValues(alpha: 0.5) : AppColors.short.withValues(alpha: 0.5)),
                ),
                child: Text(
                  widget.trade.direction.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: widget.trade.direction == 'Long' ? AppColors.long : AppColors.short,
                    fontSize: 12,
                    letterSpacing: 1.0
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Dates Row
          Row(
            children: [
              Expanded(child: _buildDateBox('Open Date', widget.trade.openDate)),
              _buildDurationBadge(),
              Expanded(child: _buildDateBox('Close Date', widget.trade.closeDate, crossAlign: CrossAxisAlignment.end)),
            ],
          ),

          const SizedBox(height: 32),
          Divider(color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 24),

          // Primary Stats Row (Dominant)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _DoughnutChart(
                        value: aggregate.winRate,
                        color: AppColors.success,
                        size: 70,
                        thickness: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'WIN RATE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5
                          ),
                      ),
                    ],
                  )
                ),
                Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.05)),
                Expanded(
                  flex: 4,
                  child: _buildPrimaryStatItem(
                    'Avg Profit', 
                    '${aggregate.averageProfitPercentage > 0 ? '+' : ''}${aggregate.averageProfitPercentage.toStringAsFixed(2)}%', 
                    aggregate.averageProfitPercentage >= 0 ? AppColors.success : AppColors.error
                  )
                ),
                Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.05)),
                Expanded(
                  flex: 4,
                  child: _buildPrimaryStatItem(
                    'Annualized', 
                    '${aggregate.annualizedProfit > 0 ? '+' : ''}${aggregate.annualizedProfit.toStringAsFixed(2)}%', 
                    aggregate.annualizedProfit >= 0 ? AppColors.success : AppColors.error
                  )
                ),
            ],
          ),
          
          if (filteredStats.isNotEmpty) ...[
             const SizedBox(height: 32),
             SizedBox(
               height: 200,
               child: _SeasonalPerformanceChart(
                 stats: filteredStats,
                 averageProfit: aggregate.averageProfitPercentage,
                 medianProfit: aggregate.medianProfitPercentage,
               ),
             ),
          ],
          
          const SizedBox(height: 32),
          _buildSeasonalTrendChart(),
          const SizedBox(height: 32),
          
          // Secondary Stats Grid
          _buildSecondaryStatsGrid(aggregate),
          
          const SizedBox(height: 24),
          
          // Verification Badge and Slider
          if (sliderEnabled) ...[
             const SizedBox(height: 16),
             YearSelectionSlider(
               minYear: minYear,
               maxYear: maxYear,
               maxSelectableYear: maxSelectableYear,
               selectedYear: effectiveStartYear,
               onChanged: (val) {
                 setState(() {
                   _startYearFilter = val;
                 });
               },
             ),
             const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSecondaryStatsGrid(SeasonalTradeAggregateStatistic aggregate) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSecondaryStatItem('Profit Factor', aggregate.profitFactor.toStringAsFixed(2))),
            Expanded(child: _buildSecondaryStatItem('Std Dev', '${aggregate.standardDeviation?.toStringAsFixed(2) ?? '-'}%')),
            Expanded(child: _buildSecondaryStatItem('Years', '${aggregate.totalTrades}')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSecondaryStatItem('Best Year', '${aggregate.bestYear.profitPercentage.toStringAsFixed(1)}% (${aggregate.bestYear.year})', valueColor: AppColors.success)),
            Expanded(child: _buildSecondaryStatItem('Worst Year', '${aggregate.worstYear.profitPercentage.toStringAsFixed(1)}% (${aggregate.worstYear.year})', valueColor: AppColors.error)),
            Expanded(child: _buildSecondaryStatItem('Cum. Return', '${(aggregate.cumulativeReturn ?? 0).toStringAsFixed(0)}%')),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryStatItem(String label, String value, Color valueColor) {
      return Column(
          children: [
              Text(
                  value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                      letterSpacing: -0.5
                  ),
              ),
              const SizedBox(height: 4),
              Text(
                  label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5
                  ),
              ),
          ],
      );
  }

  Widget _buildSecondaryStatItem(String label, String value, {Color valueColor = AppColors.textPrimary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 0.5
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDateBox(String label, String dateStr, {CrossAxisAlignment crossAlign = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Text(
          label.toUpperCase(), 
          style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w600, 
              color: AppColors.textSecondary,
              letterSpacing: 1.0
          )
        ),
        const SizedBox(height: 8),
        Text(
          _formatDate(dateStr), 
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary
          ),
        ),
      ],
    );
  }

  Widget _buildDurationBadge() {
    int days = 0;
    try {
      final now = DateTime.now();
      final openParts = widget.trade.openDate.split('-');
      final closeParts = widget.trade.closeDate.split('-');
      
      if (openParts.length >= 2 && closeParts.length >= 2) {
         int getPart(List<String> parts, int index) => int.parse(parts[parts.length - index]);
         
         final openM = getPart(openParts, 2);
         final openD = getPart(openParts, 1);
         final closeM = getPart(closeParts, 2);
         final closeD = getPart(closeParts, 1);
         
         final start = DateTime(now.year, openM, openD);
         var end = DateTime(now.year, closeM, closeD);
         
         if (end.isBefore(start)) {
           end = DateTime(now.year + 1, closeM, closeD);
         }
         
         days = end.difference(start).inDays;
      }
    } catch (_) {}

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          children: [
            const Icon(Icons.arrow_forward, size: 12, color: AppColors.textSecondary),
            if (days > 0) ...[
              const SizedBox(height: 2),
              Text(
                '$days Days',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary.withValues(alpha: 0.8)
                ),
              ),
            ]
          ],
        )
    );
  }

  Widget _buildYearlyStatisticsSection() {
    final service = SeasonalDataService();
    final tradeId = widget.trade.id ?? '';
    final stats = service.getStatistics(tradeId);
    final error = service.getStatisticsError(tradeId);
    final isLoading = service.isStatisticsLoading(tradeId);
    
    if (isLoading || error != null || stats.isEmpty) {
        return const SizedBox.shrink(); 
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isYearlyStatsExpanded = !_isYearlyStatsExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Year by Year', style: AppTextStyles.headlineLarge),
                Icon(
                  _isYearlyStatsExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          if (_isYearlyStatsExpanded) ...[
            const SizedBox(height: 24),
            Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: stats.reversed.map((s) => _YearlyStatCard(statistic: s, trade: widget.trade)).toList(),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildConfigSection(SeasonalStrategyUserSettings? userSettings, var user) {
    if (userSettings == null || widget.trade.id == null) return const SizedBox.shrink();

    final tradeId = widget.trade.id!;
    final currentThread = userSettings.getThreadForTrade(tradeId);
    final liveActive = userSettings.isLiveActive(tradeId);
    final paperActive = userSettings.isPaperActive(tradeId);
    final isSubscribed = liveActive || paperActive;
    
    // Determine active mode
    final isLiveMode = liveActive;
    
    // Verification Status
    final paperVerified = user?.alpacaPaperAccount?.verified ?? false;
    final liveVerified = user?.alpacaLiveAccount?.verified ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Configuration',
                style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (!isSubscribed) ...[
             Text(
               'Subscribe to this trade to start tracking it in your seasonal calendar and execute it.',
               style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
             ),
             const SizedBox(height: 24),
             SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _subscribe,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Subscribe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
             ),
          ] else ...[
          // Execution Mode Toggle
          Text('Execution Mode', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    label: 'PAPER',
                    isActive: !isLiveMode, // If not live, assume paper (since subscribed)
                    isEnabled: paperVerified,
                    onTap: () => _setMode(false),
                    activeColor: AppColors.accent,
                  ),
                ),
                Expanded(
                  child: _buildModeButton(
                    label: 'LIVE',
                    isActive: isLiveMode,
                    isEnabled: liveVerified,
                    onTap: () => _setMode(true),
                    activeColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Thread Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Execution Thread', style: AppTextStyles.bodyMedium),
              if (!_showAllThreads && currentThread <= 5)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllThreads = true),
                  icon: const Icon(Icons.expand_more, size: 16),
                  label: const Text('More'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                )
              else if (_showAllThreads)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllThreads = false),
                  icon: const Icon(Icons.expand_less, size: 16),
                  label: const Text('Less'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                )
                  else if (!_showAllThreads && currentThread > 5)
                     TextButton.icon(
                      onPressed: () => setState(() => _showAllThreads = true),
                      icon: const Icon(Icons.expand_more, size: 16),
                      label: const Text('Show'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                )
            ],
          ),
          const SizedBox(height: 12),
          _buildThreadGrid(currentThread),
          
          const SizedBox(height: 32),
          Divider(color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          
          // Unsubscribe
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _unsubscribe,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Unsubscribe from Trade'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          ]
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isActive,
    required bool isEnabled,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: activeColor) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isEnabled 
                ? (isActive ? activeColor : AppColors.textSecondary)
                : AppColors.textDisabled,
              fontWeight: FontWeight.bold,
              decoration: isEnabled ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadGrid(int currentThread) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
             final threadNum = index + 1;
             return _buildThreadItem(threadNum, currentThread);
          }),
        ),
        if (_showAllThreads) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
               final threadNum = index + 6;
               return _buildThreadItem(threadNum, currentThread);
            }),
          ),
        ]
      ],
    );
  }

  Widget _buildThreadItem(int threadNum, int currentThread) {
     final isSelected = currentThread == threadNum;
     final color = AppTheme.threadColors[threadNum] ?? Colors.grey;

     return GestureDetector(
        onTap: () => _updateThread(threadNum),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: isSelected 
              ? Border.all(color: Colors.white, width: 2)
              : null,
            boxShadow: isSelected 
              ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 3))]
              : [],
          ),
          child: Center(
            child: Text(
              '$threadNum',
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
  }
}

class YearSelectionSlider extends StatelessWidget {
  final int minYear;
  final int maxYear;
  final int maxSelectableYear;
  final int selectedYear;
  final ValueChanged<int> onChanged;

  const YearSelectionSlider({
    super.key,
    required this.minYear,
    required this.maxYear,
    required this.maxSelectableYear,
    required this.selectedYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (maxSelectableYear < minYear) return const SizedBox.shrink();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                    Text(
              'AGGREGATE START YEAR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$selectedYear',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
                    ),
                ],
              ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white.withValues(alpha: 0.1),
            inactiveTrackColor: AppColors.primary,
            thumbColor: Colors.white,
            overlayColor: AppColors.primary.withValues(alpha: 0.2),
            valueIndicatorColor: AppColors.primary,
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: selectedYear.toDouble(),
            min: minYear.toDouble(),
            max: maxYear.toDouble(),
            divisions: (maxYear - minYear) > 0 ? (maxYear - minYear) : 1,
            label: selectedYear.toString(),
            onChanged: (double value) {
              final intVal = value.toInt();
              if (intVal <= maxSelectableYear) {
                 onChanged(intVal);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$minYear', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10)),
              Text('$maxYear', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoughnutChart extends StatelessWidget {
  final double value;
  final Color color;
  final double size;
  final double thickness;

  const _DoughnutChart({
    required this.value,
    required this.color,
    this.size = 60,
    this.thickness = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: 270,
              sectionsSpace: 0,
              centerSpaceRadius: (size / 2) - thickness,
              sections: [
                PieChartSectionData(
                  color: color,
                  value: value,
                  title: '',
                  radius: thickness,
                  showTitle: false,
                ),
                PieChartSectionData(
                  color: color.withValues(alpha: 0.1),
                  value: 100 - value,
                  title: '',
                  radius: thickness,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Center(
                child: Text(
              '${value.toStringAsFixed(0)}%',
                  style: TextStyle(
                fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                color: color,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

class _SeasonalPerformanceChart extends StatelessWidget {
  final List<SeasonalTradeSingleStatistic> stats;
  final double averageProfit;
  final double medianProfit;

  const _SeasonalPerformanceChart({
    required this.stats,
    required this.averageProfit,
    required this.medianProfit,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final sortedStats = List<SeasonalTradeSingleStatistic>.from(stats)..sort((a, b) => a.year.compareTo(b.year));

    double minY = 0;
    double maxY = 0;
    
    for (var s in sortedStats) {
      if (s.profitPercentage > maxY) maxY = s.profitPercentage;
      if (s.profitPercentage < minY) minY = s.profitPercentage;
      if (s.maxRunUpPercentage > maxY) maxY = s.maxRunUpPercentage;
      if (-s.maxDrawdownPercentage < minY) minY = -s.maxDrawdownPercentage;
    }
    
    if (averageProfit > maxY) maxY = averageProfit;
    if (averageProfit < minY) minY = averageProfit;
    if (medianProfit > maxY) maxY = medianProfit;
    if (medianProfit < minY) minY = medianProfit;

    final range = maxY - minY;
    minY -= range * 0.1;
    maxY += range * 0.1;
    if (range == 0) {
      minY = -10;
      maxY = 10;
    }
    
    // Logic for label visibility and non-interference
    // Higher value gets top alignment, Lower value gets bottom alignment
    final bool avgIsHigher = averageProfit >= medianProfit;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: minY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipMargin: 8,
            getTooltipColor: (group) => const Color(0xFF1E1E1E),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final year = sortedStats[group.x.toInt()].year;
              final s = sortedStats[group.x.toInt()];
              return BarTooltipItem(
                '$year\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            children: [
                  TextSpan(
                    text: 'Profit: ',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 12),
                  ),
                  TextSpan(
                    text: '${s.profitPercentage > 0 ? '+' : ''}${s.profitPercentage.toStringAsFixed(2)}%\n',
                    style: TextStyle(color: s.profitPercentage >= 0 ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextSpan(
                    text: 'Runup: ',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 12),
                  ),
                  TextSpan(
                    text: '+${s.maxRunUpPercentage.toStringAsFixed(2)}%\n',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextSpan(
                    text: 'Drawdown: ',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 12),
                  ),
                  TextSpan(
                    text: '-${s.maxDrawdownPercentage.toStringAsFixed(2)}%',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedStats.length) {
                  if (sortedStats.length > 10 && index % 2 != 0) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      sortedStats[index].year.toString(),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: averageProfit,
              color: AppColors.primary,
              strokeWidth: 2,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: avgIsHigher ? Alignment.topRight : Alignment.bottomRight,
                padding: const EdgeInsets.only(right: 5, top: 4, bottom: 4),
                labelResolver: (line) => 'Avg: ${averageProfit.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
            HorizontalLine(
              y: medianProfit,
              color: AppColors.accent,
              strokeWidth: 2,
              dashArray: [2, 2],
              label: HorizontalLineLabel(
                show: true,
                alignment: avgIsHigher ? Alignment.bottomRight : Alignment.topRight,
                padding: const EdgeInsets.only(right: 5, top: 4, bottom: 4),
                labelResolver: (line) => 'Med: ${medianProfit.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
            HorizontalLine(
              y: 0,
              color: Colors.white.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ],
        ),
        barGroups: sortedStats.asMap().entries.map((entry) {
          final index = entry.key;
          final s = entry.value;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                fromY: -s.maxDrawdownPercentage, 
                toY: s.maxRunUpPercentage,       
                width: 16,
                borderRadius: BorderRadius.circular(4),
                color: Colors.transparent, 
                rodStackItems: [
                  BarChartRodStackItem(
                    -s.maxDrawdownPercentage,
                    0,
                    AppColors.error.withValues(alpha: 0.3),
                  ),
                  BarChartRodStackItem(
                    0,
                    s.maxRunUpPercentage,
                    AppColors.success.withValues(alpha: 0.3),
                  ),
                  BarChartRodStackItem(
                    0,
                    s.profitPercentage,
                    s.profitPercentage >= 0 ? AppColors.success : AppColors.error,
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _YearlyStatCard extends StatefulWidget {
  final SeasonalTradeSingleStatistic statistic;
  final SeasonalTrade trade;

  const _YearlyStatCard({required this.statistic, required this.trade});

  @override
  State<_YearlyStatCard> createState() => _YearlyStatCardState();
}

class _YearlyStatCardState extends State<_YearlyStatCard> {
  bool _isExpanded = false;
  
  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 2) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        if (month >= 1 && month <= 12) {
          return '${_months[month - 1]} $day';
        }
      } else if (parts.length == 3) {
        // YYYY-MM-DD
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        if (month >= 1 && month <= 12) {
          return '${_months[month - 1]} $day';
        }
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
     final s = widget.statistic;
     final isOngoing = widget.trade.isOngoingForYear(s.year);
     
     final hasDailyCloses = s.dailyCloses != null && s.dailyCloses!.isNotEmpty;

     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: Colors.black.withValues(alpha: 0.2),
         borderRadius: BorderRadius.circular(12),
         border: isOngoing 
             ? Border.all(color: AppColors.primary.withValues(alpha: 0.5)) 
             : Border.all(color: Colors.white.withValues(alpha: 0.05)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
           // Row 1: Year and Dates
          Row(
            children: [
               Text(
                 s.year.toString(), 
                 style: AppTextStyles.headlineLarge.copyWith(fontSize: 18)
               ),
               const Spacer(),
               Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                 _formatDate(s.entryDate), 
                 style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)
               ),
               const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 4), 
                 child: Icon(Icons.arrow_forward, size: 12, color: AppColors.textSecondary)
               ),
               if (isOngoing)
                 Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                        'ONGOING',
                        style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: AppColors.primary,
                            letterSpacing: 0.5
                        ),
                    ),
                 )
               else
                 Text(
                   _formatDate(s.exitDate),
                   style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)
                 ),
               if (hasDailyCloses) ...[
                   const SizedBox(width: 8),
                   IconButton(
                       icon: Icon(_isExpanded ? Icons.show_chart : Icons.show_chart_outlined, 
                           size: 20, 
                           color: _isExpanded ? AppColors.primary : AppColors.textSecondary
                       ),
                       padding: EdgeInsets.zero,
                       constraints: const BoxConstraints(),
                       onPressed: () => setState(() => _isExpanded = !_isExpanded),
                   )
               ]
             ]
           ),
           const SizedBox(height: 12),
           Divider(color: Colors.white.withValues(alpha: 0.05)),
           const SizedBox(height: 12),
           // Row 2: Stats
           Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Expanded(child: _buildStatItem(isOngoing ? 'Current Profit' : 'Profit', '${s.profitPercentage > 0 ? '+' : ''}${s.profitPercentage.toStringAsFixed(2)}%', 
                    s.profitPercentage >= 0 ? AppColors.success : AppColors.error)),
                 Expanded(child: _buildStatItem('Drawdown', '${s.maxDrawdownPercentage.toStringAsFixed(2)}%', AppColors.error)),
                 Expanded(child: _buildStatItem('Runup', '${s.maxRunUpPercentage.toStringAsFixed(2)}%', AppColors.success)),
              ]
           ),
           if (_isExpanded && hasDailyCloses) ...[
               const SizedBox(height: 24),
               SizedBox(
                   height: 200,
                   child: _buildChart(s.dailyCloses!),
               )
           ]
         ]
       )
     );
  }
  
  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(), 
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.5),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: valueColor),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
  
  Widget _buildChart(List<DailyClose> dailyCloses) {
      if (dailyCloses.isEmpty) return const SizedBox.shrink();

      final spots = dailyCloses.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value.price);
      }).toList();
      
      final firstPrice = dailyCloses.first.price;
      final lastPrice = dailyCloses.last.price;
      final isProfit = lastPrice >= firstPrice;
      final lineColor = isProfit ? AppColors.success : AppColors.error;
      
      // Calculate min/max Y for cleaner view
      double minY = dailyCloses.first.price;
      double maxY = dailyCloses.first.price;
      for (var c in dailyCloses) {
          if (c.price < minY) minY = c.price;
          if (c.price > maxY) maxY = c.price;
      }
      final range = maxY - minY;
      final padding = range * 0.1;
      
      return LineChart(
          LineChartData(
              gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                      return FlLine(
                          color: Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1,
                      );
                  },
              ),
              titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: (dailyCloses.length / 3).floorToDouble(), // Show ~3 dates
                          getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < dailyCloses.length) {
                                  return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                          _formatDate(dailyCloses[index].date),
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 10,
                                          ),
                                      ),
                                  );
                              }
                              return const SizedBox.shrink();
                          },
                      ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (dailyCloses.length - 1).toDouble(),
              minY: minY - padding,
              maxY: maxY + padding,
              lineBarsData: [
                  LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                          show: true,
                          color: lineColor.withValues(alpha: 0.1),
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                  lineColor.withValues(alpha: 0.2),
                                  lineColor.withValues(alpha: 0.0),
                              ],
                          ),
                      ),
                  ),
              ],
          ),
      );
  }
}

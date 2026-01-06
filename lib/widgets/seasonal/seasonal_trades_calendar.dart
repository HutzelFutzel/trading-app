import 'package:flutter/material.dart';
import '../../models/seasonal_trade.dart';
import '../../models/seasonal_strategy_user_settings.dart';
import '../../theme/app_theme.dart';
import '../../screens/seasonal_trade_view.dart';
import '../../services/seasonal_data_service.dart';
import 'dart:math' as math;

class SeasonalTradesCalendar extends StatefulWidget {
  final List<SeasonalTrade> trades;
  final SeasonalStrategyUserSettings? userSettings;

  const SeasonalTradesCalendar({
    super.key,
    required this.trades,
    this.userSettings,
  });

  @override
  State<SeasonalTradesCalendar> createState() => _SeasonalTradesCalendarState();
}

class _SeasonalTradesCalendarState extends State<SeasonalTradesCalendar> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _zoomController;
  Animation<double>? _zoomAnimation;
  
  // Date Range (±2.5 Years from now)
  late DateTime _startDate;
  late DateTime _endDate;
  final int _totalDays = (365 * 5) + 2; 

  // Data for Painting
  List<int> _activeThreads = [];
  Map<int, List<_CalendarTradeSegment>> _threadSegments = {};
  
  // Constants
  static const double _rowHeight = 44.0; 
  static const double _headerHeight = 40.0;
  static const double _sidebarWidth = 40.0;

  // Zoom State
  double _dayWidth = 10.0;
  double _baseDayWidth = 10.0;

  // Interaction State
  DateTime? _interactionDate;
  List<SeasonalTrade> _activeTradesAtDate = []; // For scrubbing
  SeasonalTrade? _clickedTrade; // For clicking
  String? _loadingTradeId; // For loading feedback
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _zoomController.addListener(() {
      if (_zoomAnimation != null) {
        setState(() {
          _dayWidth = _zoomAnimation!.value;
        });
        _scrollToToday();
      }
    });
    
    _initDateRange();
    _processTrades();
    
    // Defer initial scroll to after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize width based on screen size
      final screenWidth = MediaQuery.of(context).size.width - _sidebarWidth; 
      setState(() {
         _dayWidth = screenWidth / 365.0; // 1 year visible (Default)
      });
      if (mounted) _scrollToToday();
    });
  }

  void _initDateRange() {
    final now = DateTime.now();
    // Normalize to start of day
    final today = DateTime(now.year, now.month, now.day);
    // 2.5 * 365 = 912.5 days. Round to 913.
    _startDate = today.subtract(const Duration(days: 913));
    _endDate = today.add(const Duration(days: 913));
  }
  
  void _scrollToToday() {
    if (!_scrollController.hasClients) return;
    
    // Position today on the left side with a small gap (e.g. 50px context)
    // instead of centering it.
    final offset = (913.0 * _dayWidth) - 50.0;
    
    _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
  }

  void _processTrades() {
    final Map<int, List<_CalendarTradeSegment>> segments = {};
    final Set<int> activeThreads = {};

    // Helper to parse MM-DD
    (int, int)? parseDate(String dateStr) {
      try {
        final parts = dateStr.split('-');
        return (int.parse(parts[0]), int.parse(parts[1]));
      } catch (_) {
        return null;
      }
    }

    final startYear = _startDate.year;
    final endYear = _endDate.year;

    for (final trade in widget.trades) {
      if (!trade.verifiedByApi) continue;

      final openParts = parseDate(trade.openDate);
      final closeParts = parseDate(trade.closeDate);
      
      if (openParts == null || closeParts == null) continue;

      final (openMonth, openDay) = openParts;
      final (closeMonth, closeDay) = closeParts;
      
      final threadId = widget.userSettings?.getThreadForTrade(trade.id ?? '') ?? 1;
      
      for (int year = startYear - 1; year <= endYear + 1; year++) {
        final tradeOpen = DateTime(year, openMonth, openDay);
        DateTime tradeClose = DateTime(year, closeMonth, closeDay);
        
        if (tradeClose.isBefore(tradeOpen)) {
          tradeClose = DateTime(year + 1, closeMonth, closeDay);
        }

        if (tradeOpen.isBefore(_endDate) && tradeClose.isAfter(_startDate)) {
            final segment = _CalendarTradeSegment(
              originalTrade: trade,
              start: tradeOpen,
              end: tradeClose,
              thread: threadId,
            );

            if (!segments.containsKey(threadId)) {
              segments[threadId] = [];
            }
            segments[threadId]!.add(segment);
            activeThreads.add(threadId);
        }
      }
    }

    // Determine Stacking for Overlaps
    for (final threadId in segments.keys) {
        final list = segments[threadId]!;
        // Sort by start date first
        list.sort((a, b) => a.start.compareTo(b.start));

        // Assign stack indices
        for (int i = 0; i < list.length; i++) {
            var current = list[i];
            int overlaps = 0;
            // Check previous segments for overlap
            for (int j = 0; j < i; j++) {
                var prev = list[j];
                // Simple overlap check: StartA < EndB && EndA > StartB
                if (current.start.isBefore(prev.end) && current.end.isAfter(prev.start)) {
                    overlaps++;
                }
            }
            // Cap visual stack depth to prevent scrolling issues or visual mess
            current.stackIndex = math.min(overlaps, 3);
        }
    }

    setState(() {
      _threadSegments = segments;
      _activeThreads = activeThreads.toList()..sort();
    });
  }
  
  Color _getThreadColor(int thread) {
    if (AppTheme.threadColors.containsKey(thread)) return AppTheme.threadColors[thread]!;
    return Colors.primaries[thread % Colors.primaries.length];
  }

  void _updateInteraction(Offset localPos) {
    final x = localPos.dx;
    final days = (x / _dayWidth).floor();
    
    if (days >= 0 && days < _totalDays) {
      final newDate = _startDate.add(Duration(days: days));
      if (_interactionDate != newDate) {
        // Find all active trades at this date
        // Iterate through all threadSegments
        final List<SeasonalTrade> activeTrades = [];
        // Flatten segments
        for (final list in _threadSegments.values) {
            for (final segment in list) {
                // Normalize dates
                final sStart = DateTime(segment.start.year, segment.start.month, segment.start.day);
                final sEnd = DateTime(segment.end.year, segment.end.month, segment.end.day);
                final sSel = DateTime(newDate.year, newDate.month, newDate.day);
                
                if (sSel.isAfter(sStart.subtract(const Duration(days: 1))) && sSel.isBefore(sEnd.add(const Duration(days: 1)))) {
                    activeTrades.add(segment.originalTrade);
                }
            }
        }
        
        setState(() {
            _interactionDate = newDate;
            _activeTradesAtDate = activeTrades;
            _clickedTrade = null; // Clear clicked trade when dragging starts
        });
      }
    }
  }

  void _clearInteraction() {
    // We don't clear _interactionDate anymore on pointer up because we want to persist the info panel
    // But standard behavior might be to clear it?
    // User requirement: "dragging the date - show this information". 
    // Usually scrubbing ends on release.
    // "Clicking on a trade shows more info".
    // Let's persist if clicked, but maybe clear if just dragging ends?
    // Let's KEEP the interaction active to read the tooltip.
    // If user taps elsewhere, maybe we clear.
    // For now, let's allow it to persist to be readable.
    // But we need a way to dismiss. Tapping background?
  }
  
  void _onChartTap(TapUpDetails details) {
      // Logic to find which trade was clicked
      // We need to map local (x, y) to a trade.
      // x is mapped to date via scroll offset.
      // y is mapped to thread row.
      
      // Calculate effective X including scroll
      // The tap happens on the Body (Expanded).
      final localPos = details.localPosition;
      
      // But we need the tap relative to the scroll view content content.
      // We will attach the detector inside the scroll view.
      
      // Assuming `_handleTap` is called with local position relative to the content width.
      final x = localPos.dx;
      final y = localPos.dy;
      
      // Adjust y to match painter coordinates (relative to top of header)
      final painterY = y + _headerHeight;
      
      // 1. Find Date
      final dayIndex = (x / _dayWidth).floor();
      if (dayIndex < 0 || dayIndex >= _totalDays) {
          setState(() { _clickedTrade = null; _activeTradesAtDate = []; });
          return;
      }
      // final date = _startDate.add(Duration(days: dayIndex)); // Not strictly needed if we use rects
      
      // 2. Find Thread Row
      // headerHeight + (i * rowHeight) <= painterY < headerHeight + ((i+1) * rowHeight)
      final rowIndex = ((painterY - _headerHeight) / _rowHeight).floor();
      
      if (rowIndex >= 0 && rowIndex < _activeThreads.length) {
          final threadId = _activeThreads[rowIndex];
          final segments = _threadSegments[threadId] ?? [];
          
          // Check segments in this row
          // We need to reconstruct the rects or check bounds
          // yBase = headerHeight + (rowIndex * rowHeight) + ((rowHeight - 34)/2)
          // verticalShift = stackIndex * 5.0
          // barHeight = 24.0
          
          // Since items overlap, check in reverse order (top of stack first)
          // Segments are sorted by start date.
          // We need to know stackIndex. It's stored in segment.
          
          // Reverse iteration for hit testing top-most first
          for (final segment in segments.reversed) {
               final daysFromStart = segment.start.difference(_startDate).inDays;
               final durationDays = segment.end.difference(segment.start).inDays + 1;
               
               final xStart = daysFromStart * _dayWidth;
               final width = math.max(_dayWidth, durationDays * _dayWidth);
               
               final touchSlop = 8.0;
               
               if (x >= xStart - touchSlop && x <= xStart + width + touchSlop) {
                   // Horizontal hit. Now check vertical.
                   final maxStackHeight = 34.0;
                   final yCenterOffset = (_rowHeight - maxStackHeight) / 2;
                   final yBase = _headerHeight + (rowIndex * _rowHeight) + yCenterOffset;
                   final verticalShift = segment.stackIndex * 5.0;
                   
                   final rectTop = yBase + verticalShift;
                   final rectBottom = rectTop + 24.0;
                   
                   if (painterY >= rectTop - touchSlop && painterY <= rectBottom + touchSlop) {
                       // Hit!
                       setState(() {
                           _clickedTrade = segment.originalTrade;
                           _activeTradesAtDate = []; // Clear drag selection
                           _interactionDate = null;  // Clear drag line
                       });
                       return;
                   }
               }
          }
      }
      
      // Missed everything
      setState(() { _clickedTrade = null; _activeTradesAtDate = []; _interactionDate = null; });
  }

  void _animateZoom(int daysVisible) {
    final screenWidth = MediaQuery.of(context).size.width - _sidebarWidth;
    final targetWidth = screenWidth / daysVisible;
    
    _zoomAnimation = Tween<double>(
      begin: _dayWidth,
      end: targetWidth,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));
    
    _zoomController.forward(from: 0.0);
  }

  bool _isZoomLevel(int daysVisible) {
    final screenWidth = MediaQuery.of(context).size.width - _sidebarWidth;
    final targetWidth = screenWidth / daysVisible;
    return (_dayWidth - targetWidth).abs() < 0.1;
  }

  Widget _buildInfoPanel() {
    // Collect trades to show
    final trades = _clickedTrade != null ? [_clickedTrade!] : _activeTradesAtDate;
    
    if (trades.isEmpty) return const SizedBox.shrink();

    final service = SeasonalDataService();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _clickedTrade != null 
                          ? 'SELECTED TRADE' 
                          : 'ACTIVE TRADES • ${_interactionDate != null ? _formatDateShort(_interactionDate!) : ""}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (_clickedTrade != null)
                  GestureDetector(
                    onTap: () => setState(() => _clickedTrade = null),
                    child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trades.length,
            separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 12),
            itemBuilder: (context, index) {
              return _buildModernTradeRow(trades[index], service);
            },
          ),
        ],
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildModernTradeRow(SeasonalTrade trade, SeasonalDataService service) {
    final stats = service.getStatistics(trade.id ?? '');
    final agg = service.calculateAggregate(stats);
    final isLong = trade.direction == 'Long';
    final color = isLong ? AppColors.long : AppColors.short;
    final isOpening = _loadingTradeId == trade.id;
    final isStatsLoading = service.isStatisticsLoading(trade.id ?? '');
    
    return InkWell(
      onTap: isOpening ? null : () => _openTradeSettings(trade),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Thread Color Indicator
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 10),
            
            // 2. Main Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Symbol + Direction Badge
                  Row(
                    children: [
                      Text(
                        trade.symbol,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trade.direction.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Dates on top right
                      Text(
                        '${_formatTradeDateString(trade.openDate)} - ${_formatTradeDateString(trade.closeDate)}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 2: Stats
                  if (isStatsLoading)
                    Row(
                      children: [
                         SizedBox(
                          width: 10, 
                          height: 10, 
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary.withValues(alpha: 0.5)),
                          )
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Loading stats...',
                          style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                        ),
                      ],
                    )
                  else if (stats.isNotEmpty)
                    Row(
                      children: [
                        _buildStatBadge(
                          'WIN', 
                          '${agg.winRate.toStringAsFixed(0)}%', 
                          AppColors.success
                        ),
                        const SizedBox(width: 8),
                        _buildStatBadge(
                          'AVG', 
                          '${agg.averageProfitPercentage > 0 ? '+' : ''}${agg.averageProfitPercentage.toStringAsFixed(1)}%', 
                          agg.averageProfitPercentage >= 0 ? AppColors.success : AppColors.error
                        ),
                        const SizedBox(width: 8),
                         Text(
                          '${agg.totalTrades} YRS',
                          style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  else
                    Text(
                      'No stats available',
                      style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                    ),
                ],
              ),
            ),
            
            // 3. Arrow
            const SizedBox(width: 8),
            if (isOpening) 
               const SizedBox(
                  width: 14, 
                  height: 14, 
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary))
                )
            else
               Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _openTradeSettings(SeasonalTrade trade) async {
    if (trade.id == null) return;
    
    setState(() {
      _loadingTradeId = trade.id;
    });

    // Prefetch data to ensure smooth transition
    try {
      await Future.wait([
        SeasonalDataService().fetchStatistics(trade.id!),
        SeasonalDataService().fetchSeasonalEquity(trade.id!),
      ]);
    } catch (_) {
      // Proceed even if fetch fails, the view will handle errors
    }

    if (!mounted) return;

    setState(() {
      _loadingTradeId = null;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonalTradeView(trade: trade),
      ),
    ).then((_) {
       if (mounted) setState(() {}); 
    });
  }

  String _formatTradeDateString(String dateStr) {
    try {
      final parts = dateStr.split('-');
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[month - 1]} $day';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void didUpdateWidget(covariant SeasonalTradesCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trades != widget.trades || oldWidget.userSettings != widget.userSettings) {
      _processTrades();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trades.isEmpty || _activeThreads.isEmpty) {
        return const SizedBox.shrink();
    }

    final totalWidth = _dayWidth * _totalDays;
    final contentHeight = (_activeThreads.length * _rowHeight) + _headerHeight;
    // contentHeight is just the chart area. We will add more height for buttons in the Column.

    return Container(
      // Allow height to adapt (Column will take what it needs, parent scroll view will handle it)
      // or specify total height if needed. The previous code had height: contentHeight + 20.
      // We'll remove the fixed height on Container and let Column determine size, but since this
      // widget is likely inside a scroll view (Dashboard), we should probably be careful.
      // However, usually `contentHeight` was defining the `CustomPaint` area.
      // Let's keep the Container wrapping but remove fixed height so it grows with the Column.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            height: contentHeight, 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Left Sidebar
          SizedBox(
            width: _sidebarWidth,
            child: Column(
              children: [
                // Top Left Corner - Match header background or transparent
                Container(
                  height: _headerHeight, 
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                    ),
                  ),
                ),
                ..._activeThreads.map((t) => Container(
                  height: _rowHeight,
                  alignment: Alignment.center,
                  child: Container(
                    width: 24, height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _getThreadColor(t).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _getThreadColor(t), width: 1.5),
                    ),
                    child: Text(
                      t.toString(),
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: _getThreadColor(t),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
          
          // Scrollable Content
          Expanded(
            child: GestureDetector(
              onScaleStart: (details) {
                _baseDayWidth = _dayWidth;
                _clearInteraction();
              },
              onScaleUpdate: (details) {
                if (details.pointerCount > 1) {
                    final screenWidth = MediaQuery.of(context).size.width - _sidebarWidth;
                    final minWidth = screenWidth / 365.0; 
                    final maxWidth = screenWidth / 7.0; 
                    
                    setState(() {
                      _dayWidth = (_baseDayWidth * details.scale).clamp(minWidth, maxWidth);
                    });
                }
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: totalWidth,
                    height: contentHeight,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: Size(totalWidth, contentHeight),
                      painter: _CalendarPainter(
                        startDate: _startDate,
                              totalDays: _totalDays,
                        dayWidth: _dayWidth,
                        rowHeight: _rowHeight,
                        headerHeight: _headerHeight,
                        activeThreads: _activeThreads,
                        threadSegments: _threadSegments,
                        selectedDate: _interactionDate,
                        theme: Theme.of(context),
                              scrollController: _scrollController,
                              viewportWidth: MediaQuery.of(context).size.width - _sidebarWidth,
                              userSettings: widget.userSettings,
                              clickedTrade: _clickedTrade,
                    ),
                  ),
                            Column(
                              children: [
                                // Header: Scrubbing Area
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onHorizontalDragStart: (details) => _updateInteraction(details.localPosition),
                                  onHorizontalDragUpdate: (details) => _updateInteraction(details.localPosition),
                                  // onTapDown: (details) => _updateInteraction(details.localPosition), // Don't snap on simple tap? Or yes?
                                  // User says "dragging the date". Tapping header to jump is usually expected.
                                  onTapDown: (details) => _updateInteraction(details.localPosition),
                                  child: Container(
                                    height: _headerHeight,
                                    color: Colors.transparent,
                                  ),
                                ),
                                // Body: Click Handling
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTapUp: _onChartTap,
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Zoom Controls (Below the chart)
          // Also Info Panel
          if (_clickedTrade != null || _activeTradesAtDate.isNotEmpty)
             _buildInfoPanel(),
             
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   _ZoomButton(
                     label: '3M', 
                     isSelected: _isZoomLevel(90),
                     onTap: () => _animateZoom(90),
                   ),
                   _ZoomButton(
                     label: '6M', 
                     isSelected: _isZoomLevel(180),
                     onTap: () => _animateZoom(180),
                   ),
                   _ZoomButton(
                     label: '1Y', 
                     isSelected: _isZoomLevel(365),
                     onTap: () => _animateZoom(365),
                   ),
                ],
              ),
            ),
          ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTradeSegment {
  final SeasonalTrade originalTrade;
  final DateTime start;
  final DateTime end;
  final int thread;
  int stackIndex = 0;

  _CalendarTradeSegment({
    required this.originalTrade, 
    required this.start, 
    required this.end,
    required this.thread,
  });
}

class _LabelToDraw {
  final String text;
  final double x;
  final double width;
  final double height;
  final Color? color;
  
  _LabelToDraw({
    required this.text, 
    required this.x, 
    required this.width, 
    required this.height,
    this.color,
  });
}

class _CalendarPainter extends CustomPainter {
  final DateTime startDate;
  final int totalDays;
  final double dayWidth;
  final double rowHeight;
  final double headerHeight;
  final List<int> activeThreads;
  final Map<int, List<_CalendarTradeSegment>> threadSegments;
  final DateTime? selectedDate;
  final ThemeData theme;
  final ScrollController scrollController;
  final double viewportWidth;
  final SeasonalStrategyUserSettings? userSettings;
  final SeasonalTrade? clickedTrade;

  _CalendarPainter({
    required this.startDate,
    required this.totalDays,
    required this.dayWidth,
    required this.rowHeight,
    required this.headerHeight,
    required this.activeThreads,
    required this.threadSegments,
    this.selectedDate,
    required this.theme,
    required this.scrollController,
    required this.viewportWidth,
    this.userSettings,
    this.clickedTrade,
  }) : super(repaint: scrollController);

  @override
  bool shouldRepaint(covariant _CalendarPainter oldDelegate) {
    return oldDelegate.scrollController != scrollController ||
           oldDelegate.dayWidth != dayWidth ||
           oldDelegate.startDate != startDate ||
           oldDelegate.clickedTrade?.id != clickedTrade?.id ||
           oldDelegate.selectedDate != selectedDate ||
           oldDelegate.userSettings != userSettings;
  }

  Color _getThreadColor(int thread) {
    if (AppTheme.threadColors.containsKey(thread)) return AppTheme.threadColors[thread]!;
    return Colors.primaries[thread % Colors.primaries.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Backgrounds & Header
    final headerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.surface,
          AppColors.surface.withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, headerHeight));
      
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, headerHeight), headerPaint);

    // Header Border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, headerHeight), Offset(size.width, headerHeight), borderPaint);

    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
      
    final monthLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
      
    final yearLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 2. Grid & Month Labels
    // Optimization: Calculate visible range
    final double scrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
    final int startDayIndex = (scrollOffset / dayWidth).floor().clamp(0, totalDays);
    final int visibleDays = (viewportWidth / dayWidth).ceil() + 2; // +2 for buffer
    final int endDayIndex = (startDayIndex + visibleDays).clamp(0, totalDays);

    DateTime iterator = startDate.add(Duration(days: startDayIndex));
    int dayIndex = startDayIndex;
    
    // Draw horizontal rows (only need to draw once, could be optimized but fast enough)
    for (int i = 0; i < activeThreads.length; i++) {
        final y = headerHeight + ((i + 1) * rowHeight);
        canvas.drawLine(
          Offset(scrollOffset, y), // Start at current scroll for infinite feel or 0? 
          // Actually line should span the full scrollable width if we want it to persist, 
          // or just the visible area to save raster.
          // Let's draw it across the visible area + buffer
          Offset(scrollOffset + viewportWidth, y), 
          dividerPaint
        );
    }

    // Pre-calculate zoom dependent values
    final double pixelsPerMonth = dayWidth * 30;
    final bool showFullMonth = pixelsPerMonth > 100;
    final bool showShortMonth = pixelsPerMonth > 40;
    
    // Track sticky year
    int? stickyYear;
    double? stickyYearX;
    
    // Iterate visible days
    while (dayIndex < endDayIndex) {
        if (dayIndex * dayWidth > size.width) break;

            final x = dayIndex * dayWidth;
            
        // Sticky Year Logic:
        if (dayIndex == startDayIndex) {
           stickyYear = iterator.year;
           
           final yearStart = DateTime(stickyYear, 1, 1);
           final yearStartDays = yearStart.difference(startDate).inDays;
           final yearStartX = yearStartDays * dayWidth;
           
           stickyYearX = math.max(yearStartX, scrollOffset + 6);
        }

        if (iterator.day == 1) {
            final isYearStart = iterator.month == 1;
            
            // Draw Vertical Grid Line
            canvas.drawLine(
               Offset(x, 0),
               Offset(x, size.height),
               isYearStart ? yearLinePaint : monthLinePaint
            );
            
            // Draw Ticks on Header
            canvas.drawLine(
              Offset(x, headerHeight - 6),
              Offset(x, headerHeight),
              Paint()..color = Colors.white.withValues(alpha: isYearStart ? 0.5 : 0.3)..strokeWidth = 1.5
            );
            
            // Labels
            String? topLabel;
            String? bottomLabel;
            
            if (isYearStart) {
                // We draw the year label normally if it's in view. 
                // The sticky logic handles the "left side" case.
                // If this x is > scrollOffset + padding + some_threshold, draw it.
                // Otherwise sticky logic covers it.
                // Actually, sticky logic draws the "current" year. 
                // If we encounter a NEW year start here, we should update stickyYear or let this draw?
                // Standard sticky header behavior: The header pushes up. 
                // Here we slide left.
                // If x > stickyYearX + width, we draw.
                // For simplicity, let's just draw the year here always, and sticky draws on top/underneath if needed?
                // Better: Update stickyYear to NEXT year if we pass Jan 1?
                // No, stickyYear is for the year covering the *left edge*.
                // So we just draw this label naturally.
                topLabel = iterator.year.toString();
                bottomLabel = showShortMonth ? (showFullMonth ? 'January' : 'Jan') : '01';
            } else {
               if (showFullMonth) {
                 topLabel = _getMonthNameFull(iterator.month);
               } else if (showShortMonth) {
                 topLabel = _getMonthName(iterator.month);
               } else {
                 topLabel = iterator.month.toString().padLeft(2, '0');
               }
            }
            
            if (topLabel != null) {
                final isYear = isYearStart;
            
            textPainter.text = TextSpan(
                  text: topLabel,
              style: AppTextStyles.bodySmall.copyWith(
                    color: isYear ? Colors.white : AppColors.textSecondary, 
                    fontSize: isYear ? 11 : 10,
                    fontWeight: isYear ? FontWeight.bold : FontWeight.w500,
              ),
            );
            textPainter.layout();
                
                // If year, check collision with sticky
                bool skipDraw = false;
                if (isYear && stickyYear == iterator.year) {
                    // If the natural position is close to sticky position, don't draw natural?
                    // Or let sticky take over.
                    // Sticky is drawn at max(yearStart, scrollOffset).
                    // If x > scrollOffset + 6, sticky == x. So it's the same.
                    // If x < scrollOffset, we wouldn't be in this loop (unless startDayIndex is handled).
                    // So we can skip drawing year here if it's the sticky year, and let sticky draw it at end of loop?
                    // Yes, consistent.
                    skipDraw = true;
                }
                
                if (!skipDraw) {
            textPainter.paint(canvas, Offset(x + 6, 8));
                }

                if (bottomLabel != null) {
            textPainter.text = TextSpan(
                      text: bottomLabel,
              style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.5), 
                fontSize: 9,
                        fontWeight: FontWeight.w500,
              ),
            );
            textPainter.layout();
                    textPainter.paint(canvas, Offset(x + 6, 22));
                }
            }
        }
        
        iterator = iterator.add(const Duration(days: 1));
        dayIndex++;
    }

    // Draw Sticky Year Label
    if (stickyYear != null && stickyYearX != null) {
        textPainter.text = TextSpan(
          text: stickyYear.toString(),
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white, 
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        
        // Ensure we don't draw past the NEXT year start
        // Find next year start
        final nextYear = DateTime(stickyYear + 1, 1, 1);
        final nextYearDays = nextYear.difference(startDate).inDays;
        final nextYearX = nextYearDays * dayWidth;
        
        // Clamp X to be visible but stop before next year label hits
        // Just a simple visual check: if stickyX + width > nextYearX, clip or hide?
        // Sticky headers usually push out.
        // Let's stop sticky if nextYearX is close.
        if (stickyYearX < nextYearX - 40) { // 40px buffer
             // Add background to clear grid lines under sticky label
             final bgRect = Rect.fromLTWH(stickyYearX - 2, 4, textPainter.width + 16, headerHeight - 8);
             // Gradient or solid?
             canvas.drawRect(bgRect, Paint()..color = AppColors.surface.withValues(alpha: 0.8)); // Fade out bg
             
             textPainter.paint(canvas, Offset(stickyYearX + 6, 8));
             
             // Also draw Jan/01 below it if needed?
             // User just said "year number".
        }
    }

    // 3. Draw Trades (Stacked)
    final tradeBorderPaint = Paint()
       ..color = AppColors.background 
       ..style = PaintingStyle.stroke
       ..strokeWidth = 2.0; // Increased border width for better cutout effect

    for (int i = 0; i < activeThreads.length; i++) {
        final threadId = activeThreads[i];
        final segments = threadSegments[threadId] ?? [];
        
        // Calculate the full height available for this row content (minus padding)
        // final yTop = headerHeight + (i * rowHeight) + 4; // Unused
        
        // Use a fixed bar height to ensure consistency across stacks
        const double barHeight = 24.0;
        
        // Max stack index is clamped to 3 in _processTrades.
        // We want to center the stack group vertically in the row.
        // Total height used = barHeight + (max_stack_index * offset_per_stack)
        // Let's assume max possible height for 3 stacks: 24 + (2 * 5) = 34.
        // Row height is 44. 34 fits with 5px padding top/bottom.
        
        // Adjust yTopBase to center the content
        final double maxStackHeight = 34.0; // Estimate
        final double yCenterOffset = (rowHeight - maxStackHeight) / 2;
        final double yBase = headerHeight + (i * rowHeight) + yCenterOffset;

        for (final segment in segments) {
             final daysFromStart = segment.start.difference(startDate).inDays;
             // Add +1 to duration to make end date inclusive
             final durationDays = segment.end.difference(segment.start).inDays + 1;
             
             final xStart = daysFromStart * dayWidth;
             final width = math.max(dayWidth, durationDays * dayWidth);
             
             // Optimization: Cull invisible trades
             if (xStart + width < scrollOffset || xStart > scrollOffset + viewportWidth) continue;

             // Vertical stacking logic
             // Shift down for higher stack index (cards on top of each other)
             // Use 5.0 as the vertical step
             final double verticalShift = segment.stackIndex * 5.0;
             
             final rect = Rect.fromLTWH(xStart, yBase + verticalShift, width, barHeight);

             final tradeId = segment.originalTrade.id ?? '';
             final isLive = userSettings?.isLiveActive(tradeId) ?? false;
             final isPaper = userSettings?.isPaperActive(tradeId) ?? false;
             
             final isLong = segment.originalTrade.direction == 'Long';
             
             // Override color with trade direction
             Color baseColor = isLong ? AppColors.long : AppColors.short;
             
             // Apply status opacity
             if (isLive) {
                 // Keep full color
             } else if (isPaper) {
                 baseColor = baseColor.withValues(alpha: 0.7);
             } else {
                 // Inactive
                 baseColor = Colors.grey.withValues(alpha: 0.3);
             }

             // Draw shadow
             final shadowPaint = Paint()
                ..color = Colors.black.withValues(alpha: 0.2)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
             
             // Draw shadow slightly offset
             canvas.drawRRect(
               RRect.fromRectAndRadius(rect.shift(const Offset(0, 3)), const Radius.circular(6)), 
               shadowPaint
             );

             // Draw Bar Body (Gradient & Effects)
             // Use a richer gradient for depth
             final gradientPaint = Paint()
               ..shader = LinearGradient(
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 colors: [
                   baseColor.withValues(alpha: isPaper || !isLive ? 0.85 : 1.0),
                   Color.lerp(baseColor, Colors.black, 0.2)!.withValues(alpha: isPaper || !isLive ? 0.65 : 1.0),
                 ],
               ).createShader(rect);

             final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
             canvas.drawRRect(rrect, gradientPaint);
             
             // Glass highlight (top edge) for "3D" feel
             final highlightPath = Path()
               ..addRRect(RRect.fromRectAndCorners(
                 Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height / 2.5),
                 topLeft: const Radius.circular(6),
                 topRight: const Radius.circular(6),
               ));
             
             final highlightPaint = Paint()
               ..shader = LinearGradient(
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 colors: [
                   Colors.white.withValues(alpha: 0.15),
                   Colors.white.withValues(alpha: 0.0),
                 ],
               ).createShader(rect);
               
             canvas.drawPath(highlightPath, highlightPaint);

             // Paper Trade Pattern (Diagonal Lines)
             if (isPaper) {
                 final patternPaint = Paint()
                   ..color = Colors.white.withValues(alpha: 0.15)
                   ..strokeWidth = 1.0
                   ..style = PaintingStyle.stroke;
                 
                 final patternSpacing = 6.0;
                 // Optimization: Clip to rect
                 canvas.save();
                 canvas.clipRRect(rrect);
                 
                 for (double x = rect.left - rect.height; x < rect.right; x += patternSpacing) {
                     canvas.drawLine(
                       Offset(x, rect.bottom),
                       Offset(x + rect.height, rect.top),
                       patternPaint
                     );
                 }
                 canvas.restore();
             }
             
             // Draw Thread Color Indicator (Left Strip)
             // Beautiful "tag" style on the left edge with rounded corners matching the card
             // Determine strip color based on trade direction
             final threadColor = segment.originalTrade.direction == 'Long' 
                 ? AppTheme.long 
                 : AppTheme.short;
            // final threadColor = AppTheme.long;
             final stripWidth = 5.0;
             final stripRect = Rect.fromLTWH(rect.left, rect.top, stripWidth, rect.height);
             
             final stripPath = Path()
                ..addRRect(RRect.fromRectAndCorners(
                  stripRect, 
                  topLeft: const Radius.circular(6), 
                  bottomLeft: const Radius.circular(6)
                ));
             
             canvas.drawPath(stripPath, Paint()..color = threadColor);
             
             // Draw Border/Cutout for stacking separation
             // Only needed if we want a distinct outline. The shadow handles separation well.
             // But a thin border makes it look sharper.
                 canvas.drawRRect(
               rrect, 
               tradeBorderPaint
             );
             
             // Draw Highlight if selected
             if (clickedTrade?.id != null && clickedTrade!.id == segment.originalTrade.id) {
                 final highlightPaint = Paint()
                   ..color = Colors.white
                   ..style = PaintingStyle.stroke
                   ..strokeWidth = 2.0;
                   
                 // Glow effect for selection?
                 final glowPaint = Paint()
                   ..color = Colors.white.withValues(alpha: 0.4)
                   ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
                   ..style = PaintingStyle.stroke
                   ..strokeWidth = 4.0;
                   
                 canvas.drawRRect(rrect, glowPaint);
                 canvas.drawRRect(rrect, highlightPaint);
             }
             
             // Symbol Text (only if visible size permits)
             if (width > 30) {
                 final textStyle = AppTextStyles.bodySmall.copyWith(
                     color: Colors.white,
                     fontSize: 11,
                     fontWeight: FontWeight.w700,
                     letterSpacing: 0.3,
                     shadows: [
                       Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black.withValues(alpha: 0.6))
                     ],
                   );
                   
                 // Add Status prefix
                 String statusPrefix = '';
                 // Optional: Use icon instead of text for P/L? 
                 // Space is tight. Text is clear.
                 if (isPaper) {
                    statusPrefix = 'P • ';
                 } else if (isLive) {
                    statusPrefix = 'L • ';
                 }
                 
                 final displayText = statusPrefix + segment.originalTrade.symbol;

                 textPainter.text = TextSpan(
                   text: displayText,
                   style: textStyle,
                 );
                 
                 // Measure text
                 final contentX = rect.left + stripWidth + 6; 
                 final contentWidth = rect.width - stripWidth - 8;
                 
                 textPainter.layout(maxWidth: math.max(0, contentWidth));
                 
                 if (textPainter.width <= contentWidth) {
                     // Calculate Sticky Position
                     // Visible range of this bar:
                     final visibleStart = math.max(contentX, scrollOffset + 4); 
                     final visibleEnd = math.min(contentX + contentWidth, scrollOffset + viewportWidth - 4);
                     
                     if (visibleStart < visibleEnd) {
                         final visibleCenter = (visibleStart + visibleEnd) / 2;
                         final textHalfWidth = textPainter.width / 2;
                         
                         // Ideal X for center of visible area
                         double drawX = visibleCenter - textHalfWidth;
                         
                         // Clamp to ensure text stays within the bar's content bounds
                         drawX = drawX.clamp(contentX, contentX + contentWidth - textPainter.width);
                         
                         // Center vertically
                         final textY = rect.top + (rect.height - textPainter.height) / 2;
                         textPainter.paint(canvas, Offset(drawX, textY));
                     }
                 }
             }
        }
    }

    // 4. Draw Today Line
    final today = DateTime.now();
    final todayDays = DateTime(today.year, today.month, today.day).difference(startDate).inDays;
    final todayX = todayDays * dayWidth + (dayWidth / 2);
    
    final todayPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
      
    canvas.drawLine(
      Offset(todayX, headerHeight), 
      Offset(todayX, size.height),
      todayPaint
    );
    
    final badgeWidth = 40.0;
    final badgeRect = Rect.fromLTWH(todayX - (badgeWidth / 2), headerHeight - 24, badgeWidth, 20);
    final badgePaint = Paint()..color = AppColors.primary;
    
    canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)), 
        badgePaint
    );
    
    textPainter.text = TextSpan(
        text: 'TODAY',
        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(todayX - (textPainter.width / 2), headerHeight - 20));

    if (selectedDate != null) {
        final selDays = selectedDate!.difference(startDate).inDays;
        if (selDays >= 0) {
             final selX = selDays * dayWidth + (dayWidth / 2);
             
             // Labels to draw (collision detection)
             final List<_LabelToDraw> labelsToDraw = [];
             final Set<double> drawnLinesX = {};

             // Check if we are hovering over any trade
             for (int i = 0; i < activeThreads.length; i++) {
                final threadId = activeThreads[i];
                final segments = threadSegments[threadId] ?? [];
                
                for (final segment in segments) {
                   final sStart = DateTime(segment.start.year, segment.start.month, segment.start.day);
                   final sEnd = DateTime(segment.end.year, segment.end.month, segment.end.day);
                   final sSel = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
                   
                   if (sSel.isAfter(sStart.subtract(const Duration(days: 1))) && sSel.isBefore(sEnd.add(const Duration(days: 1)))) {
                       final startDays = segment.start.difference(startDate).inDays;
                       final endDays = segment.end.difference(startDate).inDays;
                       
                       final startX = startDays * dayWidth;
                       // Add +1 to endDays to draw line at end of the inclusive day (start of next day)
                       final endX = (endDays + 1) * dayWidth; 
                       
                       // Add lines if not already added near same spot
                       if (!drawnLinesX.contains(startX)) drawnLinesX.add(startX);
                       if (!drawnLinesX.contains(endX)) drawnLinesX.add(endX);
                       
                       // Prepare Labels
                       final startDateStr = _formatDateShort(segment.start);
                       final endDateStr = _formatDateShort(segment.end);
                       final threadColor = _getThreadColor(threadId);

                       // Measure Start Label
                       textPainter.text = TextSpan(
                          text: startDateStr,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                       );
                       textPainter.layout();
                       labelsToDraw.add(_LabelToDraw(
                          text: startDateStr, 
                          x: startX, 
                          width: textPainter.width + 8, 
                          height: textPainter.height + 4,
                          color: threadColor
                       ));

                       // Measure End Label
                       textPainter.text = TextSpan(
                          text: endDateStr,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                       );
                       textPainter.layout();
                       labelsToDraw.add(_LabelToDraw(
                          text: endDateStr, 
                          x: endX, 
                          width: textPainter.width + 8, 
                          height: textPainter.height + 4,
                          color: threadColor
                       ));
                   }
                }
             }

             // Draw Dashed Lines (deduplicated)
             final markerPaint = Paint()
                ..color = Colors.white.withValues(alpha: 0.5)
                ..strokeWidth = 1
                ..style = PaintingStyle.stroke;
                
             for (final x in drawnLinesX) {
                 _drawDashedLine(canvas, x, headerHeight, size.height, markerPaint);
             }

             // Draw Labels with Collision Detection
             // Sort by X first
             labelsToDraw.sort((a, b) => a.x.compareTo(b.x));
             
             final List<Rect> occupiedRects = [];
             
             for (final label in labelsToDraw) {
                 double y = headerHeight + 6;
                 Rect rect = Rect.fromLTWH(label.x - (label.width / 2), y, label.width, label.height);
                 
                 // Push down if overlapping
                 int attempts = 0;
                 while (attempts < 10) {
                     bool overlap = false;
                     for (final occupied in occupiedRects) {
                         if (rect.overlaps(occupied)) {
                             overlap = true;
                             break;
                         }
                     }
                     if (!overlap) break;
                     
                     y += label.height + 2; // Move down
                     rect = Rect.fromLTWH(label.x - (label.width / 2), y, label.width, label.height);
                     attempts++;
                 }
                 
                 occupiedRects.add(rect);
                 _drawDateLabelRect(canvas, textPainter, label.text, rect, label.color);
             }

             // Draw the main cursor line
             final selPaint = Paint()
                ..color = Colors.white
                ..strokeWidth = 1;
             canvas.drawLine(Offset(selX, headerHeight), Offset(selX, size.height), selPaint);
             
             final dateStr = _formatDate(selectedDate!);
             textPainter.text = TextSpan(
                text: dateStr,
                style: const TextStyle(color: AppColors.background, fontSize: 10, fontWeight: FontWeight.bold)
             );
             textPainter.layout();
             
             final bubbleWidth = textPainter.width + 16;
             final bubbleHeight = 24.0;
             // Draw bubble at the bottom of the chart area (size.height - padding) or just below the cursor line
             // The query asked "show the date below the vertical line instead of on top of it". 
             // "On top of it" usually means overlaid on top or physically above. 
             // Let's place it at the very bottom of the viewable height.
             
             final bubbleRect = Rect.fromLTWH(selX - (bubbleWidth / 2), size.height - bubbleHeight - 2, bubbleWidth, bubbleHeight);
             
             final bubblePaint = Paint()..color = Colors.white;
             canvas.drawRRect(
                 RRect.fromRectAndRadius(bubbleRect, const Radius.circular(12)), 
                 bubblePaint
             );
             
             textPainter.paint(canvas, Offset(selX - (textPainter.width / 2), size.height - bubbleHeight + 4));
        }
    }
  }

  void _drawDashedLine(Canvas canvas, double x, double startY, double endY, Paint paint) {
    const double dashWidth = 4;
    const double dashSpace = 4;
    double currentY = startY;
    while (currentY < endY) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, math.min(currentY + dashWidth, endY)),
        paint,
      );
      currentY += dashWidth + dashSpace;
    }
  }

  void _drawDateLabelRect(Canvas canvas, TextPainter tp, String text, Rect rect, Color? color) {
      tp.text = TextSpan(
         text: text,
         style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
         ),
      );
      tp.layout();
      
      final bgPaint = Paint()..color = (color ?? Colors.black).withValues(alpha: 0.8);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), bgPaint);
      
      // Center text in rect
      final textX = rect.left + (rect.width - tp.width) / 2;
      final textY = rect.top + (rect.height - tp.height) / 2;
      
      tp.paint(canvas, Offset(textX, textY));
  }
  
  String _formatDateShort(DateTime date) {
     const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
     return '${months[date.month - 1]} ${date.day}';
  }
  
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getMonthName(int month) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months[month - 1];
  }

  String _getMonthNameFull(int month) {
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return months[month - 1];
  }

}

class _ZoomButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/seasonal_trade.dart';
import '../../models/seasonal_strategy_user_settings.dart';
import '../../theme/app_theme.dart';

import 'seasonal_trades_admin_view.dart'; // Import for AdminTradeCard

class SeasonalCalendarView extends StatefulWidget {
  final List<SeasonalTrade>? trades;
  final Function(SeasonalTrade)? onEditTrade;
  final SeasonalStrategyUserSettings? userRules;

  const SeasonalCalendarView({
    super.key, 
    this.trades, 
    this.onEditTrade,
    this.userRules,
  });

  @override
  State<SeasonalCalendarView> createState() => _SeasonalCalendarViewState();
}

class _SeasonalCalendarViewState extends State<SeasonalCalendarView> {
  late final ValueNotifier<List<SeasonalTrade>> _visibleTrades;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  SeasonalTrade? _highlightedTrade;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _visibleTrades = ValueNotifier([]);
    _updateVisibleTrades();
  }

  @override
  void didUpdateWidget(SeasonalCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trades != widget.trades) {
      _updateVisibleTrades();
    }
  }

  @override
  void dispose() {
    _visibleTrades.dispose();
    super.dispose();
  }

  // Parse MM-DD to current year's DateTime
  DateTime? _parseDate(String mmdd, int year) {
    try {
      final parts = mmdd.split('-');
      if (parts.length != 2) return null;
      return DateTime(year, int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  bool _isTradeActiveOn(SeasonalTrade trade, DateTime date) {
    final openDate = _parseDate(trade.openDate, date.year);
    var closeDate = _parseDate(trade.closeDate, date.year);

    if (openDate == null || closeDate == null) return false;
    
    final dateMd = date.month * 100 + date.day;
    final openMd = openDate.month * 100 + openDate.day;
    final closeMd = closeDate.month * 100 + closeDate.day;

    if (closeMd < openMd) {
      // Wrapped
      return dateMd >= openMd || dateMd <= closeMd;
    } else {
      // Normal
      return dateMd >= openMd && dateMd <= closeMd;
    }
  }

  List<SeasonalTrade> _getTradesForRange(DateTime start, DateTime end) {
    if (widget.trades == null) return [];
    return widget.trades!.where((t) {
      for (var day = start; day.isBefore(end.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
        if (_isTradeActiveOn(t, day)) return true;
      }
      return false;
    }).toList();
  }

  void _updateVisibleTrades() {
    DateTime start, end;
    
    if (_calendarFormat == CalendarFormat.month) {
       final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
       final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
       start = firstDay.subtract(const Duration(days: 7));
       end = lastDay.add(const Duration(days: 7));
    } else {
       final difference = _focusedDay.weekday - 1; 
       start = _focusedDay.subtract(Duration(days: difference));
       end = start.add(const Duration(days: 6));
    }
    
    final trades = _getTradesForRange(start, end);
    _visibleTrades.value = trades;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        TableCalendar<SeasonalTrade>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Month',
            CalendarFormat.week: 'Week',
          },
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12.0),
            ),
            formatButtonTextStyle: TextStyle(color: theme.colorScheme.onSurface),
            titleTextStyle: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            weekendTextStyle: TextStyle(color: theme.colorScheme.primary),
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
              _updateVisibleTrades();
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            _updateVisibleTrades();
          },
          calendarBuilders: CalendarBuilders(
             defaultBuilder: (context, day, focusedDay) {
               if (_highlightedTrade != null && _isTradeActiveOn(_highlightedTrade!, day)) {
                 return Center(
                   child: Container(
                     margin: const EdgeInsets.all(6.0),
                     alignment: Alignment.center,
                     decoration: BoxDecoration(
                       color: (_highlightedTrade!.direction == 'Long' ? AppTheme.long : AppTheme.short).withOpacity(0.2),
                       shape: BoxShape.circle,
                     ),
                     child: Text(
                       '${day.day}',
                       style: TextStyle(color: theme.colorScheme.onSurface),
                     ),
                   ),
                 );
               }
               return null;
             },
             markerBuilder: (context, date, events) {
               if (widget.trades == null) return null;
               final activeTrades = widget.trades!.where((t) => _isTradeActiveOn(t, date)).toList();
               if (activeTrades.isEmpty) return null;
               
               return Positioned(
                 bottom: 1,
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: activeTrades.take(3).map((e) {
                     return Container(
                       margin: const EdgeInsets.symmetric(horizontal: 0.5),
                       width: 6,
                       height: 6,
                       decoration: BoxDecoration(
                         shape: BoxShape.circle,
                         color: e.direction == 'Long' ? AppTheme.long : AppTheme.short,
                       ),
                     );
                   }).toList(),
                 ),
               );
             },
          ),
        ),
        const Divider(),
        Expanded(
          child: ValueListenableBuilder<List<SeasonalTrade>>(
            valueListenable: _visibleTrades,
            builder: (context, value, _) {
              if (value.isEmpty) {
                 return Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.event_busy, size: 48, color: theme.colorScheme.outline.withOpacity(0.5)),
                       const SizedBox(height: 16),
                       Text(
                         'No active trades in this view',
                         style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                       ),
                     ],
                   ),
                 );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Trades in this period (${value.length})',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: value.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final trade = value[index];
                        final isHighlighted = _highlightedTrade?.id == trade.id;
                        
                        return GestureDetector(
                          onTap: () {
                            if (widget.onEditTrade != null) {
                              widget.onEditTrade!(trade);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isHighlighted 
                                ? theme.colorScheme.primaryContainer.withOpacity(0.3) 
                                : theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              border: isHighlighted 
                                ? Border.all(color: theme.colorScheme.primary, width: 2)
                                : null,
                            ),
                            child: AdminTradeCard(
                              trade: trade, 
                              onEdit: () {
                                if (widget.onEditTrade != null) {
                                  widget.onEditTrade!(trade);
                                }
                              },
                              onDelete: () {}, // No delete in calendar view popups for now, or pass it down
                              userRules: widget.userRules,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

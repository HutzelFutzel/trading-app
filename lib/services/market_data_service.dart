import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/candle.dart';

class MarketDataService extends ChangeNotifier {
  static final MarketDataService _instance = MarketDataService._internal();
  factory MarketDataService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache: symbol -> sorted list of candles
  final Map<String, List<Candle>> _cache = {};
  
  // Track which symbols have full history loaded
  final Set<String> _fullHistoryLoaded = {};

  MarketDataService._internal();

  /// Fetches all candles for a symbol from Firestore.
  /// Checks cache first if full history is marked as loaded.
  Future<List<Candle>> getAllCandles(String symbol, {bool forceRefresh = false}) async {
    if (_fullHistoryLoaded.contains(symbol) && !forceRefresh) {
      return _cache[symbol] ?? [];
    }

    try {
      final snapshot = await _firestore
          .collection('market_data')
          .doc(symbol)
          .collection('candles')
          .orderBy('date')
          .get();

      final candles = snapshot.docs.map((doc) => Candle.fromJson(doc.data())).toList();
      
      _cache[symbol] = candles;
      _fullHistoryLoaded.add(symbol);
      notifyListeners();
      
      return candles;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching all candles for $symbol: $e');
      }
      rethrow;
    }
  }

  /// Fetches candles for a specific range.
  /// If data is locally available in the requested range (based on min/max of cache), returns it.
  /// If not, fetches from Firestore and updates cache.
  Future<List<Candle>> getCandlesRange(String symbol, DateTime start, DateTime end) async {
    // Ensure start is before end
    if (start.isAfter(end)) {
        final temp = start;
        start = end;
        end = temp;
    }

    final cached = _cache[symbol];
    if (cached != null && cached.isNotEmpty) {
       // Check if full history is loaded
       if (_fullHistoryLoaded.contains(symbol)) {
           return _filterCandles(cached, start, end);
       }
       
       // Check if cached range covers the request
       final minDate = cached.first.date;
       final maxDate = cached.last.date;
       
       // We assume cache is contiguous for the covered range to avoid complex gap tracking
       if ((minDate.isBefore(start) || minDate.isAtSameMomentAs(start)) && 
           (maxDate.isAfter(end) || maxDate.isAtSameMomentAs(end))) {
            return _filterCandles(cached, start, end);
       }
    }

    // Fetch from Firestore
    try {
      // Date format in Firestore is YYYY-MM-DD string
      final startStr = start.toIso8601String().split('T')[0];
      final endStr = end.toIso8601String().split('T')[0];

      final snapshot = await _firestore
          .collection('market_data')
          .doc(symbol)
          .collection('candles')
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .orderBy('date')
          .get();
          
      final newCandles = snapshot.docs.map((doc) => Candle.fromJson(doc.data())).toList();
      
      _mergeCandles(symbol, newCandles);
      
      // Return the merged/filtered result to ensure consistency
      // (or just newCandles if we don't care about overlapping boundaries from cache)
      // Merging is safer if the request overlapped with existing cache
      final updatedCache = _cache[symbol] ?? [];
      return _filterCandles(updatedCache, start, end);
      
    } catch (e) {
       if (kDebugMode) {
         print('Error fetching candles range for $symbol: $e');
       }
       // Fallback to cache if network fails and we have some data?
       if (cached != null) return _filterCandles(cached, start, end);
       rethrow;
    }
  }

  /// Calculates the average change for each day of the year over a range of years.
  /// 
  /// @param symbol The stock symbol.
  /// @param startYear The start year (inclusive).
  /// @param endYear The end year (inclusive).
  /// @returns A Map<int, double> where key is day of year (1-366) and value is average change.
  Future<Map<int, double>> calculateAverageDailyChange(String symbol, int startYear, int endYear) async {
      // 1. Fetch data for the entire range
      final startDate = DateTime(startYear, 1, 1);
      final endDate = DateTime(endYear, 12, 31);
      
      // This will use existing cache or fetch if missing
      final candles = await getCandlesRange(symbol, startDate, endDate);
      
      if (candles.isEmpty) return {};

      // 2. Prepare accumulators
      // We use a map to handle 366 days (leap years).
      // Key: Day of Year (1-366), Value: List of changes
      final Map<int, List<double>> dayChanges = {};
      
      for (int i = 1; i <= 366; i++) {
          dayChanges[i] = [];
      }

      // 3. Process candles
      for (final candle in candles) {
          // Skip if outside year range (getCandlesRange might return slightly broader range if logic changes)
          if (candle.date.year < startYear || candle.date.year > endYear) continue;

          // Determine day of year
          // final dayOfYear = _getDayOfYear(candle.date); // Unused

          
          // Handle Feb 29 (Day 60 in leap year)
          // Standard years have 365 days. Leap years have 366.
          // In non-leap years, March 1st is day 60. In leap years, Feb 29 is day 60.
          // This causes misalignment if we strictly map 1-365.
          // Strategy: Normalize to 366 days. 
          // In non-leap years, skip day 60 (Feb 29 placeholder) effectively shifting March 1st to day 61?
          // Or stick to calendar date:
          // Jan 1 -> 1
          // ...
          // Feb 28 -> 59
          // Feb 29 -> 60
          // Mar 1 -> 61 (in leap), 60 (in non-leap)
          
          // Better approach for seasonality: align by calendar date (Month/Day).
          // Let's map MM-DD to a canonical 1-366 index.
          // Jan 1 = 1
          // ...
          // Feb 29 = 60
          // Mar 1 = 61
          // ...
          // Dec 31 = 366
          
          final canonicalDayIndex = _getCanonicalDayIndex(candle.date);
          dayChanges[canonicalDayIndex]?.add(candle.change);
      }

      // 4. Calculate Averages
      final Map<int, double> averages = {};
      dayChanges.forEach((day, changes) {
          // Remove 0s from the average array? 
          // User request: "remove all 0s from the average array".
          // Ambiguous: 
          // a) Remove 0 change values from the input set before averaging? (Implies 0 change is "no data" or ignored)
          // b) Remove days that have 0 average from the final result?
          // Context: "determine the number of the day ... add change value ... calculate average ... then remove all 0s from the average array"
          // Likely means: Filter out days where the calculated average is 0 (or no data).
          // However, a change of 0% is a valid market move (unchanged). 
          // Usually "remove 0s" implies ignoring missing data points if 0 was used as placeholder.
          // But our candle.change is real data.
          // Let's assume user means "Remove entries where we have no data or result is exactly 0 due to no significant data".
          // Or maybe "remove 0s from the inputs" to avoid skewing if 0 means "missing"?
          // But getCandlesRange returns real candles. 
          // Let's compute average of ALL non-empty lists.
          
          if (changes.isNotEmpty) {
             final nonZeroChanges = changes.where((c) => c != 0).toList();
             // If we remove 0s from inputs:
             if (nonZeroChanges.isNotEmpty) {
                final sum = nonZeroChanges.reduce((a, b) => a + b);
                averages[day] = sum / nonZeroChanges.length;
             }
             // If we keep 0s (valid flat day):
             // final sum = changes.reduce((a, b) => a + b);
             // averages[day] = sum / changes.length;
          }
      });
      
      return averages;
  }
  
  int _getDayOfYear(DateTime date) {
      return int.parse("${date.difference(DateTime(date.year, 1, 1)).inDays + 1}");
  }

  /// Returns a day index from 1 to 366.
  /// Feb 29 is 60.
  /// Mar 1 is 61.
  /// For non-leap years, Feb 29 (60) is skipped, so Feb 28 is 59 and Mar 1 is 61.
  int _getCanonicalDayIndex(DateTime date) {
      final isLeap = _isLeapYear(date.year);
      final dayOfYear = _getDayOfYear(date);
      
      if (isLeap) {
          return dayOfYear;
      } else {
          // Non-leap year
          // Days before Mar 1 are correct (1-59)
          // Days from Mar 1 onwards need to be shifted by +1 to match the 366-day scale
          if (dayOfYear >= 60) {
              return dayOfYear + 1;
          }
          return dayOfYear;
      }
  }
  
  bool _isLeapYear(int year) {
      if (year % 4 != 0) return false;
      if (year % 100 != 0) return true;
      if (year % 400 != 0) return false;
      return true;
  }

  List<Candle> _filterCandles(List<Candle> candles, DateTime start, DateTime end) {
      // Allow slight buffer or exact date match
      // Firestore dates are YYYY-MM-DD, DateTime usually has time components. 
      // Comparison should ideally ignore time or be consistent.
      // Candle.fromJson parses YYYY-MM-DD to local time 00:00:00 (or UTC depending on parsing).
      // DateTime.parse('YYYY-MM-DD') creates a local DateTime at midnight.
      
      return candles.where((c) {
          return (c.date.isAfter(start) || c.date.isAtSameMomentAs(start)) && 
                 (c.date.isBefore(end) || c.date.isAtSameMomentAs(end));
      }).toList();
  }

  void _mergeCandles(String symbol, List<Candle> newCandles) {
      if (newCandles.isEmpty) return;
      
      final current = _cache[symbol] ?? [];
      final Map<String, Candle> combined = {};
      
      // Use date string as key to deduplicate
      for (var c in current) {
          combined[c.date.toIso8601String().split('T')[0]] = c;
      }
      for (var c in newCandles) {
          combined[c.date.toIso8601String().split('T')[0]] = c;
      }
      
      final sorted = combined.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
        
      _cache[symbol] = sorted;
      notifyListeners();
  }
}

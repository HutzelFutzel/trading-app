class SeasonalTrade {
  final String? id;
  final String openDate;
  final String closeDate;
  final String symbol;
  final String? name;
  final String direction;
  final bool verifiedByApi;
  final bool symbolExists;
  final bool tradeDirectionPossible;

  SeasonalTrade({
    this.id,
    required this.openDate,
    required this.closeDate,
    required this.symbol,
    this.name,
    required this.direction,
    this.verifiedByApi = false,
    this.symbolExists = false,
    this.tradeDirectionPossible = false,
  });

  factory SeasonalTrade.fromJson(Map<String, dynamic> json) {
    return SeasonalTrade(
      id: json['id'],
      openDate: json['openDate'],
      closeDate: json['closeDate'],
      symbol: json['symbol'],
      name: json['name'],
      direction: json['direction'],
      verifiedByApi: json['verifiedByApi'] ?? false,
      symbolExists: json['symbolExists'] ?? false,
      tradeDirectionPossible: json['tradeDirectionPossible'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'openDate': openDate,
      'closeDate': closeDate,
      'symbol': symbol,
      'name': name,
      'direction': direction,
      'verifiedByApi': verifiedByApi,
      'symbolExists': symbolExists,
      'tradeDirectionPossible': tradeDirectionPossible,
    };
  }

  bool get isOngoing {
    final now = DateTime.now();
    try {
      final openParts = openDate.split('-');
      final closeParts = closeDate.split('-');
      
      final openMonth = int.parse(openParts[0]);
      final openDay = int.parse(openParts[1]);
      final closeMonth = int.parse(closeParts[0]);
      final closeDay = int.parse(closeParts[1]);

      if (closeMonth < openMonth || (closeMonth == openMonth && closeDay < openDay)) {
        // Crosses year boundary (e.g. Dec to Jan)
        final currentMD = now.month * 100 + now.day;
        final openMD = openMonth * 100 + openDay;
        final closeMD = closeMonth * 100 + closeDay;
        
        // Ongoing if we are AFTER open OR BEFORE close
        return currentMD >= openMD || currentMD <= closeMD;
      } else {
        // Same year
        final currentMD = now.month * 100 + now.day;
        final openMD = openMonth * 100 + openDay;
        final closeMD = closeMonth * 100 + closeDay;
        return currentMD >= openMD && currentMD <= closeMD;
      }
    } catch (e) {
      return false;
    }
  }

  bool isOngoingForYear(int year) {
    final now = DateTime.now();
    try {
      final openParts = openDate.split('-');
      final closeParts = closeDate.split('-');
      
      int getPart(List<String> parts, int indexFromEnd) {
        return int.parse(parts[parts.length - indexFromEnd]);
      }

      if (openParts.length >= 2 && closeParts.length >= 2) {
         final openM = getPart(openParts, 2);
         final openD = getPart(openParts, 1);
         final closeM = getPart(closeParts, 2);
         final closeD = getPart(closeParts, 1);
         
         int endYear = year;
         if (closeM < openM || (closeM == openM && closeD < openD)) {
            endYear++;
         }
         
         final theoreticalExit = DateTime(endYear, closeM, closeD, 23, 59, 59);
         
         // Logic: If the trade for this year's cycle is currently active
         // We construct the entry for this year
         final theoreticalEntry = DateTime(year, openM, openD);
         
         // Check if NOW is within [Entry, Exit]
         if (now.isAfter(theoreticalEntry) && now.isBefore(theoreticalExit)) {
           return true;
         }
      }
    } catch (_) {}
    return false;
  }
}

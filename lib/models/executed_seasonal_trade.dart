class ExecutedSeasonalTrade {
  final String? id;
  final String userId;
  final String? accountId;
  final String tradeId;
  final DateTime actualOpenDate;
  final DateTime? actualCloseDate;
  final double openPrice;
  final int numberAssets;
  final int? qty;
  final bool completed;
  final double? profit;
  final double? maxDrop;
  final double? maxRise;
  final double invested;
  final double? outcome;
  final String openOrderId;
  final String? closeOrderId;
  final bool isPaper;
  
  final double? portfolioWeightAtOpen;
  final double? portfolioWeightAtClose;
  
  // Display helpers
  final String? symbol;
  final String? name;
  final String? direction;

  ExecutedSeasonalTrade({
    this.id,
    required this.userId,
    this.accountId,
    required this.tradeId,
    required this.actualOpenDate,
    this.actualCloseDate,
    required this.openPrice,
    required this.numberAssets,
    this.qty,
    required this.completed,
    this.profit,
    this.maxDrop,
    this.maxRise,
    required this.invested,
    this.outcome,
    required this.openOrderId,
    this.closeOrderId,
    required this.isPaper,
    this.portfolioWeightAtOpen,
    this.portfolioWeightAtClose,
    this.symbol,
    this.name,
    this.direction,
  });

  factory ExecutedSeasonalTrade.fromJson(Map<String, dynamic> json) {
    return ExecutedSeasonalTrade(
      id: json['id'],
      userId: json['userId'] ?? '', // Default to empty if missing for now
      accountId: json['accountId'],
      tradeId: json['tradeId'],
      actualOpenDate: DateTime.parse(json['actualOpenDate']),
      actualCloseDate: json['actualCloseDate'] != null ? DateTime.parse(json['actualCloseDate']) : null,
      openPrice: (json['openPrice'] as num).toDouble(),
      numberAssets: json['numberAssets'],
      qty: json['qty'],
      completed: json['completed'],
      profit: json['profit'] != null ? (json['profit'] as num).toDouble() : null,
      maxDrop: json['maxDrop'] != null ? (json['maxDrop'] as num).toDouble() : null,
      maxRise: json['maxRise'] != null ? (json['maxRise'] as num).toDouble() : null,
      invested: (json['invested'] as num).toDouble(),
      outcome: json['outcome'] != null ? (json['outcome'] as num).toDouble() : null,
      openOrderId: json['openOrderId'],
      closeOrderId: json['closeOrderId'],
      isPaper: json['isPaper'] ?? true, // Default to paper for backward compatibility
      portfolioWeightAtOpen: json['portfolioWeightAtOpen'] != null ? (json['portfolioWeightAtOpen'] as num).toDouble() : null,
      portfolioWeightAtClose: json['portfolioWeightAtClose'] != null ? (json['portfolioWeightAtClose'] as num).toDouble() : null,
      symbol: json['symbol'],
      name: json['name'],
      direction: json['direction'],
    );
  }
}

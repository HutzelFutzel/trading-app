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
}

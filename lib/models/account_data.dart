class Account {
  final String id;
  final String currency;
  final double cash;
  final double portfolioValue;
  final double buyingPower;
  final double equity;

  Account({
    required this.id,
    required this.currency,
    required this.cash,
    required this.portfolioValue,
    required this.buyingPower,
    required this.equity,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? '',
      currency: json['currency'] ?? 'USD',
      cash: (json['cash'] ?? 0).toDouble(),
      portfolioValue: (json['portfolioValue'] ?? 0).toDouble(),
      buyingPower: (json['buyingPower'] ?? 0).toDouble(),
      equity: (json['equity'] ?? 0).toDouble(),
    );
  }
}

class Position {
  final String symbol;
  final double qty;
  final double avgEntryPrice;
  final double currentPrice;
  final double marketValue;
  final double unrealizedPl;
  final double unrealizedPlpc;

  Position({
    required this.symbol,
    required this.qty,
    required this.avgEntryPrice,
    required this.currentPrice,
    required this.marketValue,
    required this.unrealizedPl,
    required this.unrealizedPlpc,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      symbol: json['symbol'] ?? '',
      qty: (json['qty'] ?? 0).toDouble(),
      avgEntryPrice: (json['avgEntryPrice'] ?? 0).toDouble(),
      currentPrice: (json['currentPrice'] ?? 0).toDouble(),
      marketValue: (json['marketValue'] ?? 0).toDouble(),
      unrealizedPl: (json['unrealizedPl'] ?? 0).toDouble(),
      unrealizedPlpc: (json['unrealizedPlpc'] ?? 0).toDouble(),
    );
  }
}

class Order {
  final String id;
  final String symbol;
  final double qty;
  final String side;
  final String type;
  final String status;
  final double filledQty;
  final double? avgFillPrice;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.symbol,
    required this.qty,
    required this.side,
    required this.type,
    required this.status,
    required this.filledQty,
    this.avgFillPrice,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      qty: (json['qty'] ?? 0).toDouble(),
      side: json['side'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      filledQty: (json['filledQty'] ?? 0).toDouble(),
      avgFillPrice: json['avgFillPrice'] != null ? (json['avgFillPrice']).toDouble() : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}


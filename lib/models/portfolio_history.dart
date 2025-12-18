class PortfolioHistory {
  final List<int> timestamp;
  final List<double> equity;
  final List<double> profitLoss;
  final List<double> profitLossPct;
  final double baseValue;
  final String timeframe;

  PortfolioHistory({
    required this.timestamp,
    required this.equity,
    required this.profitLoss,
    required this.profitLossPct,
    required this.baseValue,
    required this.timeframe,
  });

  factory PortfolioHistory.fromJson(Map<String, dynamic> json) {
    return PortfolioHistory(
      timestamp: List<int>.from(json['timestamp']),
      equity: List<double>.from(json['equity'].map((x) => x?.toDouble() ?? 0.0)),
      profitLoss: List<double>.from(json['profitLoss'].map((x) => x?.toDouble() ?? 0.0)),
      profitLossPct: List<double>.from(json['profitLossPct'].map((x) => x?.toDouble() ?? 0.0)),
      baseValue: (json['baseValue'] as num).toDouble(),
      timeframe: json['timeframe'],
    );
  }
}


class SeasonalStrategySettings {
  final String? id;
  final String openOrderType;
  final String openOrderTIF;
  final String closeOrderType;
  final String closeOrderTIF;

  SeasonalStrategySettings({
    this.id,
    required this.openOrderType,
    required this.openOrderTIF,
    required this.closeOrderType,
    required this.closeOrderTIF,
  });

  factory SeasonalStrategySettings.defaults() {
    return SeasonalStrategySettings(
      openOrderType: 'market',
      openOrderTIF: 'gtc',
      closeOrderType: 'market',
      closeOrderTIF: 'gtc',
    );
  }

  factory SeasonalStrategySettings.fromJson(Map<String, dynamic> json) {
    return SeasonalStrategySettings(
      id: json['id'],
      openOrderType: json['openOrderType'] ?? 'market',
      openOrderTIF: json['openOrderTIF'] ?? 'gtc',
      closeOrderType: json['closeOrderType'] ?? 'market',
      closeOrderTIF: json['closeOrderTIF'] ?? 'gtc',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'openOrderType': openOrderType,
      'openOrderTIF': openOrderTIF,
      'closeOrderType': closeOrderType,
      'closeOrderTIF': closeOrderTIF,
    };
  }

  SeasonalStrategySettings copyWith({
    String? id,
    String? openOrderType,
    String? openOrderTIF,
    String? closeOrderType,
    String? closeOrderTIF,
  }) {
    return SeasonalStrategySettings(
      id: id ?? this.id,
      openOrderType: openOrderType ?? this.openOrderType,
      openOrderTIF: openOrderTIF ?? this.openOrderTIF,
      closeOrderType: closeOrderType ?? this.closeOrderType,
      closeOrderTIF: closeOrderTIF ?? this.closeOrderTIF,
    );
  }
}

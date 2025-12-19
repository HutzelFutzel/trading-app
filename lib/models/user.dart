class AlpacaAccount {
  final String id;
  final String apiKey;
  final String apiSecret;
  final bool verified;
  final String? alpacaAccountId;
  final String? accountNumber;
  final double maxUtilizationPercentage;
  final bool allowShortTrading;
  final bool enabled;

  AlpacaAccount({
    required this.id,
    required this.apiKey,
    required this.apiSecret,
    this.verified = false,
    this.alpacaAccountId,
    this.accountNumber,
    this.maxUtilizationPercentage = 100.0,
    this.allowShortTrading = true,
    this.enabled = true,
  });

  factory AlpacaAccount.fromJson(Map<String, dynamic> json) {
    return AlpacaAccount(
      id: json['id'],
      apiKey: json['apiKey'] ?? '',
      apiSecret: json['apiSecret'] ?? '',
      verified: json['verified'] ?? false,
      alpacaAccountId: json['alpacaAccountId'],
      accountNumber: json['accountNumber'],
      maxUtilizationPercentage: (json['maxUtilizationPercentage'] as num?)?.toDouble() ?? 100.0,
      allowShortTrading: json['allowShortTrading'] ?? true,
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'verified': verified,
      if (alpacaAccountId != null) 'alpacaAccountId': alpacaAccountId,
      if (accountNumber != null) 'accountNumber': accountNumber,
      'maxUtilizationPercentage': maxUtilizationPercentage,
      'allowShortTrading': allowShortTrading,
      'enabled': enabled,
    };
  }

  AlpacaAccount copyWith({
    String? id,
    String? apiKey,
    String? apiSecret,
    bool? verified,
    String? alpacaAccountId,
    String? accountNumber,
    double? maxUtilizationPercentage,
    bool? allowShortTrading,
    bool? enabled,
  }) {
    return AlpacaAccount(
      id: id ?? this.id,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      verified: verified ?? this.verified,
      alpacaAccountId: alpacaAccountId ?? this.alpacaAccountId,
      accountNumber: accountNumber ?? this.accountNumber,
      maxUtilizationPercentage: maxUtilizationPercentage ?? this.maxUtilizationPercentage,
      allowShortTrading: allowShortTrading ?? this.allowShortTrading,
      enabled: enabled ?? this.enabled,
    );
  }
}

class User {
  final String? id;
  final String userId;
  final bool isAdmin;
  final AlpacaAccount? alpacaPaperAccount;
  final AlpacaAccount? alpacaLiveAccount;

  User({
    this.id,
    required this.userId,
    this.isAdmin = false,
    this.alpacaPaperAccount,
    this.alpacaLiveAccount,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      userId: json['userId'],
      isAdmin: json['isAdmin'] ?? false,
      alpacaPaperAccount: json['alpacaPaperAccount'] != null
          ? AlpacaAccount.fromJson(json['alpacaPaperAccount'])
          : null,
      alpacaLiveAccount: json['alpacaLiveAccount'] != null
          ? AlpacaAccount.fromJson(json['alpacaLiveAccount'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'isAdmin': isAdmin,
      if (alpacaPaperAccount != null) 'alpacaPaperAccount': alpacaPaperAccount!.toJson(),
      if (alpacaLiveAccount != null) 'alpacaLiveAccount': alpacaLiveAccount!.toJson(),
    };
  }

  User copyWith({
    String? id,
    String? userId,
    bool? isAdmin,
    AlpacaAccount? alpacaPaperAccount,
    AlpacaAccount? alpacaLiveAccount,
  }) {
    return User(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isAdmin: isAdmin ?? this.isAdmin,
      alpacaPaperAccount: alpacaPaperAccount ?? this.alpacaPaperAccount,
      alpacaLiveAccount: alpacaLiveAccount ?? this.alpacaLiveAccount,
    );
  }
}

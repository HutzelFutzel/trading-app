class AlpacaAccount {
  final String id;
  final String label;
  final String apiKey;
  final String apiSecret;
  final bool isPaper;
  final bool verified;
  final String? alpacaAccountId;

  AlpacaAccount({
    required this.id,
    required this.label,
    required this.apiKey,
    required this.apiSecret,
    required this.isPaper,
    this.verified = false,
    this.alpacaAccountId,
  });

  factory AlpacaAccount.fromJson(Map<String, dynamic> json) {
    return AlpacaAccount(
      id: json['id'],
      label: json['label'],
      apiKey: json['apiKey'],
      apiSecret: json['apiSecret'],
      isPaper: json['isPaper'] ?? true,
      verified: json['verified'] ?? false,
      alpacaAccountId: json['alpacaAccountId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'isPaper': isPaper,
      'verified': verified,
      if (alpacaAccountId != null) 'alpacaAccountId': alpacaAccountId,
    };
  }

  AlpacaAccount copyWith({
    String? id,
    String? label,
    String? apiKey,
    String? apiSecret,
    bool? isPaper,
    bool? verified,
    String? alpacaAccountId,
  }) {
    return AlpacaAccount(
      id: id ?? this.id,
      label: label ?? this.label,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      isPaper: isPaper ?? this.isPaper,
      verified: verified ?? this.verified,
      alpacaAccountId: alpacaAccountId ?? this.alpacaAccountId,
    );
  }
}

class LinkedAccountIds {
  final String? paperAccountId;
  final String? liveAccountId;

  LinkedAccountIds({this.paperAccountId, this.liveAccountId});

  factory LinkedAccountIds.fromJson(Map<String, dynamic> json) {
    return LinkedAccountIds(
      paperAccountId: json['paperAccountId'],
      liveAccountId: json['liveAccountId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paperAccountId': paperAccountId,
      'liveAccountId': liveAccountId,
    };
  }
  
  LinkedAccountIds copyWith({
    String? paperAccountId,
    String? liveAccountId,
  }) {
    return LinkedAccountIds(
      paperAccountId: paperAccountId ?? this.paperAccountId,
      liveAccountId: liveAccountId ?? this.liveAccountId,
    );
  }
}

class User {
  final String? id;
  final String userId;
  final bool isAdmin;
  final List<AlpacaAccount> alpacaAccounts;
  final bool enableLiveTrading;
  final bool enablePaperTrading;
  final LinkedAccountIds? linkAccountSeasonal;
  final LinkedAccountIds? linkAccountDaytrade;

  User({
    this.id,
    required this.userId,
    this.isAdmin = false,
    required this.alpacaAccounts,
    this.enableLiveTrading = false,
    this.enablePaperTrading = true,
    this.linkAccountSeasonal,
    this.linkAccountDaytrade,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      userId: json['userId'],
      isAdmin: json['isAdmin'] ?? false,
      alpacaAccounts: (json['alpacaAccounts'] as List?)
          ?.map((e) => AlpacaAccount.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      enableLiveTrading: json['enableLiveTrading'] ?? false,
      enablePaperTrading: json['enablePaperTrading'] ?? true,
      linkAccountSeasonal: json['linkAccountSeasonal'] != null
          ? LinkedAccountIds.fromJson(json['linkAccountSeasonal'])
          : null,
      linkAccountDaytrade: json['linkAccountDaytrade'] != null
          ? LinkedAccountIds.fromJson(json['linkAccountDaytrade'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'isAdmin': isAdmin,
      'alpacaAccounts': alpacaAccounts.map((e) => e.toJson()).toList(),
      'enableLiveTrading': enableLiveTrading,
      'enablePaperTrading': enablePaperTrading,
      if (linkAccountSeasonal != null) 'linkAccountSeasonal': linkAccountSeasonal!.toJson(),
      if (linkAccountDaytrade != null) 'linkAccountDaytrade': linkAccountDaytrade!.toJson(),
    };
  }

  User copyWith({
    String? id,
    String? userId,
    bool? isAdmin,
    List<AlpacaAccount>? alpacaAccounts,
    bool? enableLiveTrading,
    bool? enablePaperTrading,
    LinkedAccountIds? linkAccountSeasonal,
    LinkedAccountIds? linkAccountDaytrade,
  }) {
    return User(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isAdmin: isAdmin ?? this.isAdmin,
      alpacaAccounts: alpacaAccounts ?? this.alpacaAccounts,
      enableLiveTrading: enableLiveTrading ?? this.enableLiveTrading,
      enablePaperTrading: enablePaperTrading ?? this.enablePaperTrading,
      linkAccountSeasonal: linkAccountSeasonal ?? this.linkAccountSeasonal,
      linkAccountDaytrade: linkAccountDaytrade ?? this.linkAccountDaytrade,
    );
  }
}


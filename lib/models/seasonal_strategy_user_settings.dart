class SeasonalStrategyUserSettings {
  final String? id;
  final String userId;
  final String? accountId;
  final bool enablePaperTrading;
  final bool enableLiveTrading;
  final String allocationMode;
  final Map<int, double> customAllocations;
  final double maxMargin;
  final bool allowThreadOverlap;
  final List<String> paperTradeIds;
  final List<String> liveTradeIds;
  
  // Thread assignments
  final List<String> thread1;
  final List<String> thread2;
  final List<String> thread3;
  final List<String> thread4;
  final List<String> thread5;
  final List<String> thread6;
  final List<String> thread7;
  final List<String> thread8;
  final List<String> thread9;
  final List<String> thread10;

  SeasonalStrategyUserSettings({
    this.id,
    required this.userId,
    this.accountId,
    required this.enablePaperTrading,
    required this.enableLiveTrading,
    required this.allocationMode,
    required this.customAllocations,
    required this.maxMargin,
    required this.allowThreadOverlap,
    required this.paperTradeIds,
    required this.liveTradeIds,
    this.thread1 = const [],
    this.thread2 = const [],
    this.thread3 = const [],
    this.thread4 = const [],
    this.thread5 = const [],
    this.thread6 = const [],
    this.thread7 = const [],
    this.thread8 = const [],
    this.thread9 = const [],
    this.thread10 = const [],
  });

  factory SeasonalStrategyUserSettings.defaults({required String userId}) {
    return SeasonalStrategyUserSettings(
      userId: userId,
      enablePaperTrading: true,
      enableLiveTrading: false,
      allocationMode: 'equal',
      customAllocations: {},
      maxMargin: 0,
      allowThreadOverlap: false,
      paperTradeIds: [],
      liveTradeIds: [],
    );
  }

  factory SeasonalStrategyUserSettings.fromJson(Map<String, dynamic> json) {
    Map<int, double> allocations = {};
    if (json['customAllocations'] != null) {
      (json['customAllocations'] as Map<String, dynamic>).forEach((key, value) {
        allocations[int.parse(key)] = (value as num).toDouble();
      });
    }

    List<String> parseThread(String key) {
      return (json[key] as List?)?.map((e) => e.toString()).toList() ?? [];
    }

    return SeasonalStrategyUserSettings(
      id: json['id'],
      userId: json['userId'],
      accountId: json['accountId'],
      enablePaperTrading: json['enablePaperTrading'] ?? true,
      enableLiveTrading: json['enableLiveTrading'] ?? false,
      allocationMode: json['allocationMode'] ?? 'equal',
      customAllocations: allocations,
      maxMargin: (json['maxMargin'] as num?)?.toDouble() ?? 0.0,
      allowThreadOverlap: json['allowThreadOverlap'] ?? false,
      paperTradeIds: (json['paperTradeIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      liveTradeIds: (json['liveTradeIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      thread1: parseThread('thread1'),
      thread2: parseThread('thread2'),
      thread3: parseThread('thread3'),
      thread4: parseThread('thread4'),
      thread5: parseThread('thread5'),
      thread6: parseThread('thread6'),
      thread7: parseThread('thread7'),
      thread8: parseThread('thread8'),
      thread9: parseThread('thread9'),
      thread10: parseThread('thread10'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      if (accountId != null) 'accountId': accountId,
      'enablePaperTrading': enablePaperTrading,
      'enableLiveTrading': enableLiveTrading,
      'allocationMode': allocationMode,
      'customAllocations': customAllocations.map((k, v) => MapEntry(k.toString(), v)),
      'maxMargin': maxMargin,
      'allowThreadOverlap': allowThreadOverlap,
      'paperTradeIds': paperTradeIds,
      'liveTradeIds': liveTradeIds,
      'thread1': thread1,
      'thread2': thread2,
      'thread3': thread3,
      'thread4': thread4,
      'thread5': thread5,
      'thread6': thread6,
      'thread7': thread7,
      'thread8': thread8,
      'thread9': thread9,
      'thread10': thread10,
    };
  }

  SeasonalStrategyUserSettings copyWith({
    String? id,
    String? userId,
    String? accountId,
    bool? enablePaperTrading,
    bool? enableLiveTrading,
    String? allocationMode,
    Map<int, double>? customAllocations,
    double? maxMargin,
    bool? allowThreadOverlap,
    List<String>? paperTradeIds,
    List<String>? liveTradeIds,
    List<String>? thread1,
    List<String>? thread2,
    List<String>? thread3,
    List<String>? thread4,
    List<String>? thread5,
    List<String>? thread6,
    List<String>? thread7,
    List<String>? thread8,
    List<String>? thread9,
    List<String>? thread10,
  }) {
    return SeasonalStrategyUserSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      enablePaperTrading: enablePaperTrading ?? this.enablePaperTrading,
      enableLiveTrading: enableLiveTrading ?? this.enableLiveTrading,
      allocationMode: allocationMode ?? this.allocationMode,
      customAllocations: customAllocations ?? this.customAllocations,
      maxMargin: maxMargin ?? this.maxMargin,
      allowThreadOverlap: allowThreadOverlap ?? this.allowThreadOverlap,
      paperTradeIds: paperTradeIds ?? this.paperTradeIds,
      liveTradeIds: liveTradeIds ?? this.liveTradeIds,
      thread1: thread1 ?? this.thread1,
      thread2: thread2 ?? this.thread2,
      thread3: thread3 ?? this.thread3,
      thread4: thread4 ?? this.thread4,
      thread5: thread5 ?? this.thread5,
      thread6: thread6 ?? this.thread6,
      thread7: thread7 ?? this.thread7,
      thread8: thread8 ?? this.thread8,
      thread9: thread9 ?? this.thread9,
      thread10: thread10 ?? this.thread10,
    );
  }

  // --- Logic Helpers ---

  bool isPaperActive(String tradeId) => paperTradeIds.contains(tradeId);
  bool isLiveActive(String tradeId) => liveTradeIds.contains(tradeId);

  int getThreadForTrade(String tradeId) {
    if (thread1.contains(tradeId)) return 1;
    if (thread2.contains(tradeId)) return 2;
    if (thread3.contains(tradeId)) return 3;
    if (thread4.contains(tradeId)) return 4;
    if (thread5.contains(tradeId)) return 5;
    if (thread6.contains(tradeId)) return 6;
    if (thread7.contains(tradeId)) return 7;
    if (thread8.contains(tradeId)) return 8;
    if (thread9.contains(tradeId)) return 9;
    if (thread10.contains(tradeId)) return 10;
    return 1; // Default
  }

  SeasonalStrategyUserSettings togglePaper(String tradeId, bool active) {
    final list = List<String>.from(paperTradeIds);
    if (active) {
      if (!list.contains(tradeId)) list.add(tradeId);
    } else {
      list.remove(tradeId);
    }
    return copyWith(paperTradeIds: list);
  }

  SeasonalStrategyUserSettings toggleLive(String tradeId, bool active) {
    final list = List<String>.from(liveTradeIds);
    if (active) {
      if (!list.contains(tradeId)) list.add(tradeId);
    } else {
      list.remove(tradeId);
    }
    return copyWith(liveTradeIds: list);
  }

  SeasonalStrategyUserSettings assignTradeToThread(String tradeId, int targetThread) {
    final cleanId = tradeId.trim();
    
    // Step 1: Remove from all using filter to ensure all instances are removed
    List<String> removeFrom(List<String> source) {
      return source.where((id) => id.trim() != cleanId).toList();
    }

    var t1 = removeFrom(thread1);
    var t2 = removeFrom(thread2);
    var t3 = removeFrom(thread3);
    var t4 = removeFrom(thread4);
    var t5 = removeFrom(thread5);
    var t6 = removeFrom(thread6);
    var t7 = removeFrom(thread7);
    var t8 = removeFrom(thread8);
    var t9 = removeFrom(thread9);
    var t10 = removeFrom(thread10);

    // Step 2: Add to respective
    if (targetThread == 1) t1.add(cleanId);
    else if (targetThread == 2) t2.add(cleanId);
    else if (targetThread == 3) t3.add(cleanId);
    else if (targetThread == 4) t4.add(cleanId);
    else if (targetThread == 5) t5.add(cleanId);
    else if (targetThread == 6) t6.add(cleanId);
    else if (targetThread == 7) t7.add(cleanId);
    else if (targetThread == 8) t8.add(cleanId);
    else if (targetThread == 9) t9.add(cleanId);
    else if (targetThread == 10) t10.add(cleanId);

    return copyWith(
      thread1: t1,
      thread2: t2,
      thread3: t3,
      thread4: t4,
      thread5: t5,
      thread6: t6,
      thread7: t7,
      thread8: t8,
      thread9: t9,
      thread10: t10,
    );
  }
}

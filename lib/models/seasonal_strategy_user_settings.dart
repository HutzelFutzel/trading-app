import 'package:flutter/foundation.dart';

class SeasonalStrategyUserSettings {
  final String? id;
  final String userId;
  final String? accountId;
  final String allocationMode;
  final Map<int, double> customAllocationsPaper;
  final Map<int, double> customAllocationsLive;
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
    required this.allocationMode,
    required this.customAllocationsPaper,
    required this.customAllocationsLive,
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
      allocationMode: 'equal',
      customAllocationsPaper: {},
      customAllocationsLive: {},
      paperTradeIds: [],
      liveTradeIds: [],
    );
  }

  factory SeasonalStrategyUserSettings.fromJson(Map<String, dynamic> json) {
    Map<int, double> parseAllocations(String key) {
        Map<int, double> result = {};
        if (json[key] != null) {
          (json[key] as Map<String, dynamic>).forEach((k, v) {
            result[int.parse(k)] = (v as num).toDouble();
          });
        }
        return result;
    }

    // Try new fields
    var paperAlloc = parseAllocations('customAllocationsPaper');
    var liveAlloc = parseAllocations('customAllocationsLive');

    // Fallback to legacy field if new ones are empty but legacy exists
    if (paperAlloc.isEmpty && liveAlloc.isEmpty && json['customAllocations'] != null) {
        final legacy = parseAllocations('customAllocations');
        paperAlloc = Map.from(legacy);
        liveAlloc = Map.from(legacy);
    }

    List<String> parseThread(String key) {
      return (json[key] as List?)?.map((e) => e.toString()).toList() ?? [];
    }

    return SeasonalStrategyUserSettings(
      id: json['id'],
      userId: json['userId'],
      accountId: json['accountId'],
      allocationMode: json['allocationMode'] ?? 'equal',
      customAllocationsPaper: paperAlloc,
      customAllocationsLive: liveAlloc,
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
      'allocationMode': allocationMode,
      'customAllocationsPaper': customAllocationsPaper.map((k, v) => MapEntry(k.toString(), v)),
      'customAllocationsLive': customAllocationsLive.map((k, v) => MapEntry(k.toString(), v)),
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
    String? allocationMode,
    Map<int, double>? customAllocationsPaper,
    Map<int, double>? customAllocationsLive,
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
      allocationMode: allocationMode ?? this.allocationMode,
      customAllocationsPaper: customAllocationsPaper ?? this.customAllocationsPaper,
      customAllocationsLive: customAllocationsLive ?? this.customAllocationsLive,
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
  
  double getEqualAllocation({required bool isPaper}) {
    int activeThreadsCount = 0;
    final activeTradeIds = isPaper ? paperTradeIds : liveTradeIds;

    for (int i = 1; i <= 10; i++) {
       List<String> threadTrades = [];
       switch(i) {
         case 1: threadTrades = thread1; break;
         case 2: threadTrades = thread2; break;
         case 3: threadTrades = thread3; break;
         case 4: threadTrades = thread4; break;
         case 5: threadTrades = thread5; break;
         case 6: threadTrades = thread6; break;
         case 7: threadTrades = thread7; break;
         case 8: threadTrades = thread8; break;
         case 9: threadTrades = thread9; break;
         case 10: threadTrades = thread10; break;
       }
       
       if (threadTrades.any((id) => activeTradeIds.contains(id))) {
         activeThreadsCount++;
       }
    }
    
    if (activeThreadsCount == 0) return 0.0;
    return 100.0 / activeThreadsCount;
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

  SeasonalStrategyUserSettings subscribe(String tradeId) {
    final cleanId = tradeId.trim();
    // Add to paperTradeIds and thread1
    var newPaperIds = List<String>.from(paperTradeIds);
    if (!newPaperIds.contains(cleanId)) {
      newPaperIds.add(cleanId);
    }
    
    var newThread1 = List<String>.from(thread1);
    if (!newThread1.contains(cleanId)) {
      newThread1.add(cleanId);
    }

    return copyWith(
      paperTradeIds: newPaperIds,
      thread1: newThread1,
    );
  }

  SeasonalStrategyUserSettings unsubscribe(String tradeId) {
    final cleanId = tradeId.trim();

    // Remove from execution lists
    var newPaperIds = paperTradeIds.where((id) => id != cleanId).toList();
    var newLiveIds = liveTradeIds.where((id) => id != cleanId).toList();

    // Remove from all threads
    List<String> removeFrom(List<String> source) {
      return source.where((id) => id.trim() != cleanId).toList();
    }

    return copyWith(
      paperTradeIds: newPaperIds,
      liveTradeIds: newLiveIds,
      thread1: removeFrom(thread1),
      thread2: removeFrom(thread2),
      thread3: removeFrom(thread3),
      thread4: removeFrom(thread4),
      thread5: removeFrom(thread5),
      thread6: removeFrom(thread6),
      thread7: removeFrom(thread7),
      thread8: removeFrom(thread8),
      thread9: removeFrom(thread9),
      thread10: removeFrom(thread10),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is SeasonalStrategyUserSettings &&
      other.id == id &&
      other.userId == userId &&
      other.accountId == accountId &&
      other.allocationMode == allocationMode &&
      mapEquals(other.customAllocationsPaper, customAllocationsPaper) &&
      mapEquals(other.customAllocationsLive, customAllocationsLive) &&
      listEquals(other.paperTradeIds, paperTradeIds) &&
      listEquals(other.liveTradeIds, liveTradeIds) &&
      listEquals(other.thread1, thread1) &&
      listEquals(other.thread2, thread2) &&
      listEquals(other.thread3, thread3) &&
      listEquals(other.thread4, thread4) &&
      listEquals(other.thread5, thread5) &&
      listEquals(other.thread6, thread6) &&
      listEquals(other.thread7, thread7) &&
      listEquals(other.thread8, thread8) &&
      listEquals(other.thread9, thread9) &&
      listEquals(other.thread10, thread10);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      accountId,
      allocationMode,
      Object.hashAll(customAllocationsPaper.keys),
      Object.hashAll(customAllocationsLive.keys),
      Object.hashAll(paperTradeIds),
      Object.hashAll(liveTradeIds),
      Object.hashAll([
        thread1, thread2, thread3, thread4, thread5,
        thread6, thread7, thread8, thread9, thread10
      ]),
    );
  }
  
  @override
  String toString() {
    return 'SeasonalStrategyUserSettings(id: $id, userId: $userId, paperTrades: ${paperTradeIds.length}, liveTrades: ${liveTradeIds.length})';
  }
}

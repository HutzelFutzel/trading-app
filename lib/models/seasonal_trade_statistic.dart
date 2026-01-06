import 'dart:math';

class SeasonalTradeSingleStatistic {
  final String id;
  final String tradeId;
  final int year;
  final String entryDate;
  final String exitDate;
  final double entryPrice;
  final double exitPrice;
  final double profitPercentage;
  final double maxDrawdownPercentage;
  final double maxRunUpPercentage;
  final bool isWin;
  final int durationDays;
  final List<DailyClose>? dailyCloses;

  SeasonalTradeSingleStatistic({
    required this.id,
    required this.tradeId,
    required this.year,
    required this.entryDate,
    required this.exitDate,
    required this.entryPrice,
    required this.exitPrice,
    required this.profitPercentage,
    required this.maxDrawdownPercentage,
    required this.maxRunUpPercentage,
    required this.isWin,
    required this.durationDays,
    this.dailyCloses,
  });

  factory SeasonalTradeSingleStatistic.fromJson(Map<String, dynamic> json) {
    return SeasonalTradeSingleStatistic(
      id: json['id'] as String,
      tradeId: json['tradeId'] as String,
      year: json['year'] as int,
      entryDate: json['entryDate'] as String,
      exitDate: json['exitDate'] as String,
      entryPrice: (json['entryPrice'] as num).toDouble(),
      exitPrice: (json['exitPrice'] as num).toDouble(),
      profitPercentage: (json['profitPercentage'] as num).toDouble(),
      maxDrawdownPercentage: (json['maxDrawdownPercentage'] as num).toDouble(),
      maxRunUpPercentage: (json['maxRunUpPercentage'] as num).toDouble(),
      isWin: json['isWin'] as bool,
      durationDays: json['durationDays'] as int,
      dailyCloses: (json['dailyCloses'] as List<dynamic>?)
          ?.map((e) => DailyClose.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tradeId': tradeId,
      'year': year,
      'entryDate': entryDate,
      'exitDate': exitDate,
      'entryPrice': entryPrice,
      'exitPrice': exitPrice,
      'profitPercentage': profitPercentage,
      'maxDrawdownPercentage': maxDrawdownPercentage,
      'maxRunUpPercentage': maxRunUpPercentage,
      'isWin': isWin,
      'durationDays': durationDays,
      if (dailyCloses != null)
        'dailyCloses': dailyCloses!.map((e) => e.toJson()).toList(),
    };
  }
}

class DailyClose {
  final String date;
  final double price;

  DailyClose({required this.date, required this.price});

  factory DailyClose.fromJson(Map<String, dynamic> json) {
    return DailyClose(
      date: json['date'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'price': price,
    };
  }
}

class YearPerformance {
  final int year;
  final double profitPercentage;

  YearPerformance({required this.year, required this.profitPercentage});

  factory YearPerformance.fromJson(Map<String, dynamic> json) {
    return YearPerformance(
      year: json['year'] as int,
      profitPercentage: (json['profitPercentage'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'profitPercentage': profitPercentage,
    };
  }
}

class SeasonalTradeAggregateStatistic {
  final double averageProfitPercentage;
  final double medianProfitPercentage; // Added
  final double annualizedProfit; // Added (CAGR)
  final double winRate;
  final int totalTrades;
  final double averageMaxDrawdown;
  final double averageMaxRunUp;
  final YearPerformance bestYear;
  final YearPerformance worstYear;
  final double profitFactor;
  final double? standardDeviation;
  final double? cumulativeReturn;

  SeasonalTradeAggregateStatistic({
    required this.averageProfitPercentage,
    required this.medianProfitPercentage,
    required this.annualizedProfit,
    required this.winRate,
    required this.totalTrades,
    required this.averageMaxDrawdown,
    required this.averageMaxRunUp,
    required this.bestYear,
    required this.worstYear,
    required this.profitFactor,
    this.standardDeviation,
    this.cumulativeReturn,
  });

  /// Calculates aggregate statistics from a list of single year statistics.
  /// No extra information needed.
  static SeasonalTradeAggregateStatistic fromSingleStats(
      List<SeasonalTradeSingleStatistic> stats) {
    if (stats.isEmpty) {
      return SeasonalTradeAggregateStatistic(
        averageProfitPercentage: 0,
        medianProfitPercentage: 0,
        annualizedProfit: 0,
        winRate: 0,
        totalTrades: 0,
        averageMaxDrawdown: 0,
        averageMaxRunUp: 0,
        bestYear: YearPerformance(year: 0, profitPercentage: 0),
        worstYear: YearPerformance(year: 0, profitPercentage: 0),
        profitFactor: 0,
        standardDeviation: 0,
        cumulativeReturn: 0,
      );
    }

    double totalProfit = 0;
    double totalMaxDrawdown = 0;
    double totalMaxRunUp = 0;
    int winCount = 0;
    double grossProfit = 0;
    double grossLoss = 0;

    SeasonalTradeSingleStatistic? best;
    SeasonalTradeSingleStatistic? worst;

    // For Standard Deviation and Median
    List<double> returns = [];
    int minYear = 9999;
    int maxYear = 0;

    // For Cumulative Return (Simple compounding approximation: (1 + r1) * (1 + r2) ... - 1)
    double compoundedValue = 1.0;
    
    int totalDurationDays = 0;

    for (var stat in stats) {
      totalProfit += stat.profitPercentage;
      totalDurationDays += stat.durationDays;
      totalMaxDrawdown += stat.maxDrawdownPercentage;
      totalMaxRunUp += stat.maxRunUpPercentage;
      returns.add(stat.profitPercentage);
      
      if (stat.year < minYear) minYear = stat.year;
      if (stat.year > maxYear) maxYear = stat.year;

      if (stat.isWin) {
        winCount++;
        grossProfit += stat.profitPercentage;
      } else {
        // Gross loss is usually positive magnitude
        grossLoss += stat.profitPercentage.abs();
      }

      // Best Year
      if (best == null || stat.profitPercentage > best.profitPercentage) {
        best = stat;
      }

      // Worst Year
      if (worst == null || stat.profitPercentage < worst.profitPercentage) {
        worst = stat;
      }

      // Cumulative
      compoundedValue *= (1 + (stat.profitPercentage / 100));
    }

    double averageProfit = totalProfit / stats.length;
    double winRate = (winCount / stats.length) * 100;
    double averageMaxDrawdown = totalMaxDrawdown / stats.length;
    double averageMaxRunUp = totalMaxRunUp / stats.length;

    double profitFactor = grossLoss == 0
        ? (grossProfit > 0 ? double.infinity : 0)
        : grossProfit / grossLoss;
    
    // Median Calculation
    returns.sort();
    double medianProfit;
    if (returns.isEmpty) {
      medianProfit = 0;
    } else {
      int middle = returns.length ~/ 2;
      if (returns.length % 2 == 1) {
        medianProfit = returns[middle];
      } else {
        medianProfit = (returns[middle - 1] + returns[middle]) / 2.0;
      }
    }

    // Standard Deviation Calculation
    double variance = 0;
    for (var r in returns) {
      variance += pow(r - averageProfit, 2);
    }
    double stdDev = stats.length > 1 ? sqrt(variance / (stats.length - 1)) : 0.0;
    
    // Annualized Profit (Based on Average Profit extended to 365 days)
    // CAGR based on average profit and average duration: (1 + avg%) ^ (365 / avgDur) - 1
    double annualizedProfitPct = 0;
    if (stats.isNotEmpty && totalDurationDays > 0) {
      double averageDuration = totalDurationDays / stats.length;
      if (averageProfit > -100) {
         annualizedProfitPct = (pow(1 + (averageProfit / 100.0), 365 / averageDuration) - 1) * 100;
      } else {
         annualizedProfitPct = -100;
      }
    }
    
    double cumulativeReturnPct = (compoundedValue - 1) * 100;

    return SeasonalTradeAggregateStatistic(
      averageProfitPercentage: averageProfit,
      medianProfitPercentage: medianProfit,
      annualizedProfit: annualizedProfitPct,
      winRate: winRate,
      totalTrades: stats.length,
      averageMaxDrawdown: averageMaxDrawdown,
      averageMaxRunUp: averageMaxRunUp,
      bestYear: YearPerformance(
        year: best?.year ?? 0,
        profitPercentage: best?.profitPercentage ?? 0,
      ),
      worstYear: YearPerformance(
        year: worst?.year ?? 0,
        profitPercentage: worst?.profitPercentage ?? 0,
      ),
      profitFactor: profitFactor,
      standardDeviation: stdDev,
      cumulativeReturn: cumulativeReturnPct,
    );
  }

  factory SeasonalTradeAggregateStatistic.fromJson(Map<String, dynamic> json) {
    return SeasonalTradeAggregateStatistic(
      averageProfitPercentage:
          (json['averageProfitPercentage'] as num).toDouble(),
      medianProfitPercentage:
          (json['medianProfitPercentage'] as num?)?.toDouble() ?? 0.0,
      annualizedProfit:
          (json['annualizedProfit'] as num?)?.toDouble() ?? 0.0,
      winRate: (json['winRate'] as num).toDouble(),
      totalTrades: json['totalTrades'] as int,
      averageMaxDrawdown: (json['averageMaxDrawdown'] as num).toDouble(),
      averageMaxRunUp: (json['averageMaxRunUp'] as num).toDouble(),
      bestYear:
          YearPerformance.fromJson(json['bestYear'] as Map<String, dynamic>),
      worstYear:
          YearPerformance.fromJson(json['worstYear'] as Map<String, dynamic>),
      profitFactor: (json['profitFactor'] as num).toDouble(),
      standardDeviation: (json['standardDeviation'] as num?)?.toDouble(),
      cumulativeReturn: (json['cumulativeReturn'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageProfitPercentage': averageProfitPercentage,
      'medianProfitPercentage': medianProfitPercentage,
      'annualizedProfit': annualizedProfit,
      'winRate': winRate,
      'totalTrades': totalTrades,
      'averageMaxDrawdown': averageMaxDrawdown,
      'averageMaxRunUp': averageMaxRunUp,
      'bestYear': bestYear.toJson(),
      'worstYear': worstYear.toJson(),
      'profitFactor': profitFactor,
      'standardDeviation': standardDeviation,
      'cumulativeReturn': cumulativeReturn,
    };
  }
}

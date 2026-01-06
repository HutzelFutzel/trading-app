import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/account_data.dart';
import '../common/glass_container.dart';

class SummaryView extends StatelessWidget {
  final Account? account;
  final List<Position> positions;
  final List<Order> recentOrders;
  final String accountType;
  final Function(Order)? onCancelOrder;

  const SummaryView({
    super.key,
    required this.account,
    this.positions = const [],
    this.recentOrders = const [],
    required this.accountType,
    this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    if (account == null) return const SizedBox.shrink();

    // Added bottom padding to account for floating nav bar
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEquityCard(context),
          const SizedBox(height: 24),
          if (positions.isNotEmpty) ...[
            _buildSectionTitle('Top Positions'),
            const SizedBox(height: 12),
            _buildPositionsList(context),
            const SizedBox(height: 24),
          ],
          if (recentOrders.isNotEmpty) ...[
            _buildSectionTitle('Recent Activity'),
            const SizedBox(height: 12),
            _buildRecentActivityList(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.headlineLarge,
    );
  }

  Widget _buildEquityCard(BuildContext context) {
    // Calculate additional stats
    final moneyInPositions = account!.portfolioValue - account!.cash;
    final activePositionsCount = positions.length;
    // Count open orders from recentOrders (assuming it contains relevant orders, or filter appropriately if needed)
    // The query implies "current amount of open orders". We can filter recentOrders or assume the caller passed open orders.
    // Based on AccountScreen logic, recentOrders is a mix of open orders and trades.
    // Let's count orders that are not filled/cancelled/rejected/expired.
    final openOrdersCount = recentOrders.where((o) => 
      ['new', 'accepted', 'pending_new', 'accepted_for_bidding', 'stopped', 'calculated', 'suspended', 'partially_filled'].contains(o.status.toLowerCase())
    ).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Equity
          Text(
            'Total Equity',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.simpleCurrency().format(account!.equity),
            style: AppTextStyles.displayLarge.copyWith(color: Colors.white),
          ),
          
          const SizedBox(height: 24),
          
          // Grid of stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEquityStat('Cash', account!.cash),
                    const SizedBox(height: 16),
                    _buildEquityStat('Positions Value', moneyInPositions),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCountStat('Active Positions', activePositionsCount),
                    const SizedBox(height: 16),
                    _buildCountStat('Open Orders', openOrdersCount),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountStat(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: AppTextStyles.headlineLarge.copyWith(color: Colors.white, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildEquityStat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          NumberFormat.simpleCurrency(decimalDigits: 0).format(value),
          style: AppTextStyles.headlineLarge.copyWith(color: Colors.white, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildPositionsList(BuildContext context) {
    // Show top 3 positions horizontal scroll
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: positions.length > 5 ? 5 : positions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final pos = positions[index];
          final isProfit = pos.unrealizedPl >= 0;
          return GlassContainer(
            width: 180,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(pos.symbol, style: AppTextStyles.headlineLarge.copyWith(fontSize: 16)),
                    Icon(
                      isProfit ? Icons.trending_up : Icons.trending_down,
                      color: isProfit ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pos.qty} Shares',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.simpleCurrency().format(pos.marketValue),
                      style: AppTextStyles.monoLarge.copyWith(fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isProfit ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${isProfit ? '+' : ''}${NumberFormat.simpleCurrency(decimalDigits: 2).format(pos.unrealizedPl)}',
                    style: TextStyle(
                      color: isProfit ? AppColors.success : AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivityList(BuildContext context) {
    return Column(
      children: recentOrders.map((order) {
        final isBuy = order.side == 'buy';
        final isCancellable = ['new', 'accepted', 'pending_new', 'accepted_for_bidding', 'stopped', 'calculated', 'suspended'].contains(order.status.toLowerCase());

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isBuy ? AppColors.primary : AppColors.warning).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBuy ? Icons.shopping_bag_outlined : Icons.sell_outlined,
                    color: isBuy ? AppColors.primary : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.symbol,
                        style: AppTextStyles.headlineLarge.copyWith(fontSize: 16),
                      ),
                      Text(
                        '${order.qty} Shares @ ${order.type.toUpperCase()}',
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: order.status == 'filled' ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, HH:mm').format(order.createdAt),
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 10),
                    ),
                    if (isCancellable && onCancelOrder != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          onTap: () => onCancelOrder!(order),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

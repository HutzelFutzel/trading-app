import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/account_data.dart';
import '../common/glass_container.dart';

class PortfolioView extends StatelessWidget {
  final List<Position> positions;
  final Function(Position)? onClosePosition;

  const PortfolioView({
    super.key,
    required this.positions,
    this.onClosePosition,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildInfoBox(),
        ),
        Expanded(
          child: positions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('No active positions', style: AppTextStyles.bodyLarge),
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: positions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final pos = positions[index];
                    final isProfit = pos.unrealizedPl >= 0;

                    return GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pos.symbol,
                                style: AppTextStyles.headlineLarge
                                    .copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pos.qty} shares @ \$${pos.avgEntryPrice.toStringAsFixed(2)}',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${pos.marketValue.toStringAsFixed(2)}',
                                style: AppTextStyles.monoLarge,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    isProfit
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 14,
                                    color: isProfit
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${isProfit ? '+' : ''}\$${pos.unrealizedPl.toStringAsFixed(2)} (${(pos.unrealizedPlpc * 100).toStringAsFixed(2)}%)',
                                    style: AppTextStyles.monoMedium.copyWith(
                                      color: isProfit
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (onClosePosition != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: InkWell(
                                    onTap: () => onClosePosition!(pos),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color:
                                                AppColors.error.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'CLOSE',
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
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Portfolio is managed automatically by the system. Manual intervention is only possible to close positions.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

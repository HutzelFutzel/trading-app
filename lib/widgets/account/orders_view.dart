import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/account_data.dart';
import 'package:intl/intl.dart';
import '../common/glass_container.dart';

class OrdersView extends StatelessWidget {
  final List<Order> orders;
  final Function(Order)? onCancelOrder;

  const OrdersView({super.key, required this.orders, this.onCancelOrder});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text('No orders found', style: AppTextStyles.bodyLarge),
      ));
    }

    // Added bottom padding for floating nav bar
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isBuy = order.side == 'buy';
        final isCancellable = ['new', 'accepted', 'pending_new', 'accepted_for_bidding', 'stopped', 'calculated', 'suspended'].contains(order.status.toLowerCase());
        
        return GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isBuy ? AppColors.primary : AppColors.warning).withOpacity(0.1),
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
                      style: AppTextStyles.headlineLarge.copyWith(fontSize: 18),
                    ),
                    Text(
                      '${order.qty} Shares @ ${order.type.toUpperCase()}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getStatusColor(order.status).withOpacity(0.3)),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, HH:mm').format(order.createdAt),
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 10),
                  ),
                  if (isCancellable && onCancelOrder != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: () => onCancelOrder!(order),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
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
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'filled': return AppColors.success;
      case 'new': return AppColors.primary;
      case 'cancelled': return AppColors.textDisabled;
      case 'rejected': return AppColors.error;
      default: return AppColors.warning;
    }
  }
}

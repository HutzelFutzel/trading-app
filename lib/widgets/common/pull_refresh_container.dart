import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_snackbar.dart';

class PullRefreshContainer extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? successMessage;

  const PullRefreshContainer({
    super.key,
    required this.child,
    required this.onRefresh,
    this.successMessage = "Refreshed",
  });

  Future<void> _handleRefresh(BuildContext context) async {
    await onRefresh();
    if (context.mounted && successMessage != null) {
      ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing to avoid stacking
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(message: successMessage!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _handleRefresh(context),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      displacement: 40,
      edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight, 
      child: child,
    );
  }
}


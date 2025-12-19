import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StepByStepGuide extends StatelessWidget {
  const StepByStepGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'How to Get Alpaca API Keys',
                style: AppTextStyles.headlineLarge.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStep(
            number: 1,
            title: 'Create an Alpaca Account',
            description: 'Visit alpaca.markets and sign up for a free account. You will need to verify your email address.',
          ),
          _buildStep(
            number: 2,
            title: 'Choose Environment (Paper vs Live)',
            description: 'On the Alpaca dashboard, look for the "Paper / Live" toggle (usually in the top-right corner or sidebar).\n\n• Paper Trading: Simulated money for testing strategies safely.\n• Live Trading: Real money. Requires identity verification and funding.',
          ),
          _buildStep(
            number: 3,
            title: 'Locate API Keys Section',
            description: 'In the right sidebar of your dashboard, find the "API Keys" box. If you don\'t see it, ensure you are on the "Overview" page.',
          ),
          _buildStep(
            number: 4,
            title: 'Generate Your Keys',
            description: 'Click "Generate New Key" (or "Regenerate Key").\n\nNote: For Live accounts, you must complete the onboarding process before generating keys.',
          ),
          _buildStep(
            number: 5,
            title: 'Save Your Credentials',
            description: 'Important! The "Secret Key" is shown only once. Copy both the "API Key ID" and "Secret Key" and store them securely.',
          ),
          _buildStep(
            number: 6,
            title: 'Connect to App',
            description: 'Copy the keys into the fields above. Make sure to match Paper keys with the Paper Trading section and Live keys with the Live Trading section.',
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
            ),
            child: Text(
              number.toString(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

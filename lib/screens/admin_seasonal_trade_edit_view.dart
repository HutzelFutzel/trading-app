import 'package:flutter/material.dart';
import '../models/seasonal_trade.dart';
import '../models/seasonal_strategy_user_settings.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class AdminSeasonalTradeEditView extends StatefulWidget {
  final SeasonalTrade trade;
  final SeasonalStrategyUserSettings userSettings;

  const AdminSeasonalTradeEditView({
    super.key, 
    required this.trade,
    required this.userSettings,
  });

  @override
  State<AdminSeasonalTradeEditView> createState() => _AdminSeasonalTradeEditViewState();
}

class _AdminSeasonalTradeEditViewState extends State<AdminSeasonalTradeEditView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _symbolController;
  late ApiService _apiService;
  
  String _direction = 'Long';
  bool _isSaving = false;

  // Date State
  int _openMonth = 1;
  int _openDay = 1;
  int _closeMonth = 1;
  int _closeDay = 1;

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    _symbolController = TextEditingController(text: widget.trade.symbol);
    _direction = widget.trade.direction;
    
    _parseDate(widget.trade.openDate, (m, d) {
      _openMonth = m;
      _openDay = d;
    });
    _parseDate(widget.trade.closeDate, (m, d) {
      _closeMonth = m;
      _closeDay = d;
    });
  }

  void _parseDate(String date, Function(int, int) onParsed) {
    try {
      final parts = date.split('-');
      if (parts.length == 2) {
        onParsed(int.parse(parts[0]), int.parse(parts[1]));
      }
    } catch (_) {}
  }

  String _formatDate(int month, int day) {
    return '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // 1. Update Trade
      final updatedTrade = SeasonalTrade(
        id: widget.trade.id,
        symbol: _symbolController.text,
        openDate: _formatDate(_openMonth, _openDay),
        closeDate: _formatDate(_closeMonth, _closeDay),
        direction: _direction,
        verifiedByApi: widget.trade.verifiedByApi,
        symbolExists: widget.trade.symbolExists,
        tradeDirectionPossible: widget.trade.tradeDirectionPossible,
        name: widget.trade.name,
      );

      await _apiService.updateSeasonalTrade(widget.trade.id!, updatedTrade);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Seasonal Trade', style: AppTextStyles.headlineLarge),
        backgroundColor: AppColors.background,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withValues(alpha: 0.05),
            height: 1,
          ),
        ),
        actions: [
           if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // ASSET & DIRECTION
                _buildSectionHeader('Asset Configuration'),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _symbolController,
                        style: AppTextStyles.headlineLarge.copyWith(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Symbol',
                          labelStyle: AppTextStyles.bodyMedium,
                          hintText: 'e.g. AAPL',
                          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.surfaceHighlight.withValues(alpha: 0.3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 56, // Match text field height
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHighlight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildDirectionBtn('Long', Icons.arrow_upward, AppColors.long),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildDirectionBtn('Short', Icons.arrow_downward, AppColors.short),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // SEASONALITY
                _buildSectionHeader('Seasonality Window'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildDateRow('Open', Icons.calendar_today, _openMonth, _openDay, (m) => _openMonth = m, (d) => _openDay = d),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const SizedBox(width: 24), // Offset for icon
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.05))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: const Icon(Icons.arrow_downward, size: 16, color: AppColors.textSecondary),
                            ),
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.05))),
                          ],
                        ),
                      ),
                      _buildDateRow('Close', Icons.event_available, _closeMonth, _closeDay, (m) => _closeMonth = m, (d) => _closeDay = d),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.save_outlined),
                      SizedBox(width: 8),
                      Text('Save Changes'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDirectionBtn(String label, IconData icon, Color color) {
    final isSelected = _direction == label;
    return InkWell(
      onTap: () => setState(() => _direction = label),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(
              label, 
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textSecondary
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(
    String label, 
    IconData icon,
    int currentMonth, 
    int currentDay, 
    Function(int) onMonthChanged, 
    Function(int) onDayChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // Let container show
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.headlineLarge.copyWith(fontSize: 14)),
          const Spacer(),
          // Month Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: currentMonth,
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              items: List.generate(12, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(_months[index]),
                );
              }),
              onChanged: (val) => setState(() => onMonthChanged(val!)),
            ),
          ),
          const SizedBox(width: 8),
          // Day Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: currentDay,
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              items: List.generate(31, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                );
              }),
              onChanged: (val) => setState(() => onDayChanged(val!)),
            ),
          ),
        ],
      ),
    );
  }
}

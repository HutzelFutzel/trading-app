import 'package:flutter/material.dart';
import '../models/seasonal_strategy_settings.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class AdminSeasonalStrategySettingsView extends StatefulWidget {
  const AdminSeasonalStrategySettingsView({super.key});

  @override
  State<AdminSeasonalStrategySettingsView> createState() => _AdminSeasonalStrategySettingsViewState();
}

class _AdminSeasonalStrategySettingsViewState extends State<AdminSeasonalStrategySettingsView> {
  final ApiService _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  SeasonalStrategySettings? _globalRules;

  // Order Rules State
  late String _openOrderType;
  late String _openOrderTIF;
  late String _closeOrderType;
  late String _closeOrderTIF;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final rules = await _apiService.getSeasonalTradeRules();
      
      if (mounted) {
        setState(() {
          _globalRules = rules;
          _openOrderType = rules.openOrderType;
          _openOrderTIF = rules.openOrderTIF;
          _closeOrderType = rules.closeOrderType;
          _closeOrderTIF = rules.closeOrderTIF;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load settings: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveGlobalRules(SeasonalStrategySettings newRules) async {
    setState(() => _isSaving = true);
    try {
      await _apiService.saveSeasonalTradeRules(newRules);
      if (mounted) {
        setState(() {
          _globalRules = newRules;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving globals: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Strategy Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Strategy Settings')),
        body: Center(child: Text(_error!, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Admin Strategy Settings', style: AppTextStyles.headlineLarge),
        backgroundColor: AppColors.background,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            height: 1,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlobalRulesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalRulesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GLOBAL ORDER RULES',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildOrderColumn(
                  'Entry Orders', 
                  _openOrderType, 
                  _openOrderTIF, 
                  (t, tif) {
                     setState(() { _openOrderType = t; _openOrderTIF = tif; });
                     _saveGlobalRules(_globalRules!.copyWith(openOrderType: t, openOrderTIF: tif));
                  }
                )
              ),
              Container(width: 1, height: 100, color: Colors.white.withOpacity(0.05), margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(
                child: _buildOrderColumn(
                  'Exit Orders', 
                  _closeOrderType, 
                  _closeOrderTIF, 
                  (t, tif) {
                     setState(() { _closeOrderType = t; _closeOrderTIF = tif; });
                     _saveGlobalRules(_globalRules!.copyWith(closeOrderType: t, closeOrderTIF: tif));
                  }
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderColumn(String title, String type, String tif, Function(String, String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineLarge.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        _buildDropdown('Order Type', type, ['market', 'limit'], (v) => onChanged(v, tif)),
        const SizedBox(height: 12),
        _buildDropdown('Time in Force', tif, ['day', 'gtc'], (v) => onChanged(type, v)),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: AppColors.surface,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
            filled: true,
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
          onChanged: (v) { if(v!=null) onChanged(v); },
        ),
      ],
    );
  }
}

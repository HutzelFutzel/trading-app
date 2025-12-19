import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/step_by_step_guide.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/app_snackbar.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late ApiService _apiService;
  bool _isLoading = true;
  String? _error;
  User? _settings;
  bool _isSaving = false;
  String? _paperVerificationError;
  String? _liveVerificationError;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      setState(() => _isLoading = true);
      final settings = await _apiService.getUser();
      if (mounted) {
        setState(() {
          _settings = settings;
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

  Future<void> _saveSettings(User updated, {bool showSuccess = false}) async {
    setState(() => _isSaving = true);
    try {
      final savedSettings = await _apiService.saveUser(updated);
      setState(() {
        _settings = savedSettings;
        _isSaving = false;
      });
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(
            message: 'Settings saved',
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      String message = 'Error saving: $e';
      if (e is UserSaveException) {
         message = e.message;
         if (e.updatedUser != null && mounted) {
            setState(() {
               _settings = e.updatedUser;
            });
         }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(
            message: message,
            icon: Icons.error_outline,
            iconColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _retryVerification(String accountId, bool isPaper) async {
    setState(() => _isSaving = true);
    // Reset specific error before retry
    if (isPaper) setState(() => _paperVerificationError = null);
    else setState(() => _liveVerificationError = null);

    try {
      final result = await _apiService.verifyAlpacaAccount(accountId);
      final bool verified = result['verified'] == true;
      final String? message = result['message'];
      final String? accountNumber = result['accountNumber'];
      final String? error = result['error'];
      
      if (mounted) {
        if (verified) {
           // Update local state
           User? updatedUser;
           if (isPaper && _settings?.alpacaPaperAccount != null) {
              updatedUser = _settings!.copyWith(
                alpacaPaperAccount: _settings!.alpacaPaperAccount!.copyWith(verified: true)
              );
           } else if (!isPaper && _settings?.alpacaLiveAccount != null) {
              updatedUser = _settings!.copyWith(
                alpacaLiveAccount: _settings!.alpacaLiveAccount!.copyWith(verified: true)
              );
           }

           if (updatedUser != null) {
             setState(() {
               _settings = updatedUser;
             });
           }
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'Account verified successfully')));
        } else {
           // Mark as unverified
           User? updatedUser;
           if (isPaper && _settings?.alpacaPaperAccount != null) {
              updatedUser = _settings!.copyWith(
                alpacaPaperAccount: _settings!.alpacaPaperAccount!.copyWith(verified: false)
              );
              setState(() => _paperVerificationError = error ?? message);
           } else if (!isPaper && _settings?.alpacaLiveAccount != null) {
              updatedUser = _settings!.copyWith(
                alpacaLiveAccount: _settings!.alpacaLiveAccount!.copyWith(verified: false)
              );
              setState(() => _liveVerificationError = error ?? message);
           }
           
           if (updatedUser != null) {
             setState(() {
               _settings = updatedUser;
             });
           }
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text(message ?? 'Verification failed. Check credentials.'),
             backgroundColor: Colors.red,
           ));
        }
      }
    } catch (e) {
       if (isPaper) setState(() => _paperVerificationError = e.toString());
       else setState(() => _liveVerificationError = e.toString());
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
       }
    } finally {
        if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updatePaperAccount(AlpacaAccount account) {
    if (_settings == null) return;
    _saveSettings(_settings!.copyWith(alpacaPaperAccount: account));
  }

  void _updateLiveAccount(AlpacaAccount account) {
    if (_settings == null) return;
    _saveSettings(_settings!.copyWith(alpacaLiveAccount: account));
  }

  // Helper to ensure accounts exist with IDs
  void _ensureAccountsExist() {
     if (_settings == null) return;
     bool changed = false;
     User temp = _settings!;

     if (temp.alpacaPaperAccount == null) {
        temp = temp.copyWith(
          alpacaPaperAccount: AlpacaAccount(
            id: const Uuid().v4(), 
            apiKey: '', 
            apiSecret: '',
            enabled: true
          )
        );
        changed = true;
     }

     if (temp.alpacaLiveAccount == null) {
        temp = temp.copyWith(
          alpacaLiveAccount: AlpacaAccount(
            id: const Uuid().v4(), 
            apiKey: '', 
            apiSecret: '',
            enabled: false // Default live to disabled for safety
          )
        );
        changed = true;
     }

     if (changed) {
       _settings = temp;
       // We don't save immediately to server to avoid empty writes, 
       // but we update local state so UI renders the forms.
       // Or we could save empty shells. Let's save.
       _saveSettings(temp); 
     }
  }

  // Logout function removed as it moved to menu
  
  @override
  Widget build(BuildContext context) {
    // If settings loaded but accounts missing, create them
    if (!_isLoading && _settings != null && (_settings!.alpacaPaperAccount == null || _settings!.alpacaLiveAccount == null)) {
       // Defer to next frame to avoid build error
       WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAccountsExist());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Account', style: AppTextStyles.headlineLarge),
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
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!, style: AppTextStyles.bodyLarge))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_settings?.alpacaPaperAccount != null)
                  _AccountCard(
                    title: 'Paper Trading',
                    account: _settings!.alpacaPaperAccount!,
                    isPaper: true,
                    onUpdate: _updatePaperAccount,
                    onRetryVerification: () => _retryVerification(_settings!.alpacaPaperAccount!.id, true),
                    verificationError: _paperVerificationError,
                  ),
                const SizedBox(height: 24),
                if (_settings?.alpacaLiveAccount != null)
                  _AccountCard(
                    title: 'Live Trading',
                    account: _settings!.alpacaLiveAccount!,
                    isPaper: false,
                    onUpdate: _updateLiveAccount,
                    onRetryVerification: () => _retryVerification(_settings!.alpacaLiveAccount!.id, false),
                    verificationError: _liveVerificationError,
                  ),
                
                const SizedBox(height: 40),
                Divider(color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 24),
                
                // Logout Button removed
                
                const SizedBox(height: 120),
              ],
            ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  final String title;
  final AlpacaAccount account;
  final bool isPaper;
  final Function(AlpacaAccount) onUpdate;
  final VoidCallback onRetryVerification;
  final String? verificationError;

  const _AccountCard({
    required this.title,
    required this.account, 
    required this.isPaper,
    required this.onUpdate, 
    required this.onRetryVerification,
    this.verificationError,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _expanded = false;
  late TextEditingController _keyCtrl;
  late TextEditingController _secretCtrl;
  late TextEditingController _utilizationCtrl;
  
  // Local state for immediate feedback
  late bool _allowShort;
  late bool _enabled;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.account.apiKey);
    _secretCtrl = TextEditingController(text: widget.account.apiSecret);
    _utilizationCtrl = TextEditingController(text: widget.account.maxUtilizationPercentage.toString());
    
    _allowShort = widget.account.allowShortTrading;
    _enabled = widget.account.enabled;

    _keyCtrl.addListener(_onFieldChanged);
    _secretCtrl.addListener(_onFieldChanged);
    _utilizationCtrl.addListener(_onFieldChanged);
  }
  
  @override
  void didUpdateWidget(_AccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
        // Temporarily remove listeners to avoid triggering save on external update
        _keyCtrl.removeListener(_onFieldChanged);
        _secretCtrl.removeListener(_onFieldChanged);
        _utilizationCtrl.removeListener(_onFieldChanged);

        if (_keyCtrl.text != widget.account.apiKey) _keyCtrl.text = widget.account.apiKey;
        if (_secretCtrl.text != widget.account.apiSecret) _secretCtrl.text = widget.account.apiSecret;
        
        // Only update utilization text if the numeric value is different enough (parsing issue check)
        final currentUtil = double.tryParse(_utilizationCtrl.text) ?? 0.0;
        if (currentUtil != widget.account.maxUtilizationPercentage) {
             _utilizationCtrl.text = widget.account.maxUtilizationPercentage.toString();
        }

        _allowShort = widget.account.allowShortTrading;
        _enabled = widget.account.enabled;

        // Add listeners back
        _keyCtrl.addListener(_onFieldChanged);
        _secretCtrl.addListener(_onFieldChanged);
        _utilizationCtrl.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keyCtrl.removeListener(_onFieldChanged);
    _secretCtrl.removeListener(_onFieldChanged);
    _utilizationCtrl.removeListener(_onFieldChanged);
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    _utilizationCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), _pushUpdate);
  }

  void _pushUpdate() {
    final utilization = double.tryParse(_utilizationCtrl.text) ?? 0.0;
    
    final updated = widget.account.copyWith(
      apiKey: _keyCtrl.text,
      apiSecret: _secretCtrl.text,
      maxUtilizationPercentage: utilization,
      allowShortTrading: _allowShort,
      enabled: _enabled,
    );
    widget.onUpdate(updated);
  }

  void _onSwitchChanged(bool val) {
    // For switches, we update local state and push update immediately 
    // (or with small debounce if desired, but usually immediate is expected)
    setState(() {
       // Just trigger update, local variable handled by UI
    });
    // However, if we don't update local vars, the UI won't switch until roundtrip. 
    // Our build method uses _enabled/_allowShort variables.
    // So we must update them.
    // Actually, let's update them in the specific callbacks.
    _pushUpdate();
  }

  void _showGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: const StepByStepGuide(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.account.apiKey.isNotEmpty;
    final primaryColor = widget.isPaper ? AppColors.accent : AppColors.error;
    final isVerified = widget.account.verified;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text(widget.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                if (isVerified && hasKey) ...[
                  const SizedBox(width: 12),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _enabled,
                      activeColor: primaryColor,
                      onChanged: (val) {
                        setState(() => _enabled = val);
                        _onSwitchChanged(val);
                      },
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Row(
              children: [
                if (hasKey) ...[
                   _buildBadge(isVerified ? 'VERIFIED' : 'UNVERIFIED', isVerified ? AppColors.success : AppColors.warning),
                   if (!isVerified) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 24,
                        child: OutlinedButton(
                          onPressed: widget.onRetryVerification, 
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
                            foregroundColor: AppColors.warning,
                          ),
                          child: const Text('Retry', style: TextStyle(fontSize: 10))
                        ),
                      )
                   ]
                ] else 
                   _buildBadge('NO KEYS', AppColors.textDisabled),
              ],
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.edit),
              color: AppColors.textSecondary,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // API Keys
                  Row(
                    children: [
                      Text('API Keys', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showGuide,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Icon(Icons.help_outline, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'How to get keys?',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _keyCtrl,
                    label: 'API Key ID',
                    style: AppTextStyles.monoMedium,
                    hint: 'Enter API Key',
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _secretCtrl,
                    label: 'Secret Key',
                    style: AppTextStyles.monoMedium,
                    hint: 'Enter Secret Key',
                    obscureText: true,
                  ),
                  
                  if (!hasKey) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please enter your API keys.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (!isVerified) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.verificationError ?? 'Account verification failed. Please check your keys.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                      // Only show settings if verified and keys present
                      const SizedBox(height: 24),
                      
                      // Configuration
                      Text('Trading Configuration', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // Short Trading
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Allow Short Trading', style: AppTextStyles.bodyMedium),
                          value: _allowShort,
                          activeColor: primaryColor,
                          onChanged: (val) {
                             setState(() => _allowShort = val);
                             _onSwitchChanged(val);
                          },
                       ),
                       
                       const SizedBox(height: 16),
                       
                       // Utilization
                       CustomTextField(
                         controller: _utilizationCtrl,
                         label: 'Max Portfolio Utilization',
                         style: AppTextStyles.monoMedium,
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                         suffixIcon: const Padding(
                           padding: EdgeInsets.all(14.0),
                           child: Text('%', style: TextStyle(color: AppColors.textSecondary)),
                         ),
                         hint: '100',
                       ),
                       const SizedBox(height: 8),
                       Text(
                          'Percentage of total equity to use for trading (can be > 100% for margin)',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDisabled),
                       ),
                  ],
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Text(
        text, 
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)
      ),
    );
  }
}

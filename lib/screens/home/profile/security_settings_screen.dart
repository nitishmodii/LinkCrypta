import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../services/auth_service.dart';
import '../../onboarding/pin_setup_screen.dart';
import '../../../utils/helpers.dart';
import '../../../utils/modern_colors.dart';


class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isPINSet = false;
  bool _isAuthEnabled = false;
  bool _isLoading = true;
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricAvailability();
  }
  
  Future<void> _checkBiometricAvailability() async {
    try {
      final bool canUseBiometrics = await AuthService.isBiometricAvailable();
      final List<BiometricType> availableBiometrics = 
          canUseBiometrics ? await AuthService.getAvailableBiometrics() : [];
      
      if (mounted) {
        setState(() {
          _isBiometricAvailable = canUseBiometrics;
          _availableBiometrics = availableBiometrics;
        });
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Failed to check biometric availability: ${e.toString()}',
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isPINSet = await AuthService.isPINSet();
      final isAuthEnabled = await AuthService.isAuthEnabled();

      if (mounted) {
        setState(() {
          _isPINSet = isPINSet;
          _isAuthEnabled = isAuthEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppHelpers.showSnackBar(
          context,
          'Failed to load settings: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _navigateToPINSetup() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PinSetupScreen(),
      ),
    );

    if (result == true) {
      _loadSettings();
    }
  }

  Future<void> _toggleAuthEnabled(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.setAuthEnabled(value);

      if (mounted) {
        setState(() {
          _isAuthEnabled = value;
          _isLoading = false;
        });
        AppHelpers.showSnackBar(
          context,
          value ? 'Authentication enabled' : 'Authentication disabled',
          backgroundColor: value ? ModernColors.success : ModernColors.error,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppHelpers.showSnackBar(
          context,
          'Failed to update settings: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernColors.white,
      appBar: AppBar(
        backgroundColor: ModernColors.white,
        elevation: 0,
        title: const Text(
          'Security Settings',
          style: TextStyle(
            color: ModernColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: ModernColors.textDark,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Security Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ModernColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: ModernColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: ModernColors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: ModernColors.textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage your security preferences',
                              style: TextStyle(
                                fontSize: 14,
                                color: ModernColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Biometric Info
                if (_isBiometricAvailable)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModernColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ModernColors.primaryBlue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              color: ModernColors.primaryBlue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Biometric Authentication',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ModernColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use your fingerprint or face recognition for faster and more secure access to your passwords.',
                          style: TextStyle(
                            fontSize: 14,
                            color: ModernColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // PIN Settings
                const Text(
                  'PIN Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ModernColors.textDark,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // PIN Setup/Change
                _buildSettingsItem(
                  context,
                  icon: Icons.pin_rounded,
                  title: _isPINSet ? 'Change PIN' : 'Set PIN',
                  subtitle: _isPINSet
                      ? 'Your PIN is currently set'
                      : 'Set a PIN to protect your passwords',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: ModernColors.textLight,
                  ),
                  onTap: _navigateToPINSetup,
                ),
                
                // Enable Authentication
                _buildSettingsItem(
                  context,
                  icon: Icons.lock_rounded,
                  title: 'Require Authentication',
                  subtitle: 'Require PIN or biometrics to access passwords',
                  trailing: Switch(
                    value: _isAuthEnabled,
                    onChanged: _isPINSet ? _toggleAuthEnabled : null,
                    activeColor: ModernColors.primaryBlue,
                  ),
                  onTap: () {
                    if (_isPINSet) {
                      _toggleAuthEnabled(!_isAuthEnabled);
                    } else {
                      AppHelpers.showSnackBar(
                        context,
                        'Please set a PIN first',
                        backgroundColor: Colors.orange,
                      );
                    }
                  },
                ),
                
                // Biometric Authentication
                if (_isBiometricAvailable && _isPINSet)
                  _buildSettingsItem(
                    context,
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric Authentication',
                    subtitle: _getBiometricSubtitle(),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: ModernColors.textLight,
                    ),
                    onTap: () {
                      _showBiometricDialog();
                    },
                  ),
                
                const SizedBox(height: 24),
                
                // Security Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ModernColors.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ModernColors.primaryBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: ModernColors.primaryBlue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Security Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ModernColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your passwords are encrypted using AES-256 encryption and stored securely on your device. Setting a PIN adds an additional layer of security.',
                        style: TextStyle(
                          fontSize: 14,
                          color: ModernColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _getBiometricSubtitle() {
    if (_availableBiometrics.isEmpty) {
      return 'No biometric methods available';
    }
    
    final List<String> methods = [];
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      methods.add('Fingerprint');
    }
    if (_availableBiometrics.contains(BiometricType.face)) {
      methods.add('Face Recognition');
    }
    if (_availableBiometrics.contains(BiometricType.iris)) {
      methods.add('Iris Scan');
    }
    if (_availableBiometrics.contains(BiometricType.strong)) {
      methods.add('Strong Biometrics');
    }
    if (_availableBiometrics.contains(BiometricType.weak)) {
      methods.add('Weak Biometrics');
    }
    
    return 'Available methods: ${methods.join(', ')}';
  }
  
  Future<void> _showBiometricDialog() async {
    final bool authenticated = await AuthService.authenticateWithBiometrics(
      'Authenticate to enable biometric login'
    );
    
    if (mounted) {
      if (authenticated) {
        AppHelpers.showSnackBar(
          context,
          'Biometric authentication successful',
          backgroundColor: ModernColors.success,
        );
      } else {
        AppHelpers.showSnackBar(
          context,
          'Biometric authentication failed',
          backgroundColor: ModernColors.error,
        );
      }
    }
  }
  
  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ModernColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ModernColors.lightGrey,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ModernColors.primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: ModernColors.primaryBlue,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: ModernColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: ModernColors.textLight,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
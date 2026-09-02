import 'package:flutter/material.dart';
import 'package:linkcrypta/utils/modern_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/onboarding_service.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/autofill_framework_service.dart';
import '../../../utils/helpers.dart';
import '../../../utils/responsive.dart';
import '../../../providers/data_provider.dart';
import '../../../providers/theme_provider.dart';
import 'security_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'about_screen.dart';
import 'password_activity_json_screen.dart';
import 'autofill_service_screen.dart';
import '../advanced_features_screen.dart';

// Modern Light Blue Color Scheme


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  bool _isLoading = false;
  bool _autofillEnabled = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _checkAutofillStatus();
  }

  Future<void> _checkAutofillStatus() async {
    try {
      final enabled = await AutofillFrameworkService.instance.isAutofillServiceEnabled();
      if (mounted) {
        setState(() {
          _autofillEnabled = enabled;
        });
      }
    } catch (e) {
      // ignore errors and keep default false
      print('ProfileScreen: Error checking autofill status: $e');
    }
  }

  void _getCurrentUser() {
    setState(() {
      _currentUser = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await _showLogoutDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FirebaseAuthService.signOut();
      
      if (result.success && mounted) {
        // Navigate to login screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } else if (mounted) {
        AppHelpers.showSnackBar(
          context,
          result.message,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Error during logout: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showLogoutDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Sign Out',
          style: TextStyle(
            color: ModernColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out? You\'ll need to sign in again to access your vault.',
          style: TextStyle(
            color: ModernColors.textLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: ModernColors.textLight),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernColors.white,
      appBar: AppBar(
        backgroundColor: ModernColors.white,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: ModernColors.textDark,
            fontSize: ResponsiveBreakpoints.responsiveFontSize(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: ResponsiveLayout(
        child: ListView(
          padding: ResponsiveBreakpoints.responsivePadding(
            context,
            mobile: const EdgeInsets.all(16),
            tablet: const EdgeInsets.all(20),
            desktop: const EdgeInsets.all(24),
          ),
          children: [
          // Profile Header
          Container(
            padding: ResponsiveBreakpoints.responsivePadding(
              context,
              mobile: const EdgeInsets.all(24),
              tablet: const EdgeInsets.all(28),
              desktop: const EdgeInsets.all(32),
            ),
            decoration: BoxDecoration(
              color: ModernColors.lightBlue,
              borderRadius: BorderRadius.circular(
                ResponsiveBreakpoints.responsive<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: ResponsiveBreakpoints.responsive<double>(
                    context,
                    mobile: 60,
                    tablet: 70,
                    desktop: 80,
                  ),
                  height: ResponsiveBreakpoints.responsive<double>(
                    context,
                    mobile: 60,
                    tablet: 70,
                    desktop: 80,
                  ),
                  decoration: const BoxDecoration(
                    color: ModernColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: _currentUser?.photoURL != null
                      ? ClipOval(
                          child: Image.network(
                            _currentUser!.photoURL!,
                            width: ResponsiveBreakpoints.responsive<double>(
                              context,
                              mobile: 60,
                              tablet: 70,
                              desktop: 80,
                            ),
                            height: ResponsiveBreakpoints.responsive<double>(
                              context,
                              mobile: 60,
                              tablet: 70,
                              desktop: 80,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person_rounded,
                              color: ModernColors.white,
                              size: ResponsiveBreakpoints.responsive<double>(
                                context,
                                mobile: 30,
                                tablet: 35,
                                desktop: 40,
                              ),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: ModernColors.white,
                          size: ResponsiveBreakpoints.responsive<double>(
                            context,
                            mobile: 30,
                            tablet: 35,
                            desktop: 40,
                          ),
                        ),
                ),
                SizedBox(width: ResponsiveBreakpoints.responsive<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                )),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser?.displayName ?? 'LinkCrypta User',
                        style: TextStyle(
                          fontSize: ResponsiveBreakpoints.responsiveFontSize(
                            context,
                            mobile: 18,
                            tablet: 20,
                            desktop: 22,
                          ),
                          fontWeight: FontWeight.w600,
                          color: ModernColors.textDark,
                        ),
                      ),
                      SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                        context,
                        mobile: 4,
                        tablet: 5,
                        desktop: 6,
                      )),
                      Text(
                        _currentUser?.email ?? 'Secure Password Manager',
                        style: TextStyle(
                          fontSize: ResponsiveBreakpoints.responsiveFontSize(
                            context,
                            mobile: 14,
                            tablet: 15,
                            desktop: 16,
                          ),
                          color: ModernColors.textLight,
                        ),
                      ),
                      if (_currentUser != null) ...[
                        SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                          context,
                          mobile: 4,
                          tablet: 5,
                          desktop: 6,
                        )),
                        Container(
                          padding: ResponsiveBreakpoints.responsivePadding(
                            context,
                            mobile: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            tablet: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Google Account',
                            style: TextStyle(
                              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                                context,
                                mobile: 12,
                                tablet: 13,
                                desktop: 14,
                              ),
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 24,
            tablet: 28,
            desktop: 32,
          )),
          
          // Settings Section
          Text(
            'Settings',
            style: TextStyle(
              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                context,
                mobile: 16,
                tablet: 18,
                desktop: 20,
              ),
              fontWeight: FontWeight.w600,
              color: ModernColors.textDark,
            ),
          ),
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          )),
          
          // Settings Items
          _buildSettingsItem(
            context,
            icon: Icons.data_object_rounded,
            title: 'Password Activity JSON',
            subtitle: 'View activity logs in JSON format',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PasswordActivityJsonAuthWrapper(),
                ),
              );
            },
          ),
          
          _buildSettingsItem(
            context,
            icon: Icons.security_rounded,
            title: 'Security',
            subtitle: 'Manage encryption settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SecuritySettingsScreen(),
                ),
              );
            },
          ),

          _buildSettingsItem(
            context,
            icon: Icons.auto_awesome_rounded,
            title: 'Advanced Features',
            subtitle: 'Password generator and health tools',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdvancedFeaturesScreen(),
                ),
              );
            },
          ),

          // Autofill Service selection (LinkCrypta)
          _buildSettingsItem(
            context,
            icon: Icons.auto_fix_high_rounded,
            title: 'Autofill Service',
            subtitle: _autofillEnabled
                ? 'LinkCrypta is the selected autofill service'
                : 'Not selected — tap to manage autofill service',
            onTap: () async {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AutofillServiceScreen(),
                ),
              ).then((_) => _checkAutofillStatus());
            },
          ),

          // Text Size Settings
          _buildTextSizeSettings(context),
          
          if (_currentUser != null)
            _buildSettingsItem(
              context,
              icon: Icons.cloud_upload_rounded,
              title: 'Sync All to Firebase',
              subtitle: 'Upload all passwords and links to cloud',
              onTap: () => _syncAllToFirebase(),
            ),
    
          
         
         
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          )),
          
          if (_currentUser == null)
            _buildSettingsItem(
              context,
              icon: Icons.login_rounded,
              title: 'Sign In',
              subtitle: 'Sign in to sync your data across devices',
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 24,
            tablet: 28,
            desktop: 32,
          )),
          
          // About Section
          Text(
            'About',
            style: TextStyle(
              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                context,
                mobile: 16,
                tablet: 18,
                desktop: 20,
              ),
              fontWeight: FontWeight.w600,
              color: ModernColors.textDark,
            ),
          ),
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          )),
          
          _buildSettingsItem(
            context,
            icon: Icons.info_rounded,
            title: 'About LinkCrypta',
            subtitle: 'Version 1.0.0',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
          ),
          
          _buildSettingsItem(
            context,
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          
          _buildSettingsItem(
            context,
            icon: Icons.description_rounded,
            title: 'Terms of Service',
            subtitle: 'Read our terms of service',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TermsOfServiceScreen(),
                ),
              );
            },
          ),
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 24,
            tablet: 28,
            desktop: 32,
          )),
          
          // Developer Section
          Text(
            'Developer',
            style: TextStyle(
              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                context,
                mobile: 16,
                tablet: 18,
                desktop: 20,
              ),
              fontWeight: FontWeight.w600,
              color: ModernColors.textDark,
            ),
          ),
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          )),
          
          _buildSettingsItem(
            context,
            icon: Icons.refresh_rounded,
            title: 'Reset Onboarding',
            subtitle: 'Show onboarding screens again',
            onTap: () async {
              final confirmed = await _showResetOnboardingDialog(context);
              if (confirmed) {
                await OnboardingService.resetOnboarding();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/onboarding');
                }
              }
            },
          ),

          _buildSettingsItem(
            context,
            icon: Icons.download_rounded,
            title: 'Import Autofill Credentials',
            subtitle: 'Import saved credentials from autofill service',
            onTap: () async {
              final dataProvider = Provider.of<DataProvider>(context, listen: false);
              try {
                await AutofillFrameworkService.instance.forceImportNewCredentials(dataProvider);
                if (context.mounted) {
                  AppHelpers.showSnackBar(
                    context,
                    'Autofill credentials imported successfully!',
                    backgroundColor: Colors.green,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppHelpers.showSnackBar(
                    context,
                    'Error importing credentials: ${e.toString()}',
                    backgroundColor: Colors.red,
                  );
                }
              }
            },
          ),
          
          
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 32,
            tablet: 36,
            desktop: 40,
          )),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _handleLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: ResponsiveBreakpoints.responsivePadding(
                  context,
                  mobile: const EdgeInsets.symmetric(vertical: 16),
                  tablet: const EdgeInsets.symmetric(vertical: 18),
                  desktop: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : Text(
                      _currentUser != null ? 'Sign Out' : 'Not Signed In',
                      style: TextStyle(
                        fontSize: ResponsiveBreakpoints.responsiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 17,
                          desktop: 18,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTextSizeSettings(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: EdgeInsets.only(
            bottom: ResponsiveBreakpoints.responsive<double>(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            ),
          ),
          decoration: BoxDecoration(
            color: ModernColors.white,
            borderRadius: BorderRadius.circular(
              ResponsiveBreakpoints.responsive<double>(
                context,
                mobile: 12,
                tablet: 14,
                desktop: 16,
              ),
            ),
            border: Border.all(
              color: ModernColors.lightGrey,
              width: 1,
            ),
          ),
          child: Padding(
            padding: ResponsiveBreakpoints.responsivePadding(
              context,
              mobile: const EdgeInsets.all(16),
              tablet: const EdgeInsets.all(18),
              desktop: const EdgeInsets.all(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: ResponsiveBreakpoints.responsive<double>(
                        context,
                        mobile: 40,
                        tablet: 44,
                        desktop: 48,
                      ),
                      height: ResponsiveBreakpoints.responsive<double>(
                        context,
                        mobile: 40,
                        tablet: 44,
                        desktop: 48,
                      ),
                      decoration: BoxDecoration(
                        color: ModernColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.text_fields_rounded,
                        size: ResponsiveBreakpoints.responsive<double>(
                          context,
                          mobile: 20,
                          tablet: 22,
                          desktop: 24,
                        ),
                        color: ModernColors.primaryBlue,
                      ),
                    ),
                    SizedBox(width: ResponsiveBreakpoints.responsive<double>(
                      context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    )),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Text Size',
                            style: TextStyle(
                              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                                context,
                                mobile: 16,
                                tablet: 17,
                                desktop: 18,
                              ),
                              fontWeight: FontWeight.w500,
                              color: ModernColors.textDark,
                            ),
                          ),
                          Text(
                            'Adjust text size for better readability',
                            style: TextStyle(
                              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                                context,
                                mobile: 14,
                                tablet: 15,
                                desktop: 16,
                              ),
                              color: ModernColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                )),
                Row(
                  children: [
                    Text(
                      'Small',
                      style: TextStyle(
                        fontSize: ResponsiveBreakpoints.responsiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                        color: ModernColors.textLight,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: themeProvider.textScaleFactor,
                        min: 0.8,
                        max: 1.4,
                        divisions: 6,
                        activeColor: ModernColors.primaryBlue,
                        inactiveColor: ModernColors.lightGrey,
                        onChanged: (value) {
                          themeProvider.setTextScaleFactor(value);
                        },
                      ),
                    ),
                    Text(
                      'Large',
                      style: TextStyle(
                        fontSize: ResponsiveBreakpoints.responsiveFontSize(
                          context,
                          mobile: 12,
                          tablet: 13,
                          desktop: 14,
                        ),
                        color: ModernColors.textLight,
                      ),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    'Sample text: ${(themeProvider.textScaleFactor * 100).round()}%',
                    style: TextStyle(
                      fontSize: ResponsiveBreakpoints.responsiveFontSize(
                        context,
                        mobile: 14,
                        tablet: 15,
                        desktop: 16,
                      ),
                      color: ModernColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveBreakpoints.responsive<double>(
          context,
          mobile: 8,
          tablet: 10,
          desktop: 12,
        ),
      ),
      decoration: BoxDecoration(
        color: ModernColors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          ),
        ),
        border: Border.all(
          color: ModernColors.lightGrey,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 40,
            tablet: 44,
            desktop: 48,
          ),
          height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 40,
            tablet: 44,
            desktop: 48,
          ),
          decoration: BoxDecoration(
            color: ModernColors.primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: ResponsiveBreakpoints.responsive<double>(
              context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
            color: ModernColors.primaryBlue,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: ResponsiveBreakpoints.responsiveFontSize(
              context,
              mobile: 16,
              tablet: 17,
              desktop: 18,
            ),
            fontWeight: FontWeight.w500,
            color: ModernColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: ResponsiveBreakpoints.responsiveFontSize(
              context,
              mobile: 14,
              tablet: 15,
              desktop: 16,
            ),
            color: ModernColors.textLight,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: ModernColors.textLight,
        ),
        onTap: onTap,
        contentPadding: ResponsiveBreakpoints.responsivePadding(
          context,
          mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tablet: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Future<bool> _showResetOnboardingDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Onboarding',
          style: TextStyle(
            color: ModernColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'This will show the onboarding screens again when you restart the app. Are you sure?',
          style: TextStyle(
            color: ModernColors.textLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: ModernColors.textLight),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernColors.primaryBlue,
              foregroundColor: ModernColors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Sync all data to Firebase
  Future<void> _syncAllToFirebase() async {
    if (_currentUser == null) {
      AppHelpers.showSnackBar(
        context,
        'Please sign in to sync with Firebase',
        backgroundColor: Colors.orange,
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showSyncConfirmationDialog(
      'Sync All to Firebase',
      'This will upload all your passwords and links to Firebase. Continue?',
    );
    if (!confirmed) return;

    try {
      // Show loading indicator
      AppHelpers.showSnackBar(
        context,
        'Syncing all data to Firebase...',
        backgroundColor: Colors.blue,
      );

      final dataProvider = context.read<DataProvider>();
      final success = await dataProvider.syncAllToFirebase();

      if (success) {
        AppHelpers.showSnackBar(
          context,
          'All data synced to Firebase successfully!',
          backgroundColor: Colors.green,
        );
      } else {
        AppHelpers.showSnackBar(
          context,
          'Failed to sync all data to Firebase',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      AppHelpers.showSnackBar(
        context,
        'Sync error: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    }
  }

  /// Show sync confirmation dialog
  Future<bool> _showSyncConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            color: ModernColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: ModernColors.textLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: ModernColors.textLight),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernColors.primaryBlue,
              foregroundColor: ModernColors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ) ?? false;
  }
}
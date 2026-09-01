import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/password_entry.dart';
import '../../../providers/data_provider.dart';
import '../../../utils/app_helpers.dart';
import '../../../utils/responsive.dart';
import '../../../services/auth_service.dart';
import 'edit_password_screen.dart';

// Modern Light Blue Color Scheme
class ModernColors {
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
}

class PasswordDetailScreen extends StatefulWidget {
  final PasswordEntry password;

  const PasswordDetailScreen({
    super.key,
    required this.password,
  });

  @override
  State<PasswordDetailScreen> createState() => _PasswordDetailScreenState();
}

class _PasswordDetailScreenState extends State<PasswordDetailScreen> {
  bool _obscurePassword = true;
  bool _isSyncing = false;
  final _colorScheme = const {
    'primary': ModernColors.primaryBlue,
    'secondary': ModernColors.primaryBlue,
    'accent': ModernColors.primaryBlue,
  };

  @override
  void initState() {
    super.initState();
    // Log that the password was viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.logPasswordViewed(widget.password);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardGradient = isDarkMode
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade900,
              Colors.grey.shade800,
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade100,
            ],
          );

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.password.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: _colorScheme['primary']),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditPasswordScreen(
                    password: widget.password,
                  ),
                ),
              );
              if (result == true) {
                // Refresh the data if edit was successful
                final dataProvider = context.read<DataProvider>();
                await dataProvider.loadData();
                // Update the widget to reflect changes
                setState(() {});
              }
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: ResponsiveBreakpoints.responsivePadding(
              context,
              mobile: const EdgeInsets.all(16.0),
              tablet: const EdgeInsets.all(20.0),
              desktop: const EdgeInsets.all(24.0),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Header Card with Gradient
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      ResponsiveBreakpoints.responsive<double>(
                        context,
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _colorScheme['primary']!,
                        _colorScheme['secondary']!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _colorScheme['primary']!.withValues(alpha: 0.3),
                        blurRadius: ResponsiveBreakpoints.responsive<double>(
                          context,
                          mobile: 15,
                          tablet: 18,
                          desktop: 20,
                        ),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: ResponsiveBreakpoints.responsivePadding(
                    context,
                    mobile: const EdgeInsets.all(24),
                    tablet: const EdgeInsets.all(28),
                    desktop: const EdgeInsets.all(32),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: ResponsiveBreakpoints.responsive<double>(
                          context,
                          mobile: 72,
                          tablet: 80,
                          desktop: 88,
                        ),
                        height: ResponsiveBreakpoints.responsive<double>(
                          context,
                          mobile: 72,
                          tablet: 80,
                          desktop: 88,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: ResponsiveBreakpoints.responsive<double>(
                            context,
                            mobile: 36,
                            tablet: 40,
                            desktop: 44,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                        context,
                        mobile: 16,
                        tablet: 18,
                        desktop: 20,
                      )),
                      Text(
                        widget.password.name,
                        style: TextStyle(
                          fontSize: ResponsiveBreakpoints.responsiveFontSize(
                            context,
                            mobile: 22,
                            tablet: 24,
                            desktop: 26,
                          ),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                        context,
                        mobile: 8,
                        tablet: 10,
                        desktop: 12,
                      )),
                      Container(
                        padding: ResponsiveBreakpoints.responsivePadding(
                          context,
                          mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.password.category,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: ResponsiveBreakpoints.responsiveFontSize(
                              context,
                              mobile: 12,
                              tablet: 13,
                              desktop: 14,
                            ),
                          ),
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

                // Details Section
                Padding(
                  padding: EdgeInsets.only(
                    left: ResponsiveBreakpoints.responsive<double>(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                  ),
                  child: Text(
                    'DETAILS',
                    style: TextStyle(
                      fontSize: ResponsiveBreakpoints.responsiveFontSize(
                        context,
                        mobile: 12,
                        tablet: 13,
                        desktop: 14,
                      ),
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveBreakpoints.responsive<double>(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                )),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      ResponsiveBreakpoints.responsive<double>(
                        context,
                        mobile: 20,
                        tablet: 22,
                        desktop: 24,
                      ),
                    ),
                    gradient: cardGradient,
                    boxShadow: [
                      if (!isDarkMode)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: ResponsiveBreakpoints.responsive<double>(
                            context,
                            mobile: 10,
                            tablet: 12,
                            desktop: 15,
                          ),
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Username
                      _buildModernDetailTile(
                        context,
                        icon: Icons.person_outline_rounded,
                        iconColor: _colorScheme['primary']!,
                        title: 'Username',
                        value: widget.password.username,
                        onTap: () {
                          AppHelpers.copyToClipboard(widget.password.username);
                          AppHelpers.showSnackBar(
                            context,
                            'Username copied',
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),

                      // Password
                      _buildPasswordTile(context),
                      if (widget.password.url.isNotEmpty)
                        const Divider(height: 1, indent: 16, endIndent: 16),

                      // URL
                      if (widget.password.url.isNotEmpty)
                        _buildModernDetailTile(
                          context,
                          icon: Icons.link_rounded,
                          iconColor: _colorScheme['secondary']!,
                          title: 'Website',
                          value: widget.password.url,
                          isUrl: true,
                          onTap: () => AppHelpers.launchUrl(widget.password.url),
                        ),
                      if (widget.password.notes.isNotEmpty)
                        const Divider(height: 1, indent: 16, endIndent: 16),

                      // Notes
                      if (widget.password.notes.isNotEmpty)
                        _buildModernDetailTile(
                          context,
                          icon: Icons.notes_rounded,
                          iconColor: _colorScheme['accent']!,
                          title: 'Notes',
                          value: widget.password.notes,
                          isMultiline: true,
                        ),
                      const Divider(height: 1, indent: 16, endIndent: 16),

                      // Created Date
                      _buildModernDetailTile(
                        context,
                        icon: Icons.calendar_month_rounded,
                        iconColor: Colors.orange.shade400,
                        title: 'Created',
                        value: AppHelpers.formatDateTime(widget.password.createdAt),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),

                      // Updated Date
                      _buildModernDetailTile(
                        context,
                        icon: Icons.update_rounded,
                        iconColor: Colors.teal.shade400,
                        title: 'Updated',
                        value: AppHelpers.formatDateTime(widget.password.updatedAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: _isSyncing ? Icons.sync : Icons.cloud_upload_rounded,
                        label: _isSyncing ? 'Syncing...' : 'Sync Now',
                        color: Colors.green.shade600,
                        onTap: _isSyncing ? null : () async {
                          await _syncPasswordToFirebase();
                        },
                      ),
                    ),
                    if (widget.password.url.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.open_in_browser_rounded,
                          label: 'Open Website',
                          color: _colorScheme['accent']!,
                          onTap: () => AppHelpers.launchUrl(widget.password.url),
                        ),
                      ),
                    ],
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDetailTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool isUrl = false,
    bool isMultiline = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      subtitle: isUrl
          ? Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _colorScheme['secondary'],
                decoration: TextDecoration.underline,
              ),
            )
          : Text(
              value,
              style: theme.textTheme.bodyMedium,
              maxLines: isMultiline ? null : 1,
              overflow: isMultiline ? null : TextOverflow.ellipsis,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPasswordTile(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _colorScheme['primary']!.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.lock_rounded,
          size: 20,
          color: _colorScheme['primary'],
        ),
      ),
      title: Text(
        'Password',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      subtitle: Text(
        _obscurePassword ? '••••••••' : widget.password.password,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
            onPressed: () async {
              // Authenticate before copying password
              final authenticated = await AuthService.showAuthDialog(
                context,
                reason: 'Authenticate to copy password',
              );
              
              if (authenticated) {
                final dataProvider = context.read<DataProvider>();
                final decryptedPassword = dataProvider.getDecryptedPassword(widget.password);
                AppHelpers.copyToClipboard(decryptedPassword);
                AppHelpers.showSnackBar(context, 'Password copied');
                
                // Log password view activity (since copying counts as viewing)
                dataProvider.logPasswordViewed(widget.password);
              }
            },
            splashRadius: 20,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isSyncing && label.contains('Sync')
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(
                        icon,
                        color: color,
                        size: 24,
                      ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sync password to Firebase when user clicks "Sync Now"
  Future<void> _syncPasswordToFirebase() async {
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppHelpers.showSnackBar(
        context,
        'Please sign in to sync with Firebase',
        backgroundColor: Colors.orange,
      );
      return;
    }

    print('DEBUG: Starting sync for user: ${currentUser.email}');

    setState(() {
      _isSyncing = true;
    });

    try {
      // Use the DataProvider's sync method
      final dataProvider = context.read<DataProvider>();
      final success = await dataProvider.syncPasswordToFirebase(widget.password);

      if (success) {
        AppHelpers.showSnackBar(
          context,
          'Password synced to Firebase successfully!',
          backgroundColor: Colors.green,
        );
      } else {
        // Get more detailed error from DataProvider
        final errorMsg = dataProvider.error ?? 'Unknown error occurred';
        AppHelpers.showSnackBar(
          context,
          'Sync failed: $errorMsg',
          backgroundColor: Colors.red,
        );
        print('DEBUG: Sync failed with error: $errorMsg');
      }
    } catch (e) {
      final errorMsg = 'Sync error: ${e.toString()}';
      AppHelpers.showSnackBar(
        context,
        errorMsg,
        backgroundColor: Colors.red,
      );
      print('DEBUG: Exception during sync: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}
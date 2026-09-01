import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/password_entry.dart';
import '../../../providers/data_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../services/encryption_service.dart';

class EditPasswordScreen extends StatefulWidget {
  final PasswordEntry password;

  const EditPasswordScreen({
    super.key,
    required this.password,
  });

  @override
  State<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends State<EditPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedCategory = 'General';

  // Modern color palette
  final _colors = {
    'primary': const Color(0xFF6C63FF),
    'secondary': const Color(0xFF4D8AF0),
    'accent': const Color(0xFFF7797D),
    'background': const Color(0xFFF8F9FA),
    'darkBackground': const Color(0xFF121212),
  };

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with existing password data
    _nameController.text = widget.password.name;
    _usernameController.text = widget.password.username;
    _passwordController.text = context.read<DataProvider>().getDecryptedPassword(widget.password);
    _urlController.text = widget.password.url;
    _notesController.text = widget.password.notes;
    _selectedCategory = widget.password.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    AppHelpers.hideKeyboard(context);

    try {
      final dataProvider = context.read<DataProvider>();
      
      // Encrypt the password before updating
      final encryptedPassword = EncryptionService.encryptString(_passwordController.text);
      
      // Create updated password entry
      final updatedPassword = widget.password.copyWith(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        password: encryptedPassword, // Use the encrypted password
        url: _urlController.text.trim(),
        notes: _notesController.text.trim(),
        category: _selectedCategory,
        updatedAt: DateTime.now(),
      );

      await dataProvider.updatePassword(updatedPassword);

      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Password updated successfully!',
          backgroundColor: Colors.green,
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Failed to update password: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _generatePassword() {
    final dataProvider = context.read<DataProvider>();
    final generatedPassword = dataProvider.generatePassword();
    setState(() {
      _passwordController.text = generatedPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? _colors['darkBackground']! : _colors['background']!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Edit Password'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: const Text('UPDATE'),
              style: FilledButton.styleFrom(
                backgroundColor: _colors['primary'],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _updatePassword,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _colors['primary']!,
                        _colors['secondary']!,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_rounded, size: 40, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Edit Password',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Update your password details below',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name Field
                _buildModernTextField(
                  context,
                  controller: _nameController,
                  label: 'Name',
                  icon: Icons.label_rounded,
                  iconColor: _colors['primary']!,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Username Field
                _buildModernTextField(
                  context,
                  controller: _usernameController,
                  label: 'Username/Email',
                  icon: Icons.person_rounded,
                  iconColor: _colors['secondary']!,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                _buildPasswordField(context),
                const SizedBox(height: 16),

                // URL Field
                _buildModernTextField(
                  context,
                  controller: _urlController,
                  label: 'Website URL (optional)',
                  icon: Icons.link_rounded,
                  iconColor: Colors.orange.shade400,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),

                // Category Field
                _buildCategoryDropdown(context),
                const SizedBox(height: 16),

                // Notes Field
                _buildNotesField(context),
                const SizedBox(height: 24),

                // Password Strength Tips
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _colors['primary']!.withValues(alpha: 0.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security_rounded, color: _colors['primary']),
                          const SizedBox(width: 8),
                          Text(
                            'Password Tips',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: _colors['primary'],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Use at least 12 characters\n'
                        '• Mix uppercase, lowercase, numbers & symbols\n'
                        '• Avoid common words and patterns\n'
                        '• Consider using a passphrase',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Update Button
                FilledButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: _colors['primary'],
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'UPDATE PASSWORD',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode 
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = _colors['accent']!;

    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.lock_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode 
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const SizedBox(width: 4),
              Container(
                height: 24,
                width: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.autorenew_rounded,
                  color: _colors['primary'],
                ),
                onPressed: _generatePassword,
              ),
            ],
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = Colors.teal.shade400;

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.category_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode 
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
      ),
      dropdownColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      items: AppConstants.defaultPasswordCategories
          .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategory = value;
          });
        }
      },
    );
  }

  Widget _buildNotesField(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final iconColor = Colors.purple.shade400;

    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Notes (optional)',
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.notes_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode 
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.white,
        alignLabelWithHint: true,
      ),
    );
  }
}
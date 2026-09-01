import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/data_provider.dart';
import '../../../utils/helpers.dart';
import '../../../models/password_entry.dart';
import '../../../services/auth_service.dart';
import 'add_password_screen.dart';
import 'password_detail_screen.dart';
import 'edit_password_screen.dart';
import 'widgets/password_card.dart';
import '../../../widgets/search_bar_widget.dart';
import '../../../widgets/category_filter_widget.dart';

class ModernColors {
  // Main colors
  static const Color primary = Color(0xFF6200EE);       // Deep purple
  static const Color secondary = Color(0xFF03DAC6);     // Teal
  static const Color accent = Color(0xFFBB86FC);        // Light purple
  
  // Background colors
  static const Color background = Color(0xFFF5F5F7);    // Light gray background
  static const Color surface = Color(0xFFFFFFFF);       // White surface
  static const Color surfaceVariant = Color(0xFFF3F3F3); // Light gray surface
  
  // Text colors
  static const Color textPrimary = Color(0xFF1F1F1F);   // Almost black
  static const Color textSecondary = Color(0xFF6E6E6E);  // Dark gray
  static const Color textTertiary = Color(0xFF9E9E9E);   // Medium gray
  
  // Utility colors
  static const Color error = Color(0xFFB00020);         // Error red
  static const Color success = Color(0xFF4CAF50);       // Success green
  static const Color warning = Color(0xFFFFA000);       // Warning amber
  static const Color info = Color(0xFF2196F3);          // Info blue
  static const Color divider = Color(0xFFE0E0E0);       // Light gray divider
}

class PasswordsScreen extends StatefulWidget {
  const PasswordsScreen({super.key});

  @override
  State<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends State<PasswordsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _showSearchBar = false;
  final ScrollController _scrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<DataProvider>(context, listen: false).loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      final dataProvider = context.read<DataProvider>();
      // First sync from cloud
      await dataProvider.syncFromFirebase();
      // Then reload local data
      await dataProvider.loadData();
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Failed to refresh data: ${e.toString()}',
          backgroundColor: ModernColors.error,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ModernColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Passwords',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearchBar ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchQuery = '';
                  context.read<DataProvider>().setSearchQuery('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToAddPassword,
          ),
        ],
      ),
      body: Column(
        children: [

          // Search Bar with Animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showSearchBar ? 60 : 0,
            child: _showSearchBar
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SearchBarWidget(
                      query: _searchQuery,
                      onChanged: (query) {
                        setState(() => _searchQuery = query);
                        context.read<DataProvider>().setSearchQuery(query);
                      },
                      onClear: () {
                        setState(() {
                          _searchQuery = '';
                          _showSearchBar = false;
                        });
                        context.read<DataProvider>().setSearchQuery('');
                      },
                      autoFocus: true,
                    ),
                  )
                : const SizedBox(),
          ),

          // Category Filter with Elevation
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Consumer<DataProvider>(
              builder: (context, dataProvider, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: CategoryFilterWidget(
                    categories: dataProvider.passwordCategories,
                    selectedCategory: _selectedCategory,
                    onCategoryChanged: (category) {
                      setState(() => _selectedCategory = category);
                      dataProvider.setSelectedPasswordCategory(category);
                    },
                  ),
                );
              },
            ),
          ),

          // Scrollable Password List with Refresh and Animations
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: ModernColors.primary,
              backgroundColor: ModernColors.surface,
              strokeWidth: 2.5,
              child: Consumer<DataProvider>(
                builder: (context, dataProvider, child) {
                  if (dataProvider.isLoading && dataProvider.passwords.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 20),
                          CircularProgressIndicator(
                            color: ModernColors.primary,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading passwords...',
                            style: TextStyle(
                              color: ModernColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final passwords = dataProvider.passwords;

                  if (passwords.isEmpty) {
                    return _buildEmptyState(true);
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: passwords.length,
                        itemBuilder: (context, index) {
                          final password = passwords[index];
                          // Add staggered animation effect
                          return AnimatedOpacity(
                            duration: Duration(milliseconds: 300 + (index * 30)),
                            opacity: 1.0,
                            curve: Curves.easeInOut,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12, left: 0, right: 0),
                              child: PasswordCard(
                                password: password,
                                onTap: () => _navigateToPasswordDetail(password),
                                onAction: (action, password) => _handlePasswordAction(action, password),
                              ),
                            ),
                          );
                        },
                      );
  },
);

                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: FloatingActionButton.extended(
          backgroundColor: ModernColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: _navigateToAddPassword,
          icon: const Icon(Icons.add, size: 24),
          label: const Text(
            'Add Password',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noPasswords) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: ModernColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  noPasswords ? Icons.lock_outlined : Icons.search_off_rounded,
                  size: 60,
                  color: ModernColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                noPasswords ? 'No Passwords Yet' : 'No Results Found',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: ModernColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                noPasswords
                    ? 'Securely store your passwords and access them anytime, anywhere.'
                    : 'Try a different search term or category filter.',
                style: const TextStyle(
                  fontSize: 16,
                  color: ModernColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (noPasswords)
                ElevatedButton.icon(
                  onPressed: _navigateToAddPassword,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Your First Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddPasswordScreen(),
      ),
    );
  }

  void _navigateToPasswordDetail(PasswordEntry password) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PasswordDetailScreen(password: password),
      ),
    );
  }

  Future<void> _toggleFavorite(PasswordEntry password) async {
    final dataProvider = context.read<DataProvider>();
    await dataProvider.togglePasswordFavorite(password);
  }

  Future<void> _deletePassword(PasswordEntry password) async {
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      'Delete Password',
      'Are you sure you want to delete "${password.name}"? This action cannot be undone.',
      confirmText: 'Delete',
    );

    if (confirmed) {
      final dataProvider = context.read<DataProvider>();
      await dataProvider.deletePassword(password);

      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Password deleted',
          backgroundColor: ModernColors.error,
        );
      }
    }
  }

  Future<void> _handlePasswordAction(String action, PasswordEntry password) async {
    final dataProvider = context.read<DataProvider>();
    
    switch (action) {
      case 'copy_password':
        // Authenticate before copying password
        final authenticated = await AuthService.showAuthDialog(
          context,
          reason: 'Authenticate to copy password',
        );
        
        if (authenticated) {
          try {
            final decryptedPassword = dataProvider.getDecryptedPassword(password);
            await AppHelpers.copyToClipboard(decryptedPassword);
            if (mounted) {
              AppHelpers.showSnackBar(context, 'Password copied to clipboard');
            }
            // Log password view activity (since copying counts as viewing)
            dataProvider.logPasswordViewed(password);
          } catch (e) {
            if (mounted) {
              AppHelpers.showSnackBar(
                context, 
                'Failed to decrypt password: ${e.toString()}', 
                backgroundColor: ModernColors.error
              );
            }
          }
        }
        break;
        
      case 'copy_username':
        await AppHelpers.copyToClipboard(password.username);
        if (mounted) {
          AppHelpers.showSnackBar(context, 'Username copied to clipboard');
        }
        break;
        
      case 'open_url':
        if (password.url.isNotEmpty) {
          final success = await AppHelpers.launchUrl(password.url);
          if (!success && mounted) {
            AppHelpers.showSnackBar(context, 'Cannot open this website', backgroundColor: ModernColors.error);
          }
        }
        break;
        
      case 'favorite':
        await _toggleFavorite(password);
        break;
        
      case 'edit':
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditPasswordScreen(password: password),
            ),
          );
        }
        break;
        
      case 'sync':
        try {
          await dataProvider.syncPasswordToFirebase(password);
          if (mounted) {
            AppHelpers.showSnackBar(context, 'Password synced to cloud');
          }
        } catch (e) {
          if (mounted) {
            AppHelpers.showSnackBar(context, 'Sync failed: ${e.toString()}', backgroundColor: ModernColors.error);
          }
        }
        break;
        
      case 'delete':
        await _deletePassword(password);
        break;
    }
  }
}

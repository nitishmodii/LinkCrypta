import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import 'passwords/passwords_screen.dart';
import 'links/links_screen.dart';
import 'favorites/favorites_screen.dart';
import 'profile/profile_screen.dart';
import 'passwords/add_password_screen.dart';
import 'links/widgets/add_edit_link_dialog.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final _colors = {
    'primary': const Color(0xFF6C63FF),
    'secondary': const Color(0xFF4D8AF0),
    'accent': const Color(0xFFF7797D),
    'cardGradient1': const Color(0xFF667eea),
    'cardGradient2': const Color(0xFF764ba2),
    'cardGradient3': const Color(0xFFf093fb),
    'cardGradient4': const Color(0xFFf5576c),
  };

  final List<Widget> _screens = [
    const PasswordsScreen(),
    const LinksScreen(),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: AppConstants.animationMedium,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                  ]
                : [
                    const Color(0xFFF8F9FA),
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(context, isDarkMode),
              
              // Main Content Area
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    children: _screens,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context, isDarkMode),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: ResponsiveBreakpoints.responsivePadding(
        context,
        mobile: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        tablet: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        desktop: const EdgeInsets.fromLTRB(32, 20, 32, 16),
      ),
      child: Column(
        children: [
          // App Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    _colors['primary']!,
                    _colors['secondary']!,
                  ],
                ).createShader(bounds),
                child: Text(
                  'LinkCrypta',
                  style: TextStyle(
                    fontSize: ResponsiveBreakpoints.responsiveFontSize(
                      context,
                      mobile: 24,
                      tablet: 28,
                      desktop: 32,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: [
                  _buildHeaderButton(
                    icon: Icons.notifications_outlined,
                    onTap: () {},
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24,
          )),
          
          // Stats Cards
          Consumer<DataProvider>(
            builder: (context, dataProvider, child) {
              return SizedBox(
                height: ResponsiveBreakpoints.responsive<double>(
                  context,
                  mobile: 80,
                  tablet: 90,
                  desktop: 100,
                ),
                child: ResponsiveBreakpoints.isDesktop(context)
                    ? _buildDesktopStatsGrid(dataProvider)
                    : _buildMobileStatsScroll(dataProvider),
              );
            },
          ),
        ],
      ),
    );
  }



  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: isDarkMode ? Colors.white : _colors['primary']),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    required BuildContext context,
    double? width,
  }) {
    return Container(
      width: width ?? ResponsiveBreakpoints.responsive<double>(
        context,
        mobile: 120,
        tablet: 140,
        desktop: 160,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 12,
            tablet: 14,
            desktop: 16,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: ResponsiveBreakpoints.responsive<double>(
              context,
              mobile: 6,
              tablet: 8,
              desktop: 10,
            ),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: ResponsiveBreakpoints.responsivePadding(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(14),
        desktop: const EdgeInsets.all(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveBreakpoints.responsive<double>(
                    context,
                    mobile: 4,
                    tablet: 5,
                    desktop: 6,
                  ),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: ResponsiveBreakpoints.responsive<double>(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: ResponsiveBreakpoints.responsiveFontSize(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          )),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, bool isDarkMode) {
    return Container(
      margin: ResponsiveBreakpoints.responsivePadding(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tablet: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 16,
            tablet: 18,
            desktop: 20,
          ),
        ),
        color: isDarkMode ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 16,
            tablet: 18,
            desktop: 20,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: ResponsiveBreakpoints.responsivePadding(
              context,
              mobile: const EdgeInsets.symmetric(vertical: 8),
              tablet: const EdgeInsets.symmetric(vertical: 10),
              desktop: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.lock_outline, 'Passwords', isDarkMode),
                _buildNavItem(1, Icons.link, 'Links', isDarkMode),
                _buildCenterAddButton(),
                _buildNavItem(2, Icons.favorite_border, 'Favorites', isDarkMode),
                _buildNavItem(3, Icons.person_outline, 'Profile', isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAddButton() {
    return GestureDetector(
      onTap: _showAddOptionsBottomSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4), // slight lift
        padding: EdgeInsets.all(
          ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 14,
            tablet: 16,
            desktop: 18,
          ),
        ),
        decoration: BoxDecoration(
          color: _colors['primary'],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _colors['primary']!.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 24,
            tablet: 28,
            desktop: 32,
          ),
        ),
      ),
    );
  }

  void _showAddOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              _buildAddOptionTile(
                context,
                title: 'Add Password',
                subtitle: 'Securely store a new login',
                icon: Icons.password_rounded,
                color: _colors['primary']!,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddPasswordScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildAddOptionTile(
                context,
                title: 'Add Link',
                subtitle: 'Save a secure encrypted bookmark',
                icon: Icons.link_rounded,
                color: _colors['secondary']!,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => const AddEditLinkDialog(),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddOptionTile(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDarkMode) {
    final isActive = _currentIndex == index;
    final activeColor = _colors['primary']!;
    final inactiveColor = isDarkMode ? Colors.white70 : Colors.grey;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(
              ResponsiveBreakpoints.responsive<double>(
                context,
                mobile: 8,
                tablet: 10,
                desktop: 12,
              ),
            ),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: ResponsiveBreakpoints.responsive<double>(
                context,
                mobile: 24,
                tablet: 26,
                desktop: 28,
              ),
            ),
          ),
          SizedBox(height: ResponsiveBreakpoints.responsive<double>(
            context,
            mobile: 4,
            tablet: 5,
            desktop: 6,
          )),
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveBreakpoints.responsiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Mobile stats scroll (horizontal)
  Widget _buildMobileStatsScroll(DataProvider dataProvider) {
    // Non-scrollable layout: divide available width between three cards
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = ResponsiveBreakpoints.responsive<double>(
          context,
          mobile: 8,
          tablet: 12,
          desktop: 16,
        );
        // total gaps between 3 cards -> 2 gaps
        final totalGaps = gap * 2;
        final cardWidth = (constraints.maxWidth - totalGaps) / 3;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                title: 'Passwords',
                value: dataProvider.allPasswords.length.toString(),
                icon: Icons.lock_outline,
                gradient: [_colors['cardGradient1']!, _colors['cardGradient2']!],
                context: context,
                width: cardWidth,
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                title: 'Links',
                value: dataProvider.allLinks.length.toString(),
                icon: Icons.link,
                gradient: [_colors['cardGradient3']!, _colors['cardGradient4']!],
                context: context,
                width: cardWidth,
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                title: 'Favorites',
                value: (dataProvider.allPasswords.where((p) => p.isFavorite).length +
                        dataProvider.allLinks.where((l) => l.isFavorite).length).toString(),
                icon: Icons.favorite_border,
                gradient: [_colors['accent']!, _colors['primary']!],
                context: context,
                width: cardWidth,
              ),
            ),
          ],
        );
      },
    );
  }

  // Desktop stats grid (3 columns)
  Widget _buildDesktopStatsGrid(DataProvider dataProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Passwords',
            value: dataProvider.allPasswords.length.toString(),
            icon: Icons.lock_outline,
            gradient: [_colors['cardGradient1']!, _colors['cardGradient2']!],
            context: context,
          ),
        ),
        SizedBox(width: ResponsiveBreakpoints.responsive<double>(
          context,
          mobile: 8,
          tablet: 12,
          desktop: 16,
        )),
        Expanded(
          child: _buildStatCard(
            title: 'Links',
            value: dataProvider.allLinks.length.toString(),
            icon: Icons.link,
            gradient: [_colors['cardGradient3']!, _colors['cardGradient4']!],
            context: context,
          ),
        ),
        SizedBox(width: ResponsiveBreakpoints.responsive<double>(
          context,
          mobile: 8,
          tablet: 12,
          desktop: 16,
        )),
        Expanded(
          child: _buildStatCard(
            title: 'Favorites',
            value: (dataProvider.allPasswords.where((p) => p.isFavorite).length +
                    dataProvider.allLinks.where((l) => l.isFavorite).length).toString(),
            icon: Icons.favorite_border,
            gradient: [_colors['accent']!, _colors['primary']!],
            context: context,
          ),
        ),
      ],
    );
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });
    
    _animationController.reset();
    _pageController.animateToPage(
      index,
      duration: AppConstants.animationFast,
      curve: Curves.easeInOut,
    ).then((_) {
      _animationController.forward();
    });
  }
}
import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'LinkCrypta';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Secure password and link management';
  static const Duration animationMedium = Duration(milliseconds: 400);

  // Colors
  static const Color primaryColor = Color(0xFF6750A4);
  static const Color secondaryColor = Color(0xFF625B71);
  static const Color tertiaryColor = Color(0xFF7D5260);
  static const Color surfaceColor = Color(0xFFFFFBFE);
  static const Color backgroundColor = Color(0xFFFFFBFE);
  static const Color errorColor = Color(0xFFB3261E);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);

  // Text Styles - Increased sizes for better readability
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1C1B1F),
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1C1B1F),
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1C1B1F),
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1C1B1F),
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: Color(0xFF1C1B1F),
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Color(0xFF1C1B1F),
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1C1B1F),
  );

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border Radius
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Categories
  static const List<String> defaultPasswordCategories = [
    'General',
    'Banking',
    'Work',
    'Social',
    'Shopping',
    'Entertainment',
    'Education',
    'Health',
    'Travel',
    'Browser Extension',
  ];

  static const List<String> defaultLinkCategories = [
    'General',
    'Learning',
    'Shopping',
    'Docs',
    'Social',
    'Work',
    'Entertainment',
    'News',
    'Tools',
  ];

  // Icons
  static const IconData iconPassword = Icons.lock_outline;
  static const IconData iconLink = Icons.link;
  static const IconData iconFavorite = Icons.favorite;
  static const IconData iconBookmark = Icons.bookmark;
  static const IconData iconSearch = Icons.search;
  static const IconData iconAdd = Icons.add;
  static const IconData iconEdit = Icons.edit;
  static const IconData iconDelete = Icons.delete;
  static const IconData iconCopy = Icons.copy;
  static const IconData iconVisibility = Icons.visibility;
  static const IconData iconVisibilityOff = Icons.visibility_off;
  static const IconData iconGenerate = Icons.refresh;
  static const IconData iconQR = Icons.qr_code;
  static const IconData iconSettings = Icons.settings;
  static const IconData iconProfile = Icons.person;
  static const IconData iconLogout = Icons.logout;
  static const IconData iconSecurity = Icons.security;
  static const IconData iconBackup = Icons.backup;
  static const IconData iconRestore = Icons.restore;
  static const IconData iconExport = Icons.file_download;
  static const IconData iconImport = Icons.file_upload;
  static const IconData iconFingerprint = Icons.fingerprint;
  static const IconData iconFace = Icons.face;
} 
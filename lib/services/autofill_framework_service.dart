import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../providers/data_provider.dart';
import '../widgets/save_credentials_dialog.dart';
import 'encryption_service.dart';
import 'smart_autofill_service.dart';

class AutofillFrameworkService {
  static const MethodChannel _channel = MethodChannel('com.linkcrypta.app/autofill');
  static AutofillFrameworkService? _instance;
  
  AutofillFrameworkService._();
  
  static AutofillFrameworkService get instance {
    _instance ??= AutofillFrameworkService._();
    return _instance!;
  }

  /// Initialize the autofill service and set up method call handlers
  Future<void> initialize(DataProvider dataProvider) async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getMatchingCredentials':
          return await _getMatchingCredentials(call.arguments, dataProvider);
        case 'showSaveDialog':
          return await _showSaveDialog(call.arguments, dataProvider);
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Method ${call.method} not implemented',
          );
      }
    });
    
    // Sync current passwords to SharedPreferences for Android autofill service
    await _syncPasswordsToSharedPrefs(dataProvider);
  }

  /// Sync passwords from Flutter app to Android autofill service
  Future<void> _syncPasswordsToSharedPrefs(DataProvider dataProvider) async {
    try {
      // First, import any new credentials before syncing to avoid overwriting them
      await importNewCredentialsFromAutofill(dataProvider);
      
      final passwords = dataProvider.passwords;
      final passwordsJson = passwords.map((entry) => {
        'id': entry.id,
        'name': entry.name,
        'username': entry.username,
        // IMPORTANT: send decrypted password to Android AutofillService
        // so it can fill the actual password value.
        'password': EncryptionService.decryptString(entry.password),
        'url': entry.url,
        'notes': entry.notes,
        'category': entry.category,
        'createdAt': entry.createdAt.toIso8601String(),
        'updatedAt': entry.updatedAt.toIso8601String(),
        'isFavorite': entry.isFavorite,
      }).toList();
      
      final jsonString = jsonEncode(passwordsJson);
      await _channel.invokeMethod('syncPasswordsToStorage', jsonString);
      
      print('AutofillFramework: Synced ${passwords.length} passwords to SharedPreferences and imported new credentials');
    } catch (e) {
      print('AutofillFramework: Error syncing passwords: $e');
    }
  }

  /// Check if autofill service is enabled
  Future<bool> isAutofillServiceEnabled() async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isAutofillServiceEnabled');
      return isEnabled;
    } catch (e) {
      print('Error checking autofill service status: $e');
      return false;
    }
  }

  /// Open autofill settings to enable the service
  Future<void> openAutofillSettings() async {
    try {
      await _channel.invokeMethod('openAutofillSettings');
    } catch (e) {
      print('Error opening autofill settings: $e');
    }
  }

  /// Handle request for matching credentials from Android AutofillService
  Future<List<Map<String, dynamic>>> _getMatchingCredentials(
    dynamic arguments, 
    DataProvider dataProvider
  ) async {
    try {
      final String url = arguments['url'] as String;
      
      // Use existing SmartAutoFillService to find matches
      final matches = SmartAutoFillService.findMatchingPasswords(
        url,
        dataProvider.passwords,
      );

      // Convert to format expected by Android service
      final List<Map<String, dynamic>> credentials = matches.map((match) {
        return {
          'id': match.entry.id,
          'name': match.entry.name,
          'username': match.entry.username,
          'password': EncryptionService.decryptString(match.entry.password),
          'url': match.entry.url,
          'confidence': match.confidence.name,
          'score': match.score,
        };
      }).toList();

      print('AutofillFramework: Found ${credentials.length} matching credentials for $url');
      return credentials;
    } catch (e) {
      print('AutofillFramework: Error getting matching credentials: $e');
      return [];
    }
  }

  /// Handle save dialog request from Android AutofillService
  Future<bool> _showSaveDialog(
    dynamic arguments, 
    DataProvider dataProvider
  ) async {
    try {
      final String url = arguments['url'] as String;
      final String username = arguments['username'] as String;
      final String password = arguments['password'] as String;

      print('AutofillFramework: Save dialog requested for $url with username: ${username.isNotEmpty}');

      // Check if this credential already exists
      final matches = SmartAutoFillService.findMatchingPasswords(url, dataProvider.passwords);
      final existingMatch = matches.where(
        (match) => match.entry.username == username,
      ).firstOrNull;

      if (existingMatch != null) {
        // Update existing entry if password changed
        final decryptedPassword = EncryptionService.decryptString(existingMatch.entry.password);
        if (decryptedPassword != password) {
          print('AutofillFramework: Updating existing password for $username');
          final updatedEntry = existingMatch.entry.copyWith(
            password: EncryptionService.encryptString(password),
            updatedAt: DateTime.now(),
          );
          await dataProvider.updatePassword(updatedEntry);
          return true;
        } else {
          print('AutofillFramework: Password unchanged, no update needed');
          return false; // No changes needed
        }
      }

      // For new credentials, create a new entry
      print('AutofillFramework: Creating new password entry');
      await dataProvider.addPassword(
        name: _generateFriendlyName(url),
        username: username,
        password: password,
        url: url,
        category: 'General',
        notes: 'Auto-saved via Android Autofill Framework',
      );
      
      return true;
    } catch (e) {
      print('AutofillFramework: Error processing save dialog request: $e');
      return false;
    }
  }

  /// Generate a friendly name from URL or package name
  String _generateFriendlyName(String url) {
    try {
      // Handle app package names (e.g., com.example.app)
      if (url.contains('.') && !url.startsWith('http') && !url.contains('/')) {
        final parts = url.split('.');
        if (parts.length >= 2) {
          String name = parts.last.replaceAll('_', ' ').split(' ')
              .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
              .join(' ');
          return name.isEmpty ? 'Mobile App' : name;
        }
      }

      // Handle URLs
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      String domain = uri.host;
      
      // Remove common prefixes and suffixes
      domain = domain
          .replaceFirst(RegExp(r'^www\.'), '')
          .replaceFirst(RegExp(r'\.com$'), '')
          .replaceFirst(RegExp(r'\.org$'), '')
          .replaceFirst(RegExp(r'\.net$'), '');
      
      // Capitalize first letter
      if (domain.isNotEmpty) {
        domain = domain[0].toUpperCase() + domain.substring(1);
      }
      
      return domain.isEmpty ? 'New Account' : domain;
    } catch (e) {
      print('AutofillFramework: Error generating name from $url: $e');
      return 'New Account';
    }
  }

  /// Manually trigger autofill for testing
  Future<void> triggerAutofill(String packageName) async {
    try {
      await _channel.invokeMethod('triggerAutofill', {'packageName': packageName});
    } catch (e) {
      print('Error triggering autofill: $e');
    }
  }

  /// Get autofill service statistics
  Future<Map<String, dynamic>> getAutofillStats() async {
    try {
      final Map<dynamic, dynamic> stats = await _channel.invokeMethod('getAutofillStats');
      return Map<String, dynamic>.from(stats);
    } catch (e) {
      print('Error getting autofill stats: $e');
      return {};
    }
  }

  /// Enable/disable autofill for specific apps
  Future<void> setAppAutofillEnabled(String packageName, bool enabled) async {
    try {
      await _channel.invokeMethod('setAppAutofillEnabled', {
        'packageName': packageName,
        'enabled': enabled,
      });
    } catch (e) {
      print('Error setting app autofill status: $e');
    }
  }

  /// Get list of apps with autofill data
  Future<List<Map<String, dynamic>>> getAutofillApps() async {
    try {
      final List<dynamic> apps = await _channel.invokeMethod('getAutofillApps');
      return apps.map((app) => Map<String, dynamic>.from(app)).toList();
    } catch (e) {
      print('Error getting autofill apps: $e');
      return [];
    }
  }

  /// Check for new credentials saved by Android autofill service and import them
  Future<void> importNewCredentialsFromAutofill(DataProvider dataProvider) async {
    try {
      final List<dynamic> newCredentials = await _channel.invokeMethod('getNewCredentialsFromAutofill') ?? [];
      
      for (final credMap in newCredentials) {
        final Map<String, dynamic> credential = Map<String, dynamic>.from(credMap);
        
        // Check if this credential already exists
        final existingMatches = SmartAutoFillService.findMatchingPasswords(
          credential['url'] ?? '', 
          dataProvider.passwords
        );
        
        final exists = existingMatches.any((match) => match.entry.username == credential['username']);
        
        if (!exists) {
          // Add new credential to the main app
          await dataProvider.addPassword(
            name: credential['name'] ?? 'Auto-saved',
            username: credential['username'] ?? '',
            password: credential['password'] ?? '',
            url: credential['url'] ?? '',
            category: credential['category'] ?? 'General',
            notes: (credential['notes'] ?? '') + ' (Auto-imported from autofill)',
          );
          
          print('AutofillFramework: Imported new credential for ${credential['username']}');
        }
      }
      
      if (newCredentials.isNotEmpty) {
        // Clear the temporary storage after importing
        await _channel.invokeMethod('clearNewCredentials');
      }
    } catch (e) {
      print('AutofillFramework: Error importing new credentials: $e');
    }
  }

  /// Show save credentials dialog in the current context
  static Future<bool> showSaveCredentialsDialog({
    required BuildContext context,
    required String url,
    required String username,
    required String password,
    String? appName,
  }) async {
    return await SaveCredentialsDialog.show(
      context: context,
      url: url,
      username: username,
      password: password,
      appName: appName,
    );
  }

  /// Manually trigger import of new credentials (for testing/debugging)
  Future<void> forceImportNewCredentials(DataProvider dataProvider) async {
    print('AutofillFramework: Manually triggering import of new credentials...');
    await importNewCredentialsFromAutofill(dataProvider);
  }

  /// Check if autofill is supported on this device
  static bool get isSupported {
    // Autofill Framework is available from Android API 26 (Android 8.0)
    return true; // We'll let the platform channel handle the actual check
  }
}

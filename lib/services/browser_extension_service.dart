import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/password_entry.dart';
import '../services/encryption_service.dart';
import '../services/activity_log_service.dart';
import '../services/sync_service.dart';

class BrowserExtensionService {
  static final BrowserExtensionService _instance = BrowserExtensionService._internal();
  factory BrowserExtensionService() => _instance;
  BrowserExtensionService._internal();

  static const int _defaultPort = 8080;
  static const String _syncEndpoint = '/api/extension-sync';
  static const String _statusEndpoint = '/api/status';
  
  HttpServer? _server;
  Timer? _syncTimer;
  bool _isRunning = false;
  int _currentPort = _defaultPort;
  
  final List<Function(Map<String, dynamic>)> _listeners = [];
  // EncryptionService is static, no need to instantiate
  
  // Statistics
  int _totalReceived = 0;
  int _totalProcessed = 0;
  int _totalErrors = 0;
  DateTime? _lastSyncTime;

  bool get isRunning => _isRunning;
  int get currentPort => _currentPort;
  int get totalReceived => _totalReceived;
  int get totalProcessed => _totalProcessed;
  int get totalErrors => _totalErrors;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Start the local HTTP server to receive data from browser extension
  Future<bool> startServer({int? port}) async {
    if (_isRunning) {
      debugPrint('Browser extension server already running on port $_currentPort');
      return true;
    }

    try {
      _currentPort = port ?? _defaultPort;
      
      // Try to start server on the specified port
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _currentPort);
      
      debugPrint('Browser extension server started on port $_currentPort');
      
      // Handle incoming requests
      _server!.listen(_handleRequest);
      
      _isRunning = true;
      
      // Start periodic cleanup
      _startPeriodicCleanup();
      
      return true;
      
    } catch (e) {
      debugPrint('Failed to start server on port $_currentPort: $e');
      
      // Try alternative ports
      for (int altPort in [8081, 3000, 3001, 5000]) {
        try {
          _currentPort = altPort;
          _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _currentPort);
          
          debugPrint('Browser extension server started on alternative port $_currentPort');
          
          _server!.listen(_handleRequest);
          _isRunning = true;
          _startPeriodicCleanup();
          
          return true;
        } catch (altError) {
          debugPrint('Failed to start server on port $altPort: $altError');
        }
      }
      
      return false;
    }
  }

  // Stop the server
  Future<void> stopServer() async {
    if (!_isRunning) return;
    
    try {
      await _server?.close();
      _server = null;
      _isRunning = false;
      
      _syncTimer?.cancel();
      _syncTimer = null;
      
      debugPrint('Browser extension server stopped');
      
    } catch (e) {
      debugPrint('Error stopping server: $e');
    }
  }

  // Handle incoming HTTP requests
  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, X-Extension-ID');

    try {
      if (request.method == 'OPTIONS') {
        // Handle preflight requests
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      if (request.method == 'POST' && request.uri.path == _syncEndpoint) {
        await _handleSyncRequest(request);
      } else if (request.method == 'GET' && request.uri.path == _statusEndpoint) {
        await _handleStatusRequest(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Endpoint not found'}));
        await request.response.close();
      }
    } catch (e) {
      debugPrint('Error handling request: $e');
      _totalErrors++;
      
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': 'Internal server error'}));
      await request.response.close();
    }
  }

  // Handle sync requests from browser extension
  Future<void> _handleSyncRequest(HttpRequest request) async {
    try {
      // Read request body
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      _totalReceived++;
      _lastSyncTime = DateTime.now();
      
      debugPrint('🔄 RECEIVED DATA FROM EXTENSION: ${data['domain']}');
      debugPrint('📊 Full data: $data');
      
      // Validate required fields
      if (!_isValidCredentialData(data)) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': 'Invalid credential data'}));
        await request.response.close();
        return;
      }

      // Process the credential data
      final success = await _processCredentialData(data);
      
      if (success) {
        _totalProcessed++;
        debugPrint('✅ SUCCESSFULLY PROCESSED: ${data['domain']}');
        
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode({
          'success': true,
          'message': 'Credentials processed successfully'
        }));
        
        // Notify listeners
        _notifyListeners(data);
        debugPrint('📢 NOTIFIED LISTENERS: ${_listeners.length} listeners');
        
      } else {
        _totalErrors++;
        
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({
          'success': false,
          'error': 'Failed to process credentials'
        }));
      }
      
      await request.response.close();
      
    } catch (e) {
      debugPrint('Error processing sync request: $e');
      _totalErrors++;
      
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'Invalid request format'}));
      await request.response.close();
    }
  }

  // Handle status requests
  Future<void> _handleStatusRequest(HttpRequest request) async {
    try {
      debugPrint('📊 STATUS REQUEST RECEIVED');
      
      final status = {
        'running': _isRunning,
        'port': _currentPort,
        'statistics': {
          'totalReceived': _totalReceived,
          'totalProcessed': _totalProcessed,
          'totalErrors': _totalErrors,
          'lastSyncTime': _lastSyncTime?.toIso8601String(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      request.response.statusCode = HttpStatus.ok;
      request.response.write(jsonEncode(status));
      await request.response.close();
      
      debugPrint('✅ STATUS RESPONSE SENT: $status');
      
    } catch (e) {
      debugPrint('❌ Error handling status request: $e');
      
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': 'Failed to get status'}));
      await request.response.close();
    }
  }

  // Validate credential data
  bool _isValidCredentialData(Map<String, dynamic> data) {
    return data.containsKey('username') &&
           data.containsKey('password') &&
           data.containsKey('domain') &&
           data['username'] != null &&
           data['password'] != null &&
           data['domain'] != null &&
           data['username'].toString().isNotEmpty &&
           data['password'].toString().isNotEmpty &&
           data['domain'].toString().isNotEmpty;
  }

  // Process credential data and save to Hive
  Future<bool> _processCredentialData(Map<String, dynamic> data) async {
    try {
      debugPrint('🔍 PROCESSING CREDENTIAL DATA FOR: ${data['domain']}');
      
      // Check if this credential already exists
      final existingPassword = await _findExistingPassword(
        data['domain'].toString(),
        data['username'].toString(),
      );
      
      debugPrint('🔎 EXISTING PASSWORD CHECK: ${existingPassword != null ? 'FOUND' : 'NOT FOUND'}');

      if (existingPassword != null) {
        // Update existing password if different
        if (existingPassword.password != data['password'].toString()) {
          await _updateExistingPassword(existingPassword, data);
          debugPrint('Updated existing password for ${data['domain']}');
        } else {
          debugPrint('Password already exists and is identical for ${data['domain']}');
        }
        return true;
      }

      // Create new password entry
      final passwordEntry = PasswordEntry(
        id: _generateId(),
        name: data['title']?.toString() ?? _generateTitle(data['domain'].toString(), data['username'].toString()),
        username: data['username'].toString(),
        password: data['password'].toString(),
        url: data['url']?.toString() ?? 'https://${data['domain']}',
        notes: _generateNotes(data),
        category: 'Browser Extension',
        isFavorite: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Encrypt password and save
      final encryptedPassword = EncryptionService.encryptString(passwordEntry.password);
      final entryToSave = passwordEntry.copyWith(password: encryptedPassword);
      
      final box = await Hive.openBox<PasswordEntry>('passwords');
      await box.add(entryToSave);
      
      // Log activity
      await ActivityLogService.logPasswordCreated(passwordEntry);

      // Also push to Firestore so the extension can sync
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          await SyncService.syncPasswordToFirebase(passwordEntry);
          debugPrint('☁️ PUSHED TO FIRESTORE: ${data['domain']}');
        } catch (e) {
          debugPrint('⚠️ Firestore push failed (will sync later): $e');
        }
      }

      debugPrint('💾 SAVED NEW PASSWORD FOR: ${data['domain']} from browser extension');
      debugPrint('📝 PASSWORD ENTRY ID: ${passwordEntry.id}');
      return true;
      
    } catch (e) {
      debugPrint('Error processing credential data: $e');
      return false;
    }
  }

  // Find existing password by domain and username
  Future<PasswordEntry?> _findExistingPassword(String domain, String username) async {
    try {
      final box = await Hive.openBox<PasswordEntry>('passwords');
      
      for (int i = 0; i < box.length; i++) {
        final encryptedEntry = box.getAt(i);
        if (encryptedEntry == null) continue;
        
        final decryptedPassword = EncryptionService.decryptString(encryptedEntry.password);
        final entry = encryptedEntry.copyWith(password: decryptedPassword);
        
        // Check if domain matches (handle subdomains)
        final entryDomain = _extractDomain(entry.url);
        final targetDomain = _extractDomain(domain);
        
        if (_domainsMatch(entryDomain, targetDomain) && 
            entry.username.toLowerCase() == username.toLowerCase()) {
          return entry;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error finding existing password: $e');
      return null;
    }
  }

  // Update existing password
  Future<void> _updateExistingPassword(PasswordEntry existing, Map<String, dynamic> newData) async {
    try {
      final updatedEntry = PasswordEntry(
        id: existing.id,
        name: existing.name,
        username: existing.username,
        password: newData['password'].toString(),
        url: newData['url']?.toString() ?? existing.url,
        notes: existing.notes + '\n\nUpdated from browser extension on ${DateTime.now()}',
        category: existing.category,
        isFavorite: existing.isFavorite,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );

      final encryptedPassword = EncryptionService.encryptString(updatedEntry.password);
      final encryptedEntry = updatedEntry.copyWith(password: encryptedPassword);
      
      final box = await Hive.openBox<PasswordEntry>('passwords');
      
      // Find and update the entry
      for (int i = 0; i < box.length; i++) {
        final entry = box.getAt(i);
        if (entry?.id == existing.id) {
          await box.putAt(i, encryptedEntry);
          break;
        }
      }

      // Log activity
      await ActivityLogService.logPasswordUpdated(updatedEntry, existing.password);
      
    } catch (e) {
      debugPrint('Error updating existing password: $e');
    }
  }

  // Extract domain from URL
  String _extractDomain(String url) {
    try {
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      final uri = Uri.parse(url);
      return uri.host.toLowerCase().replaceFirst('www.', '');
    } catch (e) {
      return url.toLowerCase().replaceFirst('www.', '');
    }
  }

  // Check if domains match (including subdomains)
  bool _domainsMatch(String domain1, String domain2) {
    if (domain1 == domain2) return true;
    
    final parts1 = domain1.split('.');
    final parts2 = domain2.split('.');
    
    if (parts1.length >= 2 && parts2.length >= 2) {
      final baseDomain1 = parts1.sublist(parts1.length - 2).join('.');
      final baseDomain2 = parts2.sublist(parts2.length - 2).join('.');
      return baseDomain1 == baseDomain2;
    }
    
    return false;
  }

  // Generate title for password entry
  String _generateTitle(String domain, String username) {
    final cleanDomain = domain.replaceFirst('www.', '');
    return '$cleanDomain - $username';
  }

  // Generate notes for password entry
  String _generateNotes(Map<String, dynamic> data) {
    final notes = StringBuffer();
    notes.writeln('Automatically captured from browser extension');
    notes.writeln('Captured on: ${DateTime.now()}');
    
    if (data['captureType'] != null) {
      notes.writeln('Capture type: ${data['captureType']}');
    }
    
    if (data['isRegistration'] == true) {
      notes.writeln('Captured during registration');
    }
    
    if (data['favicon'] != null) {
      notes.writeln('Favicon: ${data['favicon']}');
    }
    
    return notes.toString();
  }

  // Generate unique ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  // Start periodic cleanup
  void _startPeriodicCleanup() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performCleanup();
    });
  }

  // Perform periodic cleanup
  void _performCleanup() {
    // Reset error count periodically
    if (_totalErrors > 100) {
      _totalErrors = (_totalErrors * 0.8).round();
    }
    
    debugPrint('Browser extension service cleanup completed');
  }

  // Add listener for credential events
  void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners
  void _notifyListeners(Map<String, dynamic> data) {
    for (final listener in _listeners) {
      try {
        listener(data);
      } catch (e) {
        debugPrint('Error notifying listener: $e');
      }
    }
  }

  // Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'isRunning': _isRunning,
      'currentPort': _currentPort,
      'totalReceived': _totalReceived,
      'totalProcessed': _totalProcessed,
      'totalErrors': _totalErrors,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'successRate': _totalReceived > 0 ? (_totalProcessed / _totalReceived * 100).toStringAsFixed(1) : '0.0',
    };
  }

  // Reset statistics
  void resetStatistics() {
    _totalReceived = 0;
    _totalProcessed = 0;
    _totalErrors = 0;
    _lastSyncTime = null;
  }

  // Dispose resources
  Future<void> dispose() async {
    await stopServer();
    _listeners.clear();
  }
}

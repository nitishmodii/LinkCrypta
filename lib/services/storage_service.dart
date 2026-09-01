import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/password_entry.dart';
import '../models/link_entry.dart';
import '../models/user.dart';
import 'encryption_service.dart';

class StorageService {
  static const String _passwordBoxName = 'passwords';
  static const String _linkBoxName = 'links';
  static const Uuid _uuid = Uuid();

  static late Box<PasswordEntry> _passwordBox;
  static late Box<LinkEntry> _linkBox;

  static Future<void> initialize() async {
   
    if (!Hive.isAdapterRegistered(PasswordEntryAdapter().typeId)) {
      Hive.registerAdapter(PasswordEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(LinkEntryAdapter().typeId)) {
      Hive.registerAdapter(LinkEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(UserAdapter().typeId)) {
      Hive.registerAdapter(UserAdapter());
    }

    // Open boxes only if not already open
    if (!Hive.isBoxOpen(_passwordBoxName)) {
      _passwordBox = await Hive.openBox<PasswordEntry>(_passwordBoxName);
    } else {
      _passwordBox = Hive.box<PasswordEntry>(_passwordBoxName);
    }
    if (!Hive.isBoxOpen(_linkBoxName)) {
      _linkBox = await Hive.openBox<LinkEntry>(_linkBoxName);
    } else {
      _linkBox = Hive.box<LinkEntry>(_linkBoxName);
    }

    // Initialize storage service successfully
    // Loaded ${_passwordBox.length} passwords and ${_linkBox.length} links
  }

  // Password Management
  static Future<PasswordEntry> addPassword({
    String? id,
    required String name,
    required String username,
    required String password,
    required String url,
    String notes = '',
    String category = 'General',
  }) async {
    final now = DateTime.now();
    // Encrypt the password before storing
    final encryptedPassword = EncryptionService.encryptString(password);
    final entry = PasswordEntry(
      id: id ?? _uuid.v4(),
      name: name,
      username: username,
      password: encryptedPassword, // Store encrypted password
      url: url,
      notes: notes,
      category: category,
      createdAt: now,
      updatedAt: now,
    );

    await _passwordBox.add(entry);
    return entry;
  }

  static Future<void> updatePassword(PasswordEntry entry) async {
    // Find the entry in the Hive box by ID
    int? indexToUpdate;
    for (int i = 0; i < _passwordBox.length; i++) {
      final boxEntry = _passwordBox.getAt(i);
      if (boxEntry?.id == entry.id) {
        indexToUpdate = i;
        break;
      }
    }
    
    if (indexToUpdate != null) {
      // Update the timestamp
      entry.updatedAt = DateTime.now();
      // Update the entry at the found index
      await _passwordBox.putAt(indexToUpdate, entry);
    } else {
      // If not found, add as new entry
      await _passwordBox.add(entry);
    }
  }

  static Future<void> deletePassword(PasswordEntry entry) async {
    await entry.delete();
  }

  static List<PasswordEntry> getAllPasswords() {
    return _passwordBox.values.toList();
  }

  static String decryptPassword(String encryptedPassword) {
    try {
      return EncryptionService.decryptString(encryptedPassword);
    } catch (e) {
      // If decryption fails, return the original (for backward compatibility)
      return encryptedPassword;
    }
  }

  static List<PasswordEntry> getPasswordsByCategory(String category) {
    return _passwordBox.values
        .where((entry) => entry.category == category)
        .toList();
  }

  static List<PasswordEntry> getFavoritePasswords() {
    return _passwordBox.values
        .where((entry) => entry.isFavorite)
        .toList();
  }

  static List<PasswordEntry> searchPasswords(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _passwordBox.values
        .where((entry) =>
            entry.name.toLowerCase().contains(lowercaseQuery) ||
            entry.username.toLowerCase().contains(lowercaseQuery) ||
            entry.url.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  // Link Management
  static Future<LinkEntry> addLink({
    String? id,
    required String title,
    required String description,
    required String url,
    String category = 'General',
  }) async {
    final now = DateTime.now();
    final entry = LinkEntry(
      id: id ?? _uuid.v4(),
      title: title,
      description: description,
      url: url,
      category: category,
      createdAt: now,
      updatedAt: now,
    );

    await _linkBox.add(entry);
    // Link added successfully
    return entry;
  }

  static Future<void> updateLink(LinkEntry entry) async {
    // Find the entry in the Hive box by ID
    int? indexToUpdate;
    for (int i = 0; i < _linkBox.length; i++) {
      final boxEntry = _linkBox.getAt(i);
      if (boxEntry?.id == entry.id) {
        indexToUpdate = i;
        break;
      }
    }
    
    if (indexToUpdate != null) {
      // Update the timestamp
      entry.updatedAt = DateTime.now();
      // Update the entry at the found index
      await _linkBox.putAt(indexToUpdate, entry);
    } else {
      // If not found, add as new entry
      await _linkBox.add(entry);
    }
  }

  static Future<void> deleteLink(LinkEntry entry) async {
    await entry.delete();
  }

  static List<LinkEntry> getAllLinks() {
    final links = _linkBox.values.toList();
    return links;
  }

  static List<LinkEntry> getLinksByCategory(String category) {
    return _linkBox.values
        .where((entry) => entry.category == category)
        .toList();
  }

  static List<LinkEntry> getFavoriteLinks() {
    return _linkBox.values
        .where((entry) => entry.isFavorite)
        .toList();
  }

  static List<LinkEntry> getBookmarkedLinks() {
    return _linkBox.values
        .where((entry) => entry.isBookmarked)
        .toList();
  }

  static List<LinkEntry> searchLinks(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _linkBox.values
        .where((entry) =>
            entry.title.toLowerCase().contains(lowercaseQuery) ||
            entry.description.toLowerCase().contains(lowercaseQuery) ||
            entry.url.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  // Categories
  static List<String> getPasswordCategories() {
    final categories = _passwordBox.values
        .map((entry) => entry.category)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  static List<String> getLinkCategories() {
    final categories = _linkBox.values
        .map((entry) => entry.category)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  // Data Export/Import
  static Map<String, dynamic> exportData() {
    return {
      'passwords': _passwordBox.values.map((entry) => entry.toJson()).toList(),
      'links': _linkBox.values.map((entry) => entry.toJson()).toList(),
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    // Clear existing data
    await _passwordBox.clear();
    await _linkBox.clear();

    // Import passwords
    if (data['passwords'] != null) {
      for (final passwordData in data['passwords']) {
        final entry = PasswordEntry.fromJson(passwordData);
        await _passwordBox.add(entry);
      }
    }

    // Import links
    if (data['links'] != null) {
      for (final linkData in data['links']) {
        final entry = LinkEntry.fromJson(linkData);
        await _linkBox.add(entry);
      }
    }
  }

  // Cleanup
  static Future<void> close() async {
    await _passwordBox.close();
    await _linkBox.close();
  }

  static Future<void> clearAllData() async {
    await _passwordBox.clear();
    await _linkBox.clear();
    print('StorageService: Cleared all data');
  }
}
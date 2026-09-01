import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:linkcrypta/services/encryption_service.dart';
import 'package:linkcrypta/services/sync_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class MasterPasswordScreen extends StatefulWidget {
  const MasterPasswordScreen({super.key});

  @override
  State<MasterPasswordScreen> createState() => _MasterPasswordScreenState();
}

class _MasterPasswordScreenState extends State<MasterPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = true;
  bool _isSetup = false;
  bool _hasLegacyKey = false;
  List<int>? _firebaseSalt;
  Map<String, dynamic>? _keyVerification;
  
  @override
  void initState() {
    super.initState();
    _checkVaultState();
  }
  
  Future<void> _checkVaultState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    try {
      // Check Firebase for existing crypto settings
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('crypto')
          .get();
          
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('salt')) {
          _firebaseSalt = base64Decode(data['salt']);
          if (data.containsKey('keyCheck')) {
            _keyVerification = data['keyCheck'];
          }
          setState(() {
            _isSetup = false;
            _isLoading = false;
          });
          return;
        }
      }
      
      // If we reach here, no Firebase salt exists. Check for legacy local key.
      const storage = FlutterSecureStorage();
      final hasLegacyKey = await storage.containsKey(key: 'linkcrypta_encryption_key');
      
      setState(() {
        _isSetup = true;
        _hasLegacyKey = hasLegacyKey;
        _isLoading = false;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking vault state: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;
    
    if (_isSetup) {
      final confirm = _confirmPasswordController.text.trim();
      if (password != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }
      if (password.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 8 characters')),
        );
        return;
      }
    }
    
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser!;
    
    try {
      if (_isSetup) {
        // SETUP NEW VAULT OR MIGRATE
        final salt = EncryptionService.generateSalt();
        await EncryptionService.deriveAndCacheKey(password, salt);
        
        // Generate a verification payload to check the key on other devices
        final keyCheck = EncryptionService.encryptRecordSync({'check': 'VALID'});
        
        // Save to Firebase
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('crypto')
            .set({
          'salt': base64Encode(salt),
          'keyCheck': keyCheck,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (_hasLegacyKey) {
          // Perform Migration!
          await _migrateLegacyData();
        }
        
      } else {
        // UNLOCK EXISTING VAULT
        await EncryptionService.deriveAndCacheKey(password, _firebaseSalt!);
        
        // Verify key if we have a keyCheck payload
        if (_keyVerification != null) {
          try {
            final check = EncryptionService.decryptRecordSync(_keyVerification!);
            if (check['check'] != 'VALID') throw Exception('Invalid check payload');
          } catch (e) {
            // Wrong password!
            await EncryptionService.clearEncryptionKeys();
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect Master Password.')),
            );
            return;
          }
        }
      }
      
      // Sync from/to Firebase after setting up key
      await SyncService.syncFromFirebase();
      await SyncService.syncAllToFirebase();
      
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
      
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> _migrateLegacyData() async {
    const storage = FlutterSecureStorage();
    final oldKey = await storage.read(key: 'linkcrypta_encryption_key');
    final oldIv = await storage.read(key: 'linkcrypta_encryption_iv');
    
    if (oldKey == null || oldIv == null) return;
    
    final passwords = await SyncService.getAllPasswords();
    for (var p in passwords) {
      // The old system only encrypted the `password` field locally in AES-CBC
      final decryptedStr = EncryptionService.legacyDecrypt(p.password, oldKey, oldIv);
      if (decryptedStr != null) {
        // Now re-encrypt it using the new AES-GCM string encryption
        p.password = EncryptionService.encryptString(decryptedStr);
        await SyncService.updatePassword(p);
      }
    }
    
    // Clear old keys
    await storage.delete(key: 'linkcrypta_encryption_key');
    await storage.delete(key: 'linkcrypta_encryption_iv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Vault'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isSetup 
                        ? (_hasLegacyKey ? 'Upgrade Vault Security' : 'Set Master Password')
                        : 'Unlock Your Vault',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSetup
                        ? 'Your Master Password encrypts your data end-to-end. It is never sent to our servers. If you lose it, you lose access to your passwords.'
                        : 'Enter your Master Password to decrypt your vault. This stays securely on your device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Master Password',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  if (_isSetup) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Master Password',
                        prefixIcon: Icon(Icons.key),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isSetup ? 'Encrypt Vault' : 'Unlock Vault',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

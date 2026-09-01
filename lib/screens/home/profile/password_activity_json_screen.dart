import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../providers/data_provider.dart';
import '../../../models/password_activity_log.dart';
import '../../../services/auth_service.dart';
import '../../../services/encryption_service.dart';

class PasswordActivityJsonScreen extends StatefulWidget {
  const PasswordActivityJsonScreen({super.key});

  @override
  State<PasswordActivityJsonScreen> createState() =>
      _PasswordActivityJsonScreenState();
}

// Authentication wrapper for the password activity JSON screen
class PasswordActivityJsonAuthWrapper extends StatefulWidget {
  const PasswordActivityJsonAuthWrapper({super.key});

  @override
  State<PasswordActivityJsonAuthWrapper> createState() =>
      _PasswordActivityJsonAuthWrapperState();
}

class _PasswordActivityJsonAuthWrapperState
    extends State<PasswordActivityJsonAuthWrapper> {
  bool _isAuthenticating = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final bool authenticated = await AuthService.showAuthDialog(
      context,
      reason: 'Authentication required to view password activity logs',
    );

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _isAuthenticated = authenticated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return Scaffold(
        appBar: AppBar(title: const Text('Password Activity JSON')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Password Activity JSON')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Authentication Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'You need to authenticate to view password activity logs.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _authenticate();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return const PasswordActivityJsonScreen();
  }
}

class _PasswordActivityJsonScreenState extends State<PasswordActivityJsonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedPasswordId;
  ActivityType? _selectedActivityType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _prettyPrint = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Set default date range to last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Activity JSON'),
        actions: [
          // Toggle between pretty print and compact JSON
          IconButton(
            icon: Icon(_prettyPrint
                ? Icons.format_align_left
                : Icons.format_align_center),
            tooltip: _prettyPrint ? 'Pretty Print' : 'Compact JSON',
            onPressed: () {
              setState(() {
                _prettyPrint = !_prettyPrint;
              });
            },
          ),
          // Download JSON
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download JSON',
            onPressed: _downloadJsonToFile,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Viewed'),
            Tab(text: 'Created'),
            Tab(text: 'Modified'),
          ],
          onTap: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _selectedActivityType = null; // All
                  break;
                case 1:
                  _selectedActivityType = ActivityType.viewed;
                  break;
                case 2:
                  _selectedActivityType = ActivityType.created;
                  break;
                case 3:
                  // Both updated and deleted are considered modifications
                  _selectedActivityType = ActivityType.updated;
                  break;
              }
            });
          },
        ),
      ),
      body: Column(
        children: [
          // Date range filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate != null
                        ? DateFormat('MMM d, yyyy').format(_startDate!)
                        : 'Start Date'),
                    onPressed: () => _selectDate(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_endDate != null
                        ? DateFormat('MMM d, yyyy').format(_endDate!)
                        : 'End Date'),
                    onPressed: () => _selectDate(false),
                  ),
                ),
              ],
            ),
          ),

          // Activity logs list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActivityLogsJson(null),
                _buildActivityLogsJson(ActivityType.viewed),
                _buildActivityLogsJson(ActivityType.created),
                _buildActivityLogsJson(ActivityType.updated),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _copyJsonToClipboard,
        tooltip: 'Copy JSON',
        child: const Icon(Icons.copy),
      ),
    );
  }

  Widget _buildActivityLogsJson(ActivityType? activityType) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        List<PasswordActivityLog> logs = [];

        // Apply filters
        if (_selectedPasswordId != null) {
          logs = dataProvider.getPasswordLogsForPassword(_selectedPasswordId!);
        } else if (_startDate != null && _endDate != null) {
          logs = dataProvider.getPasswordLogsInDateRange(_startDate!, _endDate!);
        } else if (activityType != null) {
          logs = dataProvider.getPasswordLogsByActivityType(activityType);
        } else {
          logs = dataProvider.getAllPasswordLogs();
        }

        // Apply activity type filter
        if (activityType != null) {
          logs = logs.where((log) => log.activityType == activityType).toList();
        } else if (_selectedActivityType != null) {
          if (_selectedActivityType == ActivityType.updated) {
            logs = logs
                .where((log) =>
                    log.activityType == ActivityType.updated ||
                    log.activityType == ActivityType.deleted)
                .toList();
          } else {
            logs = logs
                .where((log) => log.activityType == _selectedActivityType)
                .toList();
          }
        }

        if (logs.isEmpty) {
          return const Center(
            child: Text('No activity logs found'),
          );
        }

        // Convert logs to JSON with decrypted values
        final List<Map<String, dynamic>> jsonLogs = logs.map((log) {
          final Map<String, dynamic> jsonLog = log.toJson();

          if (jsonLog['oldValue'] != null) {
            try {
              jsonLog['oldValue'] =
                  EncryptionService.decryptString(jsonLog['oldValue']);
            } catch (e) {
              jsonLog['oldValue'] = "[Encrypted: ${jsonLog['oldValue']}]";
            }
          }

          if (jsonLog['newValue'] != null) {
            try {
              jsonLog['newValue'] =
                  EncryptionService.decryptString(jsonLog['newValue']);
            } catch (e) {
              jsonLog['newValue'] = "[Encrypted: ${jsonLog['newValue']}]";
            }
          }

          return jsonLog;
        }).toList();

        final String jsonString = _prettyPrint
            ? const JsonEncoder.withIndent('  ').convert(jsonLogs)
            : json.encode(jsonLogs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText(
            jsonString,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _copyJsonToClipboard() async {
    final String jsonString = await _generateFilteredJson();
    await Clipboard.setData(ClipboardData(text: jsonString));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON copied to clipboard')),
    );
  }

  Future<void> _downloadJsonToFile() async {
    final String jsonString = await _generateFilteredJson();
    await _saveJsonToFile(jsonString);
  }

  Future<String> _generateFilteredJson() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    List<PasswordActivityLog> logs = [];

    if (_selectedPasswordId != null) {
      logs = dataProvider.getPasswordLogsForPassword(_selectedPasswordId!);
    } else if (_startDate != null && _endDate != null) {
      logs = dataProvider.getPasswordLogsInDateRange(_startDate!, _endDate!);
    } else if (_selectedActivityType != null) {
      logs = dataProvider.getPasswordLogsByActivityType(_selectedActivityType!);
    } else {
      logs = dataProvider.getAllPasswordLogs();
    }

    if (_tabController.index > 0) {
      final tabActivityType = _getActivityTypeForTabIndex(_tabController.index);
      if (tabActivityType == ActivityType.updated) {
        logs = logs
            .where((log) =>
                log.activityType == ActivityType.updated ||
                log.activityType == ActivityType.deleted)
            .toList();
      } else if (tabActivityType != null) {
        logs = logs.where((log) => log.activityType == tabActivityType).toList();
      }
    }

    final List<Map<String, dynamic>> jsonLogs = logs.map((log) {
      final Map<String, dynamic> jsonLog = log.toJson();

      if (jsonLog['oldValue'] != null) {
        try {
          jsonLog['oldValue'] = EncryptionService.decryptString(jsonLog['oldValue']);
        } catch (e) {
          jsonLog['oldValue'] = "[Encrypted: ${jsonLog['oldValue']}]";
        }
      }

      if (jsonLog['newValue'] != null) {
        try {
          jsonLog['newValue'] = EncryptionService.decryptString(jsonLog['newValue']);
        } catch (e) {
          jsonLog['newValue'] = "[Encrypted: ${jsonLog['newValue']}]";
        }
      }

      return jsonLog;
    }).toList();

    return _prettyPrint
        ? const JsonEncoder.withIndent('  ').convert(jsonLogs)
        : json.encode(jsonLogs);
  }

  Future<void> _saveJsonToFile(String jsonString) async {
    try {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
        return;
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final path = '${directory.path}/password_logs.json';
      final file = File(path);

      await file.writeAsString(jsonString);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  ActivityType? _getActivityTypeForTabIndex(int index) {
    switch (index) {
      case 0:
        return null;
      case 1:
        return ActivityType.viewed;
      case 2:
        return ActivityType.created;
      case 3:
        return ActivityType.updated;
      default:
        return null;
    }
  }
}

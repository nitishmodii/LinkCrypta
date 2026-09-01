import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';
import '../../services/smart_autofill_service.dart' as autofill;
import '../../services/encryption_service.dart';
import '../../models/password_entry.dart';

class SmartAutoFillScreen extends StatefulWidget {
  const SmartAutoFillScreen({super.key});

  @override
  State<SmartAutoFillScreen> createState() => _SmartAutoFillScreenState();
}

class _SmartAutoFillScreenState extends State<SmartAutoFillScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  
  List<autofill.UrlMatch> _urlMatches = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Auto-Fill'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4D8AF0)],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'URL Matching'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFF8F9FA), const Color(0xFFE3F2FD)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildUrlMatchingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlMatchingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUrlInputCard(),
          const SizedBox(height: 16),
          if (_urlMatches.isNotEmpty) _buildUrlMatchesCard(),
          const SizedBox(height: 16),
          _buildQuickUrlsCard(),
        ],
      ),
    );
  }

  Widget _buildUrlInputCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Text(
                  'URL Matching',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Enter URL',
                hintText: 'https://example.com',
                prefixIcon: const Icon(Icons.language),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _findMatches,
                ),
              ),
              onSubmitted: (_) => _findMatches(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _findMatches,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Searching...' : 'Find Matches'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste),
                  label: const Text('Paste'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlMatchesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Text(
                  'Matching Passwords (${_urlMatches.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _urlMatches.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final match = _urlMatches[index];
                return _buildMatchItem(match);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchItem(autofill.UrlMatch match) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _getConfidenceColor(match.confidence).withValues(alpha: 0.1),
        child: Icon(
          _getConfidenceIcon(match.confidence),
          color: _getConfidenceColor(match.confidence),
        ),
      ),
      title: Text(
        match.entry.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(match.entry.username),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(match.confidence).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  match.confidence.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getConfidenceColor(match.confidence),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${match.score.toInt()}% • ${match.reason}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        onPressed: () => _copyCredentials(match.entry),
      ),
    );
  }

  Widget _buildQuickUrlsCard() {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        final recentUrls = dataProvider.passwords
            .where((p) => p.url.isNotEmpty)
            .take(5)
            .toList();

        if (recentUrls.isEmpty) return const SizedBox();

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Quick URLs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recentUrls.map((entry) {
                    final domain = autofill.SmartAutoFillService.isValidUrl(entry.url)
                        ? Uri.parse(entry.url).host
                        : entry.url;
                    return ActionChip(
                      avatar: const Icon(Icons.language, size: 16),
                      label: Text(domain),
                      onPressed: () {
                        _urlController.text = entry.url;
                        _findMatches();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }










  void _findMatches() async {
    if (_urlController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final matches = autofill.SmartAutoFillService.findMatchingPasswords(
      _urlController.text,
      dataProvider.passwords,
    );

    setState(() {
      _urlMatches = matches;
      _isLoading = false;
    });

    if (matches.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${matches.length} matching passwords'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }



  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData?.text != null) {
      _urlController.text = clipboardData!.text!;
    }
  }

  void _copyCredentials(PasswordEntry entry) async {
    final decryptedPassword = EncryptionService.decryptString(entry.password);
    await Clipboard.setData(ClipboardData(text: '${entry.username}\n$decryptedPassword'));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Credentials copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }


  Color _getConfidenceColor(autofill.MatchConfidence confidence) {
    switch (confidence) {
      case autofill.MatchConfidence.exact:
        return Colors.green;
      case autofill.MatchConfidence.high:
        return Colors.blue;
      case autofill.MatchConfidence.medium:
        return Colors.orange;
      case autofill.MatchConfidence.low:
        return Colors.red;
    }
  }

  IconData _getConfidenceIcon(autofill.MatchConfidence confidence) {
    switch (confidence) {
      case autofill.MatchConfidence.exact:
        return Icons.verified;
      case autofill.MatchConfidence.high:
        return Icons.thumb_up;
      case autofill.MatchConfidence.medium:
        return Icons.help_outline;
      case autofill.MatchConfidence.low:
        return Icons.warning;
    }
  }

}

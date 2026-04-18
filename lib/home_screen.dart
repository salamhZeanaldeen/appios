import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'scanner_screen.dart';
import 'theme_provider.dart';
import 'document_provider.dart';
import 'report_service.dart';
import 'document_detail_screen.dart';
import 'notification_manager.dart';
import 'document_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DocumentProvider>(context, listen: false).loadDocuments();
    });
  }

  Future<void> _refresh() async {
    await Provider.of<DocumentProvider>(context, listen: false).loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DocumentProvider>(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'آخر المراسلات',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => ReportService().generatePendingReport(provider.documents),
                              icon: const Icon(Icons.pending_actions, color: Colors.redAccent),
                              label: const Text('العالقة', style: TextStyle(color: Colors.redAccent)),
                            ),
                            TextButton.icon(
                              onPressed: () => ReportService().generateDeadlineReport(provider.documents),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('ت. المواعيد'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRecentDocs(),
                    const SizedBox(height: 32),
                    _buildThemeSelector(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Directionality(textDirection: TextDirection.rtl, child: ScannerScreen())),
        ).then((_) => _refresh()),
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('مسح ضوئي جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      flexibleSpace: const FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'أرشيف السيادة المحلي',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => showSearch(
            context: context, 
            delegate: DocumentSearchDelegate()
          ),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: () => NotificationManager().showInstantNotification(
            title: '🔔 اختبار التنبيه',
            body: 'هذا تنبيه تجريبي للتأكد من عمل الصوت والنظام بشكل سليم.',
          ),
          icon: const Icon(Icons.notifications_active, color: Colors.amberAccent),
          tooltip: 'اختبار التنبيه',
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final statsData = Provider.of<DocumentProvider>(context).stats;

    if (Provider.of<DocumentProvider>(context).isLoading && statsData['total'] == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final statsList = [
      {'label': 'إجمالي المراسلات', 'value': statsData['total'] ?? 0, 'icon': Icons.library_books, 'color': Colors.blue},
      {'label': 'بانتظار الرد', 'value': statsData['pending'] ?? 0, 'icon': Icons.timer, 'color': Colors.amber},
      {'label': 'وارد', 'value': statsData['incoming'] ?? 0, 'icon': Icons.move_to_inbox, 'color': Colors.indigo},
      {'label': 'صادر', 'value': statsData['outgoing'] ?? 0, 'icon': Icons.outbox, 'color': Colors.green},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: statsList.length,
      itemBuilder: (context, i) {
        final item = statsList[i];
        return InkWell(
          onTap: () {
            String? fType;
            String? fStatus;
            String title = item['label'] as String;

            if (title == 'بانتظار الرد') fStatus = 'قيد الانتظار';
            if (title == 'وارد') fType = 'وارد';
            if (title == 'صادر') fType = 'صادر';

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DocumentListScreen(
                title: title,
                filterType: fType,
                filterStatus: fStatus,
              )),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(item['icon'] as IconData, color: (item['color'] as Color).withOpacity(0.8), size: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['value']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(item['label'] as String, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentDocs() {
    final recentDocs = Provider.of<DocumentProvider>(context).documents.take(5).toList();

    if (recentDocs.isEmpty && !Provider.of<DocumentProvider>(context).isLoading) {
      return const Center(child: Text('لا توجد مراسلات حالياً', style: TextStyle(color: Colors.white24)));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentDocs.length,
      itemBuilder: (context, i) {
        final doc = recentDocs[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DocumentDetailScreen(doc: doc)
              ),
            ),
            leading: Icon(
              doc['type'] == 'وارد' ? Icons.download_for_offline : Icons.upload_file,
              color: doc['type'] == 'وارد' ? Colors.blueAccent : Colors.greenAccent,
            ),
            title: Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              'الحالة: ${doc['status']}',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_left, color: Colors.white24),
          ),
        );
      },
    );
  }

  Widget _buildThemeSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اختر المظهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _themeChip('داكن', AppTheme.sovereignDark, themeProvider),
            const SizedBox(width: 8),
            _themeChip('فاتح', AppTheme.royalLight, themeProvider),
            const SizedBox(width: 8),
            _themeChip('برمجي', AppTheme.matrixGreen, themeProvider),
          ],
        ),
      ],
    );
  }


  Widget _themeChip(String label, AppTheme theme, ThemeProvider provider) {
    final isSelected = provider.currentTheme == theme;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) { if (val) provider.setTheme(theme); },
    );
  }
}

class DocumentSearchDelegate extends SearchDelegate {
  DocumentSearchDelegate();

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('ابحث عن عنوان أو محتوى مراسلة...'));
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return Consumer<DocumentProvider>(
      builder: (context, provider, child) {
        // Simple search logic for the delegate
        final results = provider.documents.where((d) => 
          d['title'].toString().contains(query) || 
          d['ocr_text'].toString().contains(query)
        ).toList();

        if (results.isEmpty) {
          return const Center(child: Text('لا توجد نتائج'));
        }
        
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) {
            final doc = results[i];
            return ListTile(
              title: Text(doc['title']),
              subtitle: Text(doc['type']),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DocumentDetailScreen(doc: doc))
              ),
            );
          },
        );
      },
    );
  }
}

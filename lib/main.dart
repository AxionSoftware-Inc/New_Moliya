import 'dart:io';
import 'package:be_core/be_core.dart';
import 'package:flutter/material.dart';
import 'finance_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storagePath = await getAppStoragePath('finance_data.json');
  final service = await FinanceService.init(storagePath);
  final server = StandardAppServer(schema: service.schema, store: service.store);
  try {
    await server.start();
  } catch (e) {
    stderr.writeln('Finance Server start ogohlantirish: $e');
  }

  final profileManager = await ProfileManager.create();
  final pluginManager = await PluginManager.create();

  runApp(FinanceApp(
    service: service,
    profileManager: profileManager,
    pluginManager: pluginManager,
  ));
}

// ============================================================================
// DESIGN SYSTEM & THEME ARCHITECTURE (MIDNIGHT EXECUTIVE & LIGHT THEMES)
// ============================================================================
class FinanceTheme {
  // Light Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Dark Palette (Midnight Executive)
  static const Color darkBg = Color(0xFF0B0F19);
  static const Color darkCard = Color(0xFF131B2E);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Semantic Accents
  static const Color emerald = Color(0xFF10B981); // Kirim / Tushum
  static const Color rose = Color(0xFFEF4444);    // Chiqim / Xarajat
  static const Color sky = Color(0xFF0284C7);     // Balans / Aktivlar
  static const Color amber = Color(0xFFF59E0B);   // Nasiyalar / Qarz
  static const Color purple = Color(0xFF8B5CF6);  // AI & Automation

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: emerald,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      dividerColor: lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: Color(0xFFD1FAE5), // Emerald 100
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: emerald,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      dividerColor: darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0F19),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF0B0F19),
        elevation: 0,
        indicatorColor: Color(0xFF064E3B), // Emerald 900
      ),
    );
  }
}

// Global theme notifier for real-time switching
final ValueNotifier<ThemeMode> financeThemeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

class FinanceApp extends StatelessWidget {
  const FinanceApp({
    super.key,
    required this.service,
    required this.profileManager,
    required this.pluginManager,
  });

  final FinanceService service;
  final ProfileManager profileManager;
  final PluginManager pluginManager;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: financeThemeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Moliya & Kassa',
          debugShowCheckedModeBanner: false,
          theme: FinanceTheme.light(),
          darkTheme: FinanceTheme.dark(),
          themeMode: currentMode,
          home: FinanceMainShell(
            service: service,
            profileManager: profileManager,
            pluginManager: pluginManager,
          ),
        );
      },
    );
  }
}

// ============================================================================
// MAIN SHELL (APP BAR, BOTTOM NAV, TABS)
// ============================================================================
class FinanceMainShell extends StatefulWidget {
  const FinanceMainShell({
    super.key,
    required this.service,
    required this.profileManager,
    required this.pluginManager,
  });

  final FinanceService service;
  final ProfileManager profileManager;
  final PluginManager pluginManager;

  @override
  State<FinanceMainShell> createState() => _FinanceMainShellState();
}

class _FinanceMainShellState extends State<FinanceMainShell> {
  int _currentIndex = 0;
  final SecurityManager _security = SecurityManager();

  @override
  void initState() {
    super.initState();
    widget.service.store.addListener(_onStoreChanged);
    _syncUser();
  }

  @override
  void dispose() {
    widget.service.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _syncUser() {
    final cur = widget.profileManager.current;
    final matched = SecurityManager.defaultAccounts.firstWhere(
      (a) => a.id == cur.id,
      orElse: () => UserAccount(id: cur.id, name: cur.name, role: cur.role, department: cur.department),
    );
    _security.currentUser = matched;
  }

  void _switchUser(UserProfile profile) async {
    await widget.profileManager.switchProfile(profile);
    _syncUser();
    if (mounted) setState(() {});
  }

  void _openAiTxAssistant(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FinanceAiAssistantSheet(
        pluginManager: widget.pluginManager,
        service: widget.service,
        security: _security,
        onTxCreated: () => setState(() => _currentIndex = 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = widget.service.store.all;
    final txCount = all.where((e) =>
      e.status == 'income' || e.status == 'tx_income' ||
      e.status == 'expense' || e.status == 'tx_expense' ||
      e.status == 'debt_active' || e.status == 'debt_closed'
    ).length;

    final userRole = _security.currentUser.role;
    final isDirector = userRole == UserRole.director;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: FinanceTheme.emerald.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: FinanceTheme.emerald, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moliya & Kassa',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                  ),
                ),
                Text(
                  ':8083 • ${widget.profileManager.current.name}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Theme switch button
          IconButton(
            icon: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
              size: 20,
              color: isDark ? Colors.amber : FinanceTheme.lightTextMuted,
            ),
            tooltip: isDark ? 'Kunduzgi rejim' : 'Tungi rejim',
            onPressed: () {
              financeThemeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          // AI Assistant button
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: FinanceTheme.purple, size: 20),
            tooltip: "O'zbekcha AI Kassa Amali",
            onPressed: () => _openAiTxAssistant(context),
          ),
          // RBAC Role Chip
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDirector
                  ? FinanceTheme.emerald.withValues(alpha: isDark ? 0.2 : 0.1)
                  : FinanceTheme.sky.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDirector
                    ? FinanceTheme.emerald.withValues(alpha: 0.4)
                    : FinanceTheme.sky.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: isDirector ? FinanceTheme.emerald : FinanceTheme.sky,
                  child: Text(
                    userRole.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  userRole.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDirector ? FinanceTheme.emerald : FinanceTheme.sky,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Kassa & Balans (Core List)
          FinanceCashflowTab(
            service: widget.service,
            security: _security,
            pluginManager: widget.pluginManager,
            onGoToCreate: () => setState(() => _currentIndex = 1),
            onOpenAi: () => _openAiTxAssistant(context),
          ),
          // Tab 1: Tezkor Kirim / Chiqim (Core Create Form)
          FinanceCreateTxTab(
            service: widget.service,
            security: _security,
            onTxCreated: () => setState(() => _currentIndex = 0),
          ),
          // Tab 2: Profil & Sozlamalar (Core Profile & Settings)
          FinanceProfileTab(
            service: widget.service,
            profileManager: widget.profileManager,
            pluginManager: widget.pluginManager,
            onProfileChanged: _switchUser,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: txCount > 0,
              label: Text('$txCount'),
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: 'Kassa & Balans',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Kirim / Chiqim',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FORMATTING HELPERS
// ============================================================================
String _formatMoney(num amount) {
  final str = amount.abs().toInt().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}

String _formatCompact(num amount) {
  if (amount.abs() >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  } else if (amount.abs() >= 1000) {
    return '${(amount / 1000).toStringAsFixed(0)}K';
  }
  return amount.toInt().toString();
}

// ============================================================================
// TAB 0: KASSA VA AMALLAR RO'YXATI (MOBILE FIRST EXECUTIVE LIST)
// ============================================================================
class FinanceCashflowTab extends StatefulWidget {
  const FinanceCashflowTab({
    super.key,
    required this.service,
    required this.security,
    required this.onGoToCreate,
    required this.onOpenAi,
    this.pluginManager,
  });

  final FinanceService service;
  final SecurityManager security;
  final VoidCallback onGoToCreate;
  final VoidCallback onOpenAi;
  final PluginManager? pluginManager;

  @override
  State<FinanceCashflowTab> createState() => _FinanceCashflowTabState();
}

class _FinanceCashflowTabState extends State<FinanceCashflowTab> {
  String _filter = 'all'; // all, income, expense, debt
  String _search = '';

  List<Entity> get _transactions {
    var items = widget.service.store.all.where((e) {
      if (_filter == 'income') {
        return e.status == 'income' || e.status == 'tx_income';
      }
      if (_filter == 'expense') {
        return e.status == 'expense' || e.status == 'tx_expense';
      }
      if (_filter == 'debt') {
        return e.status == 'debt_active' || e.status == 'debt_closed';
      }
      return e.status == 'income' || e.status == 'tx_income' ||
             e.status == 'expense' || e.status == 'tx_expense' ||
             e.status == 'debt_active' || e.status == 'debt_closed';
    }).toList();

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase().trim();
      items = items.where((e) {
        final name = e.name.toLowerCase();
        final cat = (e.meta['category'] ?? '').toString().toLowerCase();
        final note = (e.meta['note'] ?? '').toString().toLowerCase();
        final person = (e.meta['person'] ?? e.meta['from'] ?? e.meta['to'] ?? '').toString().toLowerCase();
        return name.contains(q) || cat.contains(q) || note.contains(q) || person.contains(q);
      }).toList();
    }

    // Newest first
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  void _deleteTx(Entity tx) {
    if (widget.security.currentUser.role != UserRole.director) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xatolik: Faqat direktor moliyaviy yozuvlarni o\'chira oladi.')),
      );
      return;
    }
    widget.service.store.delete(tx.id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'${tx.name}' yozuvi o'chirildi")),
      );
    }
  }

  void _quickPayDebt(Entity debt) async {
    final remaining = UzbekNlp.parseNumber(debt.meta['remaining']);
    final person = debt.meta['person'] ?? debt.name;

    final tool = widget.service.schema.tools.firstWhere((t) => t.name == 'finance_debt_close');
    await tool.handler({
      'id': debt.id,
      'person': person,
      'amount': remaining,
      'sync_cash': true,
      'note': "To'liq so'ndirildi",
    });

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$person ning qarzi to'liq so'ndirildi va kassaga kirim qilindi!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = widget.service.store.all;

    // Real-time zero-mock calculations
    num totalIncome = 0;
    num totalExpense = 0;
    num totalReceivables = 0;
    int incomeCount = 0;
    int expenseCount = 0;
    int debtCount = 0;

    for (final item in all) {
      final amount = UzbekNlp.parseNumber(item.meta['amount']);
      if (item.status == 'income' || item.status == 'tx_income') {
        totalIncome += amount;
        incomeCount++;
      } else if (item.status == 'expense' || item.status == 'tx_expense') {
        totalExpense += amount;
        expenseCount++;
      } else if (item.status == 'debt_active') {
        debtCount++;
        final rem = UzbekNlp.parseNumber(item.meta['remaining']);
        if (item.meta['type'] == 'receivable') {
          totalReceivables += rem;
        }
      } else if (item.status == 'debt_closed') {
        debtCount++;
      }
    }

    final balance = totalIncome - totalExpense;
    final profitMargin = totalIncome > 0 ? ((balance / totalIncome) * 100).toStringAsFixed(1) : '0.0';
    final isDirector = widget.security.currentUser.role == UserRole.director;
    final txs = _transactions;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            // Hero Executive Balance Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? FinanceTheme.darkCard : FinanceTheme.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: FinanceTheme.emerald.withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance, size: 16, color: FinanceTheme.emerald),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kassa Sof Qoldig\'i',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.auto_awesome, size: 18, color: FinanceTheme.purple),
                            tooltip: 'AI Kassa',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            onPressed: widget.onOpenAi,
                          ),
                          const SizedBox(width: 4),
                          FilledButton.icon(
                            onPressed: widget.onGoToCreate,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Amal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: FilledButton.styleFrom(
                              backgroundColor: FinanceTheme.emerald,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${balance >= 0 ? "+" : ""}${_formatMoney(balance)} so\'m',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: balance >= 0 ? FinanceTheme.emerald : FinanceTheme.rose,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: FinanceTheme.emerald.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_downward, color: FinanceTheme.emerald, size: 14),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kirim ($incomeCount)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                                    ),
                                  ),
                                  Text(
                                    '+${_formatMoney(totalIncome)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: FinanceTheme.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: FinanceTheme.rose.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_upward, color: FinanceTheme.rose, size: 14),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chiqim ($expenseCount)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                                      ),
                                    ),
                                    Text(
                                      '-${_formatMoney(totalExpense)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: FinanceTheme.rose,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // P&L & Receivables Micro-bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? FinanceTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up, size: 15, color: FinanceTheme.emerald),
                          const SizedBox(width: 6),
                          Text('Rentabellik: ', style: TextStyle(fontSize: 11, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted)),
                          Text('$profitMargin%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinanceTheme.emerald)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? FinanceTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.handshake_outlined, size: 15, color: FinanceTheme.amber),
                          const SizedBox(width: 6),
                          Text('Nasiyalar: ', style: TextStyle(fontSize: 11, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted)),
                          Text('${_formatCompact(totalReceivables)} UZS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FinanceTheme.amber)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Live Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Manba, toifa yoki izohni qidirish...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? FinanceTheme.darkCard : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                  ),
                ),
              ),
            ),

            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterPill('all', 'Barchasi', all.length, isDark),
                  const SizedBox(width: 6),
                  _buildFilterPill('income', 'Kirimlar', incomeCount, isDark, FinanceTheme.emerald),
                  const SizedBox(width: 6),
                  _buildFilterPill('expense', 'Chiqimlar', expenseCount, isDark, FinanceTheme.rose),
                  const SizedBox(width: 6),
                  _buildFilterPill('debt', 'Nasiyalar', debtCount, isDark, FinanceTheme.amber),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Transactions List
            Expanded(
              child: txs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? FinanceTheme.darkTextMuted : Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Hech qanday moliyaviy amal topilmadi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: widget.onGoToCreate,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Kassaga birinchi amalni yozish'),
                              style: FilledButton.styleFrom(backgroundColor: FinanceTheme.emerald),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: txs.length,
                      itemBuilder: (ctx, idx) {
                        final tx = txs[idx];
                        final isIncome = tx.status == 'income' || tx.status == 'tx_income';
                        final isExpense = tx.status == 'expense' || tx.status == 'tx_expense';
                        final isDebt = tx.status == 'debt_active' || tx.status == 'debt_closed';
                        final isClosedDebt = tx.status == 'debt_closed';

                        final amount = UzbekNlp.parseNumber(tx.meta['amount']);
                        final category = tx.meta['category'] ?? (isDebt ? 'Nasiya' : 'Umumiy');
                        final note = tx.meta['note'] ?? '';
                        final person = tx.meta['person'] ?? tx.meta['from'] ?? tx.meta['to'] ?? '';

                        Color cardAccent = isIncome
                            ? FinanceTheme.emerald
                            : (isExpense ? FinanceTheme.rose : FinanceTheme.amber);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? FinanceTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cardAccent.withValues(alpha: isDark ? 0.2 : 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_downward
                                          : (isExpense ? Icons.arrow_upward : Icons.handshake_outlined),
                                      color: cardAccent,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: cardAccent.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$category',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cardAccent),
                                              ),
                                            ),
                                            if (person.toString().isNotEmpty)
                                              Text(
                                                '• $person',
                                                style: TextStyle(fontSize: 11, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isIncome ? "+" : (isExpense ? "-" : "")}${_formatMoney(amount)} so\'m',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: cardAccent,
                                        ),
                                      ),
                                      if (isDebt) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          isClosedDebt ? 'Yopilgan ✅' : 'Qoldiq: ${_formatMoney(UzbekNlp.parseNumber(tx.meta['remaining']))}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isClosedDebt ? FinanceTheme.emerald : FinanceTheme.amber,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isDirector) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 16, color: isDark ? FinanceTheme.darkTextMuted : Colors.grey),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () => _deleteTx(tx),
                                    ),
                                  ],
                                ],
                              ),
                              if (note.toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 36),
                                  child: Text(
                                    'Izoh: $note',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                                    ),
                                  ),
                                ),
                              ],
                              if (isDebt && !isClosedDebt) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 36),
                                  child: SizedBox(
                                    height: 28,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _quickPayDebt(tx),
                                      icon: const Icon(Icons.check, size: 13),
                                      label: const Text('Qarzni So\'ndirish & Kassaga Kirim', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: FinanceTheme.emerald,
                                        side: const BorderSide(color: FinanceTheme.emerald),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String key, String label, int count, bool isDark, [Color? color]) {
    final isSelected = _filter == key;
    final pillColor = color ?? FinanceTheme.emerald;

    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? pillColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? FinanceTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? pillColor
                : (isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? pillColor : (isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? pillColor : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 1: TEZKOR KIRIM / CHIQIM / NASIYA (EXECUTIVE CREATE FORM)
// ============================================================================
class FinanceCreateTxTab extends StatefulWidget {
  const FinanceCreateTxTab({
    super.key,
    required this.service,
    required this.security,
    required this.onTxCreated,
  });

  final FinanceService service;
  final SecurityManager security;
  final VoidCallback onTxCreated;

  @override
  State<FinanceCreateTxTab> createState() => _FinanceCreateTxTabState();
}

class _FinanceCreateTxTabState extends State<FinanceCreateTxTab> {
  // Mode: 0 = Kirim, 1 = Chiqim, 2 = Nasiya
  int _mode = 0;

  final _amountController = TextEditingController(text: '5000000');
  final _sourceController = TextEditingController(text: 'Akfa Korxona');
  final _noteController = TextEditingController();
  String _selectedCategory = 'savdo';
  String _debtType = 'receivable'; // receivable (bizga) or payable (bizdan)

  final List<String> _incomeCategories = ['savdo', 'xizmat', 'kash', 'qarz_qaytarish', 'boshqa'];
  final List<String> _expenseCategories = ['ijara', 'oylik', 'ta\'minot', 'kommunal', 'marketing', 'boshqa'];
  final List<String> _debtCategories = ['mahsulot_nasiya', 'xomashyo_qarz', 'hamkor_nasiya', 'boshqa'];

  void _setPreset(int mode, String name, String cat, String amount) {
    setState(() {
      _mode = mode;
      _sourceController.text = name;
      _selectedCategory = cat;
      _amountController.text = amount;
    });
  }

  void _save() async {
    final source = _sourceController.text.trim();
    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, manba yoki maqsad nomini kiriting.')),
      );
      return;
    }

    final amount = UzbekNlp.parseNumber(_amountController.text.trim());
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, to\'g\'ri summani kiriting.')),
      );
      return;
    }

    final note = _noteController.text.trim();
    final user = widget.security.currentUser.name;

    if (_mode == 0) {
      // Kirim
      final tool = widget.service.schema.tools.firstWhere((t) => t.name == 'finance_income');
      await tool.handler({
        'amount': amount,
        'from': source,
        'category': _selectedCategory,
        'note': note,
        'cashier': user,
      });
    } else if (_mode == 1) {
      // Chiqim
      final tool = widget.service.schema.tools.firstWhere((t) => t.name == 'finance_expense');
      await tool.handler({
        'amount': amount,
        'to': source,
        'category': _selectedCategory,
        'note': note,
        'authorized_by': user,
      });
    } else {
      // Nasiya / Qarz
      final tool = widget.service.schema.tools.firstWhere((t) => t.name == 'finance_debt_add');
      await tool.handler({
        'person': source,
        'amount': amount,
        'type': _debtType,
        'note': note.isNotEmpty ? note : 'Nasiya shartnomasi',
      });
    }

    if (mounted) {
      final label = _mode == 0 ? "Kirim" : (_mode == 1 ? "Chiqim" : "Nasiya");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label muvaffaqiyatli saqlandi!')),
      );
      _noteController.clear();
      widget.onTxCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _mode == 0
        ? _incomeCategories
        : (_mode == 1 ? _expenseCategories : _debtCategories);

    Color activeColor = _mode == 0
        ? FinanceTheme.emerald
        : (_mode == 1 ? FinanceTheme.rose : FinanceTheme.amber);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Kassaga Yangi Amal Yozish',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kassaga kirim, xarajat chiqimi yoki nasiya qarzini qayd etish',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                ),
              ),
              const SizedBox(height: 16),

              // Segmented Action Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? FinanceTheme.darkCard : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                ),
                child: Row(
                  children: [
                    _buildModeButton(0, 'Kirim (+)', Icons.arrow_downward, FinanceTheme.emerald, isDark),
                    _buildModeButton(1, 'Chiqim (-)', Icons.arrow_upward, FinanceTheme.rose, isDark),
                    _buildModeButton(2, 'Nasiya', Icons.handshake_outlined, FinanceTheme.amber, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tezkor Namunalar
              Text(
                'Tezkor namunalar (1-klikda to\'ldirish):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _mode == 0
                    ? [
                        _buildPresetChip('⚡ Akfa Korxona (5 mln)', () => _setPreset(0, 'Akfa Korxona', 'savdo', '5000000'), isDark),
                        _buildPresetChip('📦 Savdo tushumi (3.5 mln)', () => _setPreset(0, 'Savdo tushumi', 'savdo', '3500000'), isDark),
                        _buildPresetChip('🛠 Xizmat haqi (1.2 mln)', () => _setPreset(0, 'Xizmat haqi', 'xizmat', '1200000'), isDark),
                      ]
                    : (_mode == 1
                        ? [
                            _buildPresetChip('🏢 Ofis ijarasi (2 mln)', () => _setPreset(1, 'Ofis ijarasi', 'ijara', '2000000'), isDark),
                            _buildPresetChip('💼 Xodimlar oyligi (4 mln)', () => _setPreset(1, 'Xodimlar oyligi', 'oylik', '4000000'), isDark),
                            _buildPresetChip('💡 Kommunal to\'lov (400 ming)', () => _setPreset(1, 'Kommunal to\'lov', 'kommunal', '400000'), isDark),
                          ]
                        : [
                            _buildPresetChip('🤝 Botir Nasiya (1.5 mln)', () => _setPreset(2, 'Botir', 'mahsulot_nasiya', '1500000'), isDark),
                            _buildPresetChip('🏭 Tech Star (3 mln)', () => _setPreset(2, 'Tech Star', 'hamkor_nasiya', '3000000'), isDark),
                          ]),
              ),
              const SizedBox(height: 16),

              // Summa Field
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
                decoration: InputDecoration(
                  labelText: 'Summa (so\'m) *',
                  labelStyle: TextStyle(color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted, fontSize: 13),
                  hintText: '5000000',
                  prefixIcon: Icon(Icons.monetization_on_outlined, color: activeColor),
                  suffixText: 'so\'m',
                  suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: activeColor),
                  filled: true,
                  fillColor: isDark ? FinanceTheme.darkCard : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Manba yoki Maqsad
              TextField(
                controller: _sourceController,
                style: TextStyle(color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
                decoration: InputDecoration(
                  labelText: _mode == 0
                      ? 'Kimdan / Manba nomi *'
                      : (_mode == 1 ? 'Kimgadir / Xarajat maqsadi *' : 'Mijoz yoki Qarzdor nomi *'),
                  labelStyle: TextStyle(color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted, fontSize: 13),
                  hintText: _mode == 0 ? 'Masalan: Akfa Korxona' : (_mode == 1 ? 'Masalan: Ofis binosi egasi' : 'Masalan: Botir'),
                  prefixIcon: Icon(Icons.person_pin_outlined, color: activeColor),
                  filled: true,
                  fillColor: isDark ? FinanceTheme.darkCard : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Nasiya turi (agar Nasiya tanlangan bo'lsa)
              if (_mode == 2) ...[
                Text(
                  'Nasiya yo\'nalishi:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Olinadigan (Debitorlik)'),
                        selected: _debtType == 'receivable',
                        onSelected: (val) {
                          if (val) setState(() => _debtType = 'receivable');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('To\'lanadigan (Kreditorlik)'),
                        selected: _debtType == 'payable',
                        onSelected: (val) {
                          if (val) setState(() => _debtType = 'payable');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Toifa tanlash
              Text(
                'Toifa:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    selectedColor: activeColor.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? activeColor : (isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Qo'shimcha Izoh
              TextField(
                controller: _noteController,
                style: TextStyle(color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
                decoration: InputDecoration(
                  labelText: 'Qo\'shimcha izoh (ixtiyoriy)',
                  labelStyle: TextStyle(color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted, fontSize: 13),
                  hintText: 'Masalan: Shartnoma #104 yoki Chek raqami',
                  filled: true,
                  fillColor: isDark ? FinanceTheme.darkCard : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Big Action Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: Icon(_mode == 0 ? Icons.arrow_downward : (_mode == 1 ? Icons.arrow_upward : Icons.handshake_outlined)),
                  label: Text(
                    _mode == 0
                        ? 'Kassaga Kirim Qilish'
                        : (_mode == 1 ? 'Kassadan Chiqim Qilish' : 'Nasiyani Qayd Etish'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: activeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(int index, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _mode == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _mode = index;
          _selectedCategory = index == 0 ? 'savdo' : (index == 1 ? 'ijara' : 'mahsulot_nasiya');
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.3 : 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? color : (isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : (isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, bool isDark) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      backgroundColor: isDark ? FinanceTheme.darkCard : Colors.white,
      side: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
    );
  }
}

// ============================================================================
// TAB 2: PROFIL & SOZLAMALAR (ZERO MOCK EXECUTIVE PROFILE TAB)
// ============================================================================
class FinanceProfileTab extends StatefulWidget {
  const FinanceProfileTab({
    super.key,
    required this.service,
    required this.profileManager,
    required this.pluginManager,
    required this.onProfileChanged,
  });

  final FinanceService service;
  final ProfileManager profileManager;
  final PluginManager pluginManager;
  final ValueChanged<UserProfile> onProfileChanged;

  @override
  State<FinanceProfileTab> createState() => _FinanceProfileTabState();
}

class _FinanceProfileTabState extends State<FinanceProfileTab> {
  int _subTabIndex = 0; // 0 = Rollar (RBAC), 1 = Plaginlar, 2 = Tizim

  UserProfile get _profile => widget.profileManager.current;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = widget.service.store.all;

    // Real-time zero-mock calculations
    num totalIncome = 0;
    num totalExpense = 0;
    int incomeCount = 0;
    int expenseCount = 0;

    for (final item in all) {
      final amount = UzbekNlp.parseNumber(item.meta['amount']);
      if (item.status == 'income' || item.status == 'tx_income') {
        totalIncome += amount;
        incomeCount++;
      } else if (item.status == 'expense' || item.status == 'tx_expense') {
        totalExpense += amount;
        expenseCount++;
      }
    }

    final balance = totalIncome - totalExpense;
    final profitMargin = totalIncome > 0 ? ((balance / totalIncome) * 100).toStringAsFixed(1) : '0.0';
    final plugins = widget.pluginManager.getAllPlugins();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FinanceTheme.darkCard : FinanceTheme.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: FinanceTheme.emerald,
                          child: Text(
                            _profile.name[0],
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _profile.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 16, color: FinanceTheme.emerald),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_profile.department} • Axion Finance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FinanceTheme.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _profile.role.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: FinanceTheme.emerald,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.email_outlined, size: 13, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
                            const SizedBox(width: 5),
                            Text(_profile.email, style: TextStyle(fontSize: 11, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 13, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
                            const SizedBox(width: 5),
                            Text(_profile.phone, style: TextStyle(fontSize: 11, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dark / Light Mode Switcher Tile
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDark ? Icons.nightlight_round : Icons.wb_sunny,
                                size: 16,
                                color: isDark ? Colors.amber : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isDark ? 'Tungi rejim (Dark Mode)' : 'Kunduzgi rejim (Light Mode)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: isDark,
                            activeThumbColor: FinanceTheme.emerald,
                            onChanged: (val) {
                              financeThemeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 Real-time Dynamic Metrics Cards (Zero Mock)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Kassa Balansi',
                      '${balance >= 0 ? "+" : ""}${_formatCompact(balance)} UZS',
                      'Mavjud sof balans',
                      Icons.account_balance_wallet_outlined,
                      balance >= 0 ? FinanceTheme.emerald : FinanceTheme.rose,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Jami Kirim',
                      '+${_formatCompact(totalIncome)} UZS',
                      '$incomeCount ta operatsiya',
                      Icons.arrow_downward,
                      FinanceTheme.emerald,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Jami Chiqim',
                      '-${_formatCompact(totalExpense)} UZS',
                      '$expenseCount ta xarajat',
                      Icons.arrow_upward,
                      FinanceTheme.rose,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Rentabellik',
                      '$profitMargin%',
                      'P&L samaradorlik',
                      Icons.trending_up,
                      FinanceTheme.sky,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Segmented Tabs: Rollar, Plaginlar, Tizim
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? FinanceTheme.darkCard : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                ),
                child: Row(
                  children: [
                    _buildSubTabButton(0, 'Rollar', Icons.badge_outlined, isDark),
                    _buildSubTabButton(1, 'Plaginlar (${plugins.length})', Icons.extension_outlined, isDark),
                    _buildSubTabButton(2, 'Tizim', Icons.dns_outlined, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Sub-tab 0: Rollar (RBAC)
              if (_subTabIndex == 0) ...[
                Text(
                  'Foydalanuvchi va Rolni Tanlash (RBAC)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tizim sinovi uchun istalgan akkauntga o\'tishingiz mumkin. Ruxsatlar darhol moslashadi.',
                  style: TextStyle(fontSize: 11, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
                ),
                const SizedBox(height: 10),
                Column(
                  children: UserProfile.defaultProfiles.map((p) {
                    final isCurrent = p.id == _profile.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? FinanceTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? FinanceTheme.emerald
                              : (isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isCurrent
                                ? FinanceTheme.emerald
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            child: Icon(
                              p.role == UserRole.director ? Icons.shield : Icons.person,
                              size: 16,
                              color: isCurrent ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                        color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.role.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent ? FinanceTheme.emerald : (isDark ? Colors.amber : Colors.blueGrey),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${p.department} • Axion ID: #${p.id}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: FinanceTheme.emerald,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Faol', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            )
                          else
                            TextButton(
                              onPressed: () {
                                widget.onProfileChanged(p);
                                setState(() {});
                              },
                              child: const Text('O\'tish', style: TextStyle(fontSize: 11, color: FinanceTheme.emerald)),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Sub-tab 1: Plaginlar
              if (_subTabIndex == 1) ...[
                Text(
                  'Plaginlar Markazi (Microkernel Engine)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kassa funksiyalarini plaginlar orqali kengaytiring va nazorat qiling.',
                  style: TextStyle(fontSize: 11, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
                ),
                const SizedBox(height: 10),
                Column(
                  children: plugins.map((plugin) {
                    final isConfigurable = plugin.id == 'plugin_ecosystem_bridge' || plugin.id == 'plugin_uzbek_ai';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? FinanceTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            plugin.id == 'plugin_uzbek_ai'
                                ? Icons.auto_awesome
                                : (plugin.id == 'plugin_pnl_analytics' ? Icons.pie_chart : Icons.extension_outlined),
                            color: FinanceTheme.emerald,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        plugin.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                                        ),
                                      ),
                                    ),
                                    if (isConfigurable)
                                      InkWell(
                                        onTap: () => _showPluginConfigDialog(context, plugin),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: FinanceTheme.emerald.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: FinanceTheme.emerald.withValues(alpha: 0.3)),
                                          ),
                                          child: const Text('Sozlash', style: TextStyle(fontSize: 10, color: FinanceTheme.emerald, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  plugin.description,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: plugin.isEnabled,
                            activeThumbColor: FinanceTheme.emerald,
                            onChanged: (val) async {
                              await widget.pluginManager.togglePlugin(plugin.id, val);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Sub-tab 2: Tizim
              if (_subTabIndex == 2) ...[
                Text(
                  'Tizim va Microservice Holati',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? FinanceTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                  ),
                  child: Column(
                    children: [
                      _buildServiceTile('Moliya Microservice Server', 'Port: :8083 • Faol (Online)', Icons.dns, FinanceTheme.emerald, isDark),
                      Divider(height: 16, color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                      _buildServiceTile('KPI & Baholash Tizimi', 'Port: :8081 • Ulangan', Icons.assessment_outlined, FinanceTheme.sky, isDark),
                      Divider(height: 16, color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                      _buildServiceTile('CRM & Savdo Voronkasi', 'Port: :8082 • Ulangan', Icons.hub_outlined, FinanceTheme.purple, isDark),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String subtext, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FinanceTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                ),
              ),
              Icon(icon, size: 15, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _subTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _subTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? FinanceTheme.emerald : (isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? (isDark ? Colors.white : Colors.black87) : (isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(String title, String subtitle, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText)),
              Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted)),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  void _showPluginConfigDialog(BuildContext context, EcosystemPlugin plugin) {
    showDialog(
      context: context,
      builder: (ctx) => FinancePluginConfigDialog(
        plugin: plugin,
        pluginManager: widget.pluginManager,
        onSaved: () => setState(() {}),
      ),
    );
  }
}

// ============================================================================
// PLAGIN: MOLIYA AI AMAL KIRITISH (EXECUTIVE MODAL BOTTOM SHEET)
// ============================================================================
class FinanceAiAssistantSheet extends StatefulWidget {
  const FinanceAiAssistantSheet({
    super.key,
    required this.pluginManager,
    required this.service,
    required this.security,
    required this.onTxCreated,
  });

  final PluginManager pluginManager;
  final FinanceService service;
  final SecurityManager security;
  final VoidCallback onTxCreated;

  @override
  State<FinanceAiAssistantSheet> createState() => _FinanceAiAssistantSheetState();
}

class _FinanceAiAssistantSheetState extends State<FinanceAiAssistantSheet> {
  final _controller = TextEditingController(
    text: "Alidan 5 000 000 so'm qarz qaytdi, kassaga kirim qil",
  );
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    final amount = UzbekNlp.parseNumber(text).toDouble();
    final lower = text.toLowerCase();
    final isExpense = lower.contains('chiqim') || lower.contains('xarajat') || lower.contains('to\'lov') || lower.contains('oylik') || lower.contains('ijara');

    String party = 'Kassir';
    final fromMatch = RegExp(r'([A-ZА-ЯЁ][a-zа-яё]+)dan').firstMatch(text);
    final toMatch = RegExp(r'([A-ZА-ЯЁ][a-zа-яё]+)ga').firstMatch(text);
    if (fromMatch != null) {
      party = fromMatch.group(1) ?? 'Mijoz';
    } else if (toMatch != null) {
      party = toMatch.group(1) ?? 'Xodim';
    }

    String category = 'boshqa';
    if (lower.contains('qarz') || lower.contains('nasiya')) {
      category = 'qarz_qaytarish';
    } else if (lower.contains('oylik') || lower.contains('bonus')) {
      category = 'Oylik/Bonus';
    } else if (lower.contains('ijara')) {
      category = 'ijara';
    } else if (lower.contains('savdo')) {
      category = 'savdo';
    }

    setState(() {
      _isLoading = false;
      _result = {
        'is_expense': isExpense,
        'amount': amount > 0 ? amount : 1000000.0,
        'party': party,
        'category': category,
        'note': text,
      };
    });
  }

  void _confirmAndCreate() async {
    if (_result == null) return;

    final isExpense = _result!['is_expense'] as bool;
    final toolName = isExpense ? 'finance_expense' : 'finance_income';
    final tool = widget.service.schema.tools.firstWhere((t) => t.name == toolName);

    if (isExpense) {
      await tool.handler({
        'amount': _result!['amount'],
        'to': _result!['party'],
        'category': _result!['category'],
        'note': _result!['note'],
        'authorized_by': widget.security.currentUser.name,
      });
    } else {
      await tool.handler({
        'amount': _result!['amount'],
        'from': _result!['party'],
        'category': _result!['category'],
        'note': _result!['note'],
        'cashier': widget.security.currentUser.name,
      });
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kassaga ${_result!['amount'].toInt()} so\'m ${isExpense ? "chiqim" : "kirim"} qilindi!')),
      );
      widget.onTxCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? FinanceTheme.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FinanceTheme.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: FinanceTheme.purple, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Kassa Amali Kiritish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText,
                        ),
                      ),
                      Text(
                        'Tabiiy tilda yozing, AI kirim yoki chiqimni avtomat aniqlaydi',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: isDark ? FinanceTheme.darkTextMuted : Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('⚡ Alidan 5 mln qarz qaytdi', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _controller.text = "Alidan 5 000 000 so'm qarz qaytdi, kassaga kirim qil";
                    _analyze();
                  },
                ),
                ActionChip(
                  label: const Text('🏢 Ofis ijarasiga 2 mln chiqim', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _controller.text = "Ofis ijarasi uchun 2 000 000 so'm xarajat chiqim yoz";
                    _analyze();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _controller,
              maxLines: 2,
              style: TextStyle(color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText),
              decoration: InputDecoration(
                hintText: 'Masalan: Alidan 5 mln qarz qaytdi yoki Ijaraga 2 mln chiqim',
                filled: true,
                fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? FinanceTheme.darkBorder : FinanceTheme.lightBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _analyze,
                icon: const Icon(Icons.psychology, size: 18),
                label: const Text('AI Kassa Buyrug\'ini Tahlil Qilish'),
                style: FilledButton.styleFrom(backgroundColor: FinanceTheme.purple),
              ),
            ),

            if (_result != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_result!['is_expense'] as bool) ? FinanceTheme.rose : FinanceTheme.emerald,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (_result!['is_expense'] as bool) ? Icons.arrow_upward : Icons.arrow_downward,
                          color: (_result!['is_expense'] as bool) ? FinanceTheme.rose : FinanceTheme.emerald,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          (_result!['is_expense'] as bool) ? 'Chiqim Operatsiyasi' : 'Kirim Operatsiyasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: (_result!['is_expense'] as bool) ? FinanceTheme.rose : FinanceTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text('• Kimga/Kimdan: ${_result!['party']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? FinanceTheme.darkText : FinanceTheme.lightText)),
                    const SizedBox(height: 4),
                    Text(
                      '• Summa: ${_formatMoney(_result!['amount'])} so\'m',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: (_result!['is_expense'] as bool) ? FinanceTheme.rose : FinanceTheme.emerald,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('• Toifa: ${_result!['category']}', style: TextStyle(fontSize: 12, color: isDark ? FinanceTheme.darkTextMuted : FinanceTheme.lightTextMuted)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton.icon(
                        onPressed: _confirmAndCreate,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Kassa Amalini Saqlash', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: (_result!['is_expense'] as bool) ? FinanceTheme.rose : FinanceTheme.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PLAGIN SOZLAMALARI DIALOGI (MOLIYA)
// ============================================================================
class FinancePluginConfigDialog extends StatefulWidget {
  const FinancePluginConfigDialog({
    super.key,
    required this.plugin,
    required this.pluginManager,
    required this.onSaved,
  });

  final EcosystemPlugin plugin;
  final PluginManager pluginManager;
  final VoidCallback onSaved;

  @override
  State<FinancePluginConfigDialog> createState() => _FinancePluginConfigDialogState();
}

class _FinancePluginConfigDialogState extends State<FinancePluginConfigDialog> {
  late final TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    final curLimit = widget.plugin.metadata['max_payout_limit'] ?? 3000000;
    _limitController = TextEditingController(text: '$curLimit');
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _save() async {
    final val = double.tryParse(_limitController.text.trim()) ?? 3000000.0;
    widget.plugin.metadata['max_payout_limit'] = val;
    await widget.pluginManager.registerPlugin(widget.plugin);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sync_alt, color: FinanceTheme.emerald),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.plugin.name, style: const TextStyle(fontSize: 16))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.plugin.description}\n\nKPI orqali tasdiqlangan bonuslar avtomatik shu chegaragacha kassadan chiqim qilinadi.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maksimal chiqim chegarasi (so\'m)',
              suffixText: 'so\'m',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: FinanceTheme.emerald),
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}

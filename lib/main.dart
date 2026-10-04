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
    return MaterialApp(
      title: 'Moliya & Kassa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: FinanceMainShell(
        service: service,
        profileManager: profileManager,
        pluginManager: pluginManager,
      ),
    );
  }
}

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
    final txCount = widget.service.store.all.where((e) => e.status == 'tx_income' || e.status == 'tx_expense').length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Moliya & Kassa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _security.currentUser.role == UserRole.director
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _security.currentUser.role == UserRole.director
                      ? Colors.green.shade300
                      : Colors.blue.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _security.currentUser.role == UserRole.director ? Icons.shield : Icons.person,
                    size: 13,
                    color: _security.currentUser.role == UserRole.director
                        ? Colors.green.shade800
                        : Colors.blue.shade800,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.profileManager.current.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _security.currentUser.role == UserRole.director
                          ? Colors.green.shade900
                          : Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Plagin: O'zbekcha AI Assistent
          if (widget.pluginManager.isPluginActive('plugin_uzbek_ai'))
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.purple),
              tooltip: "O'zbekcha AI Kassa Amali",
              onPressed: () => _openAiTxAssistant(context),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade400),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 13, color: Colors.green),
                SizedBox(width: 5),
                Text(':8083', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
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
          ),
          // Tab 1: Tezkor Kirim / Chiqim (Core Create Form)
          FinanceCreateTxTab(
            service: widget.service,
            security: _security,
            onTxCreated: () => setState(() => _currentIndex = 0),
          ),
          // Tab 2: Profil & Sozlamalar (Core Profile & Settings)
          FinanceProfileTab(
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
            label: 'Profil & Sozlamalar',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 0: KASSA VA AMALLAR RO'YXATI (CORE LIST)
// ============================================================================
class FinanceCashflowTab extends StatefulWidget {
  const FinanceCashflowTab({
    super.key,
    required this.service,
    required this.security,
    required this.onGoToCreate,
    this.pluginManager,
  });

  final FinanceService service;
  final SecurityManager security;
  final VoidCallback onGoToCreate;
  final PluginManager? pluginManager;

  @override
  State<FinanceCashflowTab> createState() => _FinanceCashflowTabState();
}

class _FinanceCashflowTabState extends State<FinanceCashflowTab> {
  String _filter = 'all'; // all, income, expense
  String _search = '';

  List<Entity> get _transactions {
    var items = widget.service.store.all
        .where((e) => e.status == 'tx_income' || e.status == 'tx_expense')
        .toList();

    if (_filter == 'income') {
      items = items.where((e) => e.status == 'tx_income').toList();
    } else if (_filter == 'expense') {
      items = items.where((e) => e.status == 'tx_expense').toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase().trim();
      items = items.where((e) {
        final name = e.name.toLowerCase();
        final cat = (e.meta['category'] ?? '').toString().toLowerCase();
        final note = (e.meta['note'] ?? '').toString().toLowerCase();
        return name.contains(q) || cat.contains(q) || note.contains(q);
      }).toList();
    }

    // Eng yangilari tepada
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final txs = _transactions;
    final all = widget.service.store.all;
    num totalIncome = 0;
    num totalExpense = 0;

    for (final item in all) {
      final amount = UzbekNlp.parseNumber(item.meta['amount']);
      if (item.status == 'tx_income') totalIncome += amount;
      if (item.status == 'tx_expense') totalExpense += amount;
    }
    final balance = totalIncome - totalExpense;
    final isDirector = widget.security.currentUser.role == UserRole.director;

    return Column(
      children: [
        // Live Kassa Balansi Kartasi
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kassa Sof Qoldig\'i',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${balance.toInt()} so\'m',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onGoToCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Amal kiritish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jami Kirim', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('+${totalIncome.toInt()} so\'m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward, color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jami Chiqim', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('-${totalExpense.toInt()} so\'m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Plagin: P&L Tahlil va Diagramma Slot
        if (widget.pluginManager?.isPluginActive('plugin_pnl_analytics') == true) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pie_chart, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    const Text(
                      'P&L Moliyaviy Tahlil (Plagin)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                    ),
                    const Spacer(),
                    Text(
                      'Rentabellik: ${totalIncome > 0 ? ((balance / totalIncome) * 100).toInt() : 0}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sof Foyda: ${balance.toInt()} so\'m',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),
                    Text(
                      'Xarajat nisbati: ${totalIncome > 0 ? ((totalExpense / totalIncome) * 100).toInt() : 0}%',
                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Qidirish va Filtrlar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Manba, toifa yoki izohni qidirish...',
                    hintStyle: const TextStyle(fontSize: 13),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _filter == 'all',
                label: const Text('Barchasi'),
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 4),
              FilterChip(
                selected: _filter == 'income',
                label: const Text('Kirimlar'),
                selectedColor: Colors.green.shade100,
                onSelected: (_) => setState(() => _filter = 'income'),
              ),
              const SizedBox(width: 4),
              FilterChip(
                selected: _filter == 'expense',
                label: const Text('Chiqimlar'),
                selectedColor: Colors.red.shade100,
                onSelected: (_) => setState(() => _filter = 'expense'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Tranzaksiyalar Ro'yxati
        Expanded(
          child: txs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Hech qanday moliyaviy amal topilmadi',
                        style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onGoToCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('Kassaga birinchi amalni yozish'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: txs.length,
                  itemBuilder: (ctx, idx) {
                    final tx = txs[idx];
                    final isIncome = tx.status == 'tx_income';
                    final amount = UzbekNlp.parseNumber(tx.meta['amount']);
                    final category = tx.meta['category'] ?? 'Umumiy';
                    final note = tx.meta['note'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        title: Text(tx.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          '$category ${note.isNotEmpty ? "• $note" : ""}',
                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isIncome ? "+" : "-"}${amount.toInt()} so\'m',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isIncome ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                            if (isDirector) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                onPressed: () => _deleteTx(tx),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 1: TEZKOR KIRIM / CHIQIM (CORE CREATE FORM)
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
  bool _isIncome = true;
  final _amountController = TextEditingController(text: '1000000');
  final _sourceController = TextEditingController(text: 'Savdo tushumi');
  final _noteController = TextEditingController();
  String _selectedCategory = 'savdo';

  final List<String> _incomeCategories = ['savdo', 'xizmat', 'kash', 'qarz_qaytarish', 'boshqa'];
  final List<String> _expenseCategories = ['ijara', 'oylik', 'ta\'minot', 'kommunal', 'marketing', 'boshqa'];

  void _addPreset(bool isInc, String name, String cat, String amount) {
    _isIncome = isInc;
    _sourceController.text = name;
    _selectedCategory = cat;
    _amountController.text = amount;
    setState(() {});
  }

  void _saveTx() async {
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

    final toolName = _isIncome ? 'finance_income' : 'finance_expense';
    final tool = widget.service.schema.tools.firstWhere((t) => t.name == toolName);

    if (_isIncome) {
      await tool.handler({
        'amount': amount,
        'from': source,
        'category': _selectedCategory,
        'note': _noteController.text.trim(),
      });
    } else {
      await tool.handler({
        'amount': amount,
        'to': source,
        'category': _selectedCategory,
        'note': _noteController.text.trim(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_isIncome ? "Kirim" : "Chiqim"} muvaffaqiyatli saqlandi!')),
      );
      _noteController.clear();
      widget.onTxCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isIncome ? _incomeCategories : _expenseCategories;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kassaga Yangi Amal Yozish',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kassaga kirim yoki xarajat chiqimini qayd etish',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Turi: Kirim yoki Chiqim
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() {
                    _isIncome = true;
                    _selectedCategory = 'savdo';
                    _sourceController.text = 'Savdo tushumi';
                  }),
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('Kirim (+)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isIncome ? Colors.green : Colors.grey.shade200,
                    foregroundColor: _isIncome ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() {
                    _isIncome = false;
                    _selectedCategory = 'ijara';
                    _sourceController.text = 'Ofis ijarasi';
                  }),
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Chiqim (-)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: !_isIncome ? Colors.red : Colors.grey.shade200,
                    foregroundColor: !_isIncome ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tezkor namunalar
          const Text('Tezkor namunalar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _isIncome
                ? [
                    ActionChip(
                      label: const Text('Savdo tushumi (5 mln)'),
                      onPressed: () => _addPreset(true, 'Savdo tushumi', 'savdo', '5000000'),
                    ),
                    ActionChip(
                      label: const Text('Xizmat haqi (1.2 mln)'),
                      onPressed: () => _addPreset(true, 'Xizmat haqi', 'xizmat', '1200000'),
                    ),
                  ]
                : [
                    ActionChip(
                      label: const Text('Ofis ijarasi (2 mln)'),
                      onPressed: () => _addPreset(false, 'Ofis ijarasi', 'ijara', '2000000'),
                    ),
                    ActionChip(
                      label: const Text('Xodimlar oyligi (4 mln)'),
                      onPressed: () => _addPreset(false, 'Xodimlar oyligi', 'oylik', '4000000'),
                    ),
                    ActionChip(
                      label: const Text('Kommunal to\'lov (400 ming)'),
                      onPressed: () => _addPreset(false, 'Kommunal to\'lov', 'kommunal', '400000'),
                    ),
                  ],
          ),
          const SizedBox(height: 16),

          // Summa
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Summa (so\'m) *',
              hintText: '1000000',
              prefixIcon: const Icon(Icons.monetization_on_outlined),
              border: const OutlineInputBorder(),
              suffixText: 'so\'m',
              suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // Manba yoki Maqsad
          TextField(
            controller: _sourceController,
            decoration: InputDecoration(
              labelText: _isIncome ? 'Kimdan / Manba nomi *' : 'Kimgadir / Xarajat maqsadi *',
              hintText: _isIncome ? 'Masalan: Botir (Savdo)' : 'Masalan: Ofis binosi egasi',
              prefixIcon: const Icon(Icons.person_pin_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Toifa tanlash
          const Text('Toifa:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: categories.map((cat) {
              final isSel = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _selectedCategory = cat);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Izoh
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Qo\'shimcha izoh (ixtiyoriy)',
              hintText: 'Masalan: Chek raqami yoki shartnoma',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Saqlash tugmasi
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _saveTx,
              icon: Icon(_isIncome ? Icons.arrow_downward : Icons.arrow_upward),
              label: Text(
                _isIncome ? 'Kassaga Kirim Qilish' : 'Kassadan Chiqim Qilish',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _isIncome ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 2: PROFIL & SOZLAMALAR (CORE PROFILE & SETTINGS)
// ============================================================================
class FinanceProfileTab extends StatefulWidget {
  const FinanceProfileTab({
    super.key,
    required this.profileManager,
    required this.pluginManager,
    required this.onProfileChanged,
  });

  final ProfileManager profileManager;
  final PluginManager pluginManager;
  final ValueChanged<UserProfile> onProfileChanged;

  @override
  State<FinanceProfileTab> createState() => _FinanceProfileTabState();
}

class _FinanceProfileTabState extends State<FinanceProfileTab> {
  UserProfile get _profile => widget.profileManager.current;

  @override
  Widget build(BuildContext context) {
    final plugins = widget.pluginManager.getAllPlugins();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profil Kartasi
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      _profile.name[0],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_profile.role.name.toUpperCase()} • ${_profile.department}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_profile.phone}  |  ${_profile.email}',
                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Foydalanuvchini Almashtirish (RBAC)
          const Text(
            'Foydalanuvchi va Rolni Tanlash (RBAC)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Column(
            children: UserProfile.defaultProfiles.map((p) {
              final isCurrent = p.id == _profile.id;
              return Card(
                elevation: 0,
                color: isCurrent ? Colors.green.shade50 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isCurrent ? Colors.green.shade300 : Colors.grey.shade200,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    p.role == UserRole.director ? Icons.shield : Icons.person,
                    color: isCurrent ? Colors.green : Colors.grey,
                  ),
                  title: Text(p.name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text('${p.role.name} • ${p.department}'),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  onTap: () {
                    widget.onProfileChanged(p);
                    setState(() {});
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Tizim & Server Holati
          const Text(
            'Tizim va Microservice Holati',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(Icons.dns, color: Colors.green),
                  title: Text('Moliya Microservice Server'),
                  subtitle: Text('Port: 8083  |  Holati: Faol (Online)'),
                ),
                Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.hub_outlined, color: Colors.teal),
                  title: Text('KPI & CRM Integratsiyasi'),
                  subtitle: Text('Portlar: :8081 (KPI), :8082 (CRM)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Plaginlar Markazi (Microkernel Plugin Registry)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Plaginlar Markazi (Microkernel Engine)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${plugins.where((p) => p.isEnabled).length} ta faol',
                  style: TextStyle(color: Colors.purple.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: plugins.map((plugin) {
                final isConfigurable = plugin.id == 'plugin_ecosystem_bridge' || plugin.id == 'plugin_uzbek_ai';
                return SwitchListTile(
                  dense: true,
                  secondary: Icon(
                    plugin.id == 'plugin_uzbek_ai'
                        ? Icons.auto_awesome
                        : (plugin.id == 'plugin_pnl_analytics' ? Icons.pie_chart : (plugin.id == 'plugin_debt_ledger' ? Icons.handshake : (plugin.id == 'plugin_ecosystem_bridge' ? Icons.sync_alt : Icons.extension_outlined))),
                    color: Colors.green.shade700,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(plugin.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      if (isConfigurable)
                        InkWell(
                          onTap: () => _showPluginConfigDialog(context, plugin),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune, size: 11, color: Colors.green),
                                SizedBox(width: 3),
                                Text('Sozlash', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(plugin.description, style: const TextStyle(fontSize: 11)),
                  value: plugin.isEnabled,
                  onChanged: (val) async {
                    await widget.pluginManager.togglePlugin(plugin.id, val);
                    setState(() {});
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
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
// PLAGIN: MOLIYA AI AMAL KIRITISH (MODAL BOTTOM SHEET)
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
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Kassa Amali Kiritish',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tabiiy tilda yozing, AI kirim yoki chiqimni avtomatik toifalaydi',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Alidan 5 mln qarz qaytdi', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _controller.text = "Alidan 5 000 000 so'm qarz qaytdi, kassaga kirim qil";
                    _analyze();
                  },
                ),
                ActionChip(
                  label: const Text('Ofis ijarasiga 2 mln chiqim', style: TextStyle(fontSize: 11)),
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
              decoration: InputDecoration(
                hintText: 'Masalan: Alidan 5 mln qarz qaytdi yoki Ijaraga 2 mln chiqim',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _analyze,
                icon: const Icon(Icons.psychology, size: 18),
                label: const Text('AI Kassa Buyrug\'ini Tahlil Qilish'),
                style: FilledButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ),

            if (_result != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: (_result!['is_expense'] as bool) ? Colors.red.shade50 : Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: (_result!['is_expense'] as bool) ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            (_result!['is_expense'] as bool) ? Icons.arrow_upward : Icons.arrow_downward,
                            color: (_result!['is_expense'] as bool) ? Colors.red : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (_result!['is_expense'] as bool) ? 'Chiqim Operatsiyasi' : 'Kirim Operatsiyasi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: (_result!['is_expense'] as bool) ? Colors.red.shade900 : Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text('• Kimga/Kimdan: ${_result!['party']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('• Summa: ${(_result!['amount'] as num).toInt()} so\'m', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: (_result!['is_expense'] as bool) ? Colors.red : Colors.green)),
                      const SizedBox(height: 4),
                      Text('• Toifa: ${_result!['category']}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: _confirmAndCreate,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Kassa Amalini Saqlash', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: (_result!['is_expense'] as bool) ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
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
          const Icon(Icons.sync_alt, color: Colors.green),
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
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}


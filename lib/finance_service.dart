import 'dart:io';
import 'package:be_core/be_core.dart';

/// Moliya va Kassa servisi:
/// Kassa operatsiyalari (Kirim, Chiqim), Nasiyalar va qarzlar (Debitorlik / Kreditorlik),
/// kassa balansi, P&L moliyaviy hisobot va boshqa dasturlar (KPI, CRM) bilan integratsiya.
class FinanceService {
  FinanceService(this.store);
  final StandardStore store;

  static const port = 8083;

  static Future<FinanceService> init([String? customPath]) async {
    final path = customPath ?? '${Directory.current.path}/finance_data.json';
    final store = await StandardStore.open(path);
    return FinanceService(store);
  }

  AppSchema get schema => AppSchema(
        app: 'finance',
        version: '1.1.0',
        description: 'Kassa operatsiyalari: kirim, chiqim, nasiya/qarzlar va sof balans',
        port: port,
        tools: [
          // 1. Kassaga kirim qilish
          ToolDef(
            name: 'finance_income',
            description: "Kassaga kirim / tushum qilish (masalan: Alidan 5 mln tushdi, savdodan)",
            params: {
              'amount': const ParamDef(type: 'number', description: 'Tushum summasi (so\'m)'),
              'from': const ParamDef(type: 'string', description: 'Kimdan yoki manba nomi', defaultValue: 'Mijoz'),
              'category': const ParamDef(type: 'string', description: 'Kategoriya (savdo, xizmat, kash, boshqa)', defaultValue: 'savdo'),
              'note': const ParamDef(type: 'string', description: 'Qo\'shimcha izoh', required: false, defaultValue: ''),
              'cashier': const ParamDef(type: 'string', description: 'Qabul qilgan kassir', required: false, defaultValue: 'Malika'),
            },
            handler: (p) async {
              final amount = UzbekNlp.parseNumber(p['amount']);
              if (amount <= 0) return ToolResult.err(error: "Kirim summasi 0 dan katta bo'lishi kerak.");

              final from = '${p['from'] ?? 'Noma\'lum'}'.trim();
              final category = '${p['category'] ?? 'savdo'}'.trim();
              final note = '${p['note'] ?? ''}'.trim();
              final cashier = '${p['cashier'] ?? 'Malika'}'.trim();

              final entity = store.insert(
                name: 'Kirim: $from',
                status: 'income',
                meta: {
                  'amount': amount,
                  'from': from,
                  'category': category,
                  'note': note,
                  'cashier': cashier,
                  'created_at': DateTime.now().toIso8601String(),
                },
              );

              return ToolResult.ok(
                action: 'finance_income',
                data: entity.toJson(),
                message: "$from dan ${amount.toInt()} so'm kirim qilindi ($category).",
              );
            },
          ),

          // 2. Chiqim qilish
          ToolDef(
            name: 'finance_expense',
            description: "Kassadan xarajat / chiqim qilish (masalan: oylik, ijara, xarid)",
            params: {
              'amount': const ParamDef(type: 'number', description: 'Chiqim summasi (so\'m)'),
              'to': const ParamDef(type: 'string', description: 'Kimga yoki nima uchun', defaultValue: 'Xarajat'),
              'category': const ParamDef(type: 'string', description: 'Kategoriya (ijara, Oylik/Bonus, xomashyo, soliq, kommunal)', defaultValue: 'xarajat'),
              'note': const ParamDef(type: 'string', description: 'Izoh', required: false, defaultValue: ''),
              'authorized_by': const ParamDef(type: 'string', description: 'Ruxsat bergan rahbar', required: false, defaultValue: 'Direktor'),
            },
            handler: (p) async {
              final amount = UzbekNlp.parseNumber(p['amount']);
              if (amount <= 0) return ToolResult.err(error: "Chiqim summasi 0 dan katta bo'lishi kerak.");

              final to = '${p['to'] ?? 'Xarajat'}'.trim();
              final category = '${p['category'] ?? 'xarajat'}'.trim();
              final note = '${p['note'] ?? ''}'.trim();
              final authBy = '${p['authorized_by'] ?? 'Direktor'}'.trim();

              final entity = store.insert(
                name: 'Chiqim: $to',
                status: 'expense',
                meta: {
                  'amount': amount,
                  'to': to,
                  'category': category,
                  'note': note,
                  'authorized_by': authBy,
                  'created_at': DateTime.now().toIso8601String(),
                },
              );

              return ToolResult.ok(
                action: 'finance_expense',
                data: entity.toJson(),
                message: "$to uchun ${amount.toInt()} so'm chiqim qilindi ($category).",
              );
            },
          ),

          // 3. Nasiya yoki qarz yozish
          ToolDef(
            name: 'finance_debt_add',
            description: "Qarz yoki nasiya yozish (bizga qarz yoki bizning qarzimiz)",
            params: {
              'person': const ParamDef(type: 'string', description: 'Shaxs yoki kompaniya nomi'),
              'amount': const ParamDef(type: 'number', description: 'Qarz summasi'),
              'type': const ParamDef(type: 'string', description: 'receivable (bizga olinadigan nasiya) | payable (biz to\'laydigan qarzimiz)', defaultValue: 'receivable'),
              'due_date': const ParamDef(type: 'string', description: 'Qaytarish muddati', required: false),
              'note': const ParamDef(type: 'string', description: 'Izoh', required: false, defaultValue: ''),
            },
            handler: (p) async {
              final person = '${p['person']}'.trim();
              final amount = UzbekNlp.parseNumber(p['amount']);
              if (person.isEmpty) return ToolResult.err(error: "Shaxs ismi ko'rsatilmadi.");
              if (amount <= 0) return ToolResult.err(error: "Summa 0 dan katta bo'lishi kerak.");

              final type = '${p['type'] ?? 'receivable'}'.toLowerCase().trim();
              final dueDate = p['due_date'] != null ? UzbekNlp.parseDate(p['due_date']) : null;
              final note = '${p['note'] ?? ''}'.trim();

              final meta = <String, dynamic>{
                'person': person,
                'amount': amount,
                'type': type,
                'paid': 0,
                'remaining': amount,
                'note': note,
                'created_at': DateTime.now().toIso8601String(),
              };
              if (dueDate != null) meta['due_date'] = dueDate;

              final entity = store.insert(
                name: 'Qarz: $person',
                status: 'debt_active',
                meta: meta,
              );

              final typeLabel = type == 'receivable' ? 'olinishi kerak bo\'lgan nasiya' : 'berilishi kerak bo\'lgan qarz';
              return ToolResult.ok(
                action: 'finance_debt_add',
                data: entity.toJson(),
                message: "$person ga ${amount.toInt()} so'm $typeLabel yozildi.",
              );
            },
          ),

          // 4. Qarzni to'lash / so'ndirish
          ToolDef(
            name: 'finance_debt_close',
            description: "Qarzni to'liq yoki qisman to'lash va kassa balansiga kiritish",
            params: {
              'person': const ParamDef(type: 'string', description: 'Shaxs ismi yoki ID'),
              'amount': const ParamDef(type: 'number', description: 'To\'langan summa (bo\'sh bo\'lsa to\'liq yopiladi)', required: false),
              'sync_cash': const ParamDef(type: 'boolean', description: 'Kassa balansiga avtomatik kirim/chiqim qilish', defaultValue: true),
              'note': const ParamDef(type: 'string', description: 'To\'lov izohi', required: false),
            },
            handler: (p) async {
              final person = p['id'] ?? p['person'] ?? p['name'];
              final debtEntity = store.find('$person') ??
                  store.filter(status: 'debt_active', predicate: (e) {
                    final match = UzbekNlp.matchEntity('$person', [e.name, '${e.meta['person']}']);
                    return match != null;
                  }).firstOrNull;

              if (debtEntity == null) {
                return ToolResult.err(error: "'$person' bo'yicha faol qarz topilmadi.");
              }

              final total = UzbekNlp.parseNumber(debtEntity.meta['amount']);
              final currentPaid = UzbekNlp.parseNumber(debtEntity.meta['paid'] ?? 0);
              final remaining = total - currentPaid;

              final paidDelta = p['amount'] != null ? UzbekNlp.parseNumber(p['amount']) : remaining;
              if (paidDelta <= 0) return ToolResult.err(error: "To'lov summasi 0 dan katta bo'lishi kerak.");

              final newPaid = currentPaid + paidDelta;
              final newRemaining = (total - newPaid) > 0 ? (total - newPaid) : 0;
              final isFullyPaid = newRemaining <= 0;

              final updated = store.update(
                debtEntity.id,
                status: isFullyPaid ? 'debt_closed' : 'debt_active',
                metaPatch: {
                  'paid': newPaid,
                  'remaining': newRemaining,
                  'last_payment_at': DateTime.now().toIso8601String(),
                },
              );

              // Agar kassa bilan sinxronlash yoqilgan bo'lsa:
              final syncCash = p['sync_cash'] != false && '${p['sync_cash']}'.toLowerCase() != 'false';
              if (syncCash) {
                final isReceivable = debtEntity.meta['type'] == 'receivable';
                final personName = debtEntity.meta['person'] ?? debtEntity.name;
                if (isReceivable) {
                  // Bizga qarzini qaytardi -> Kassa kirim
                  store.insert(
                    name: 'Kirim (Qarz qaytdi): $personName',
                    status: 'income',
                    meta: {
                      'amount': paidDelta,
                      'from': personName,
                      'category': 'Qarz qaytishi',
                      'note': p['note'] ?? 'Nasiya to\'lovi',
                      'created_at': DateTime.now().toIso8601String(),
                    },
                  );
                } else {
                  // Biz qarzimizni to'ladik -> Kassa chiqim
                  store.insert(
                    name: 'Chiqim (Qarz to\'landi): $personName',
                    status: 'expense',
                    meta: {
                      'amount': paidDelta,
                      'to': personName,
                      'category': 'Qarz to\'lovi',
                      'note': p['note'] ?? 'Qarz so\'ndirish',
                      'created_at': DateTime.now().toIso8601String(),
                    },
                  );
                }
              }

              final personName = debtEntity.meta['person'] ?? debtEntity.name;
              return ToolResult.ok(
                action: 'finance_debt_close',
                data: updated.toJson(),
                message: isFullyPaid
                    ? "$personName ning qarzi TO'LIQ yopildi (${paidDelta.toInt()} so'm to'landi)."
                    : "$personName ${paidDelta.toInt()} so'm to'ladi. Qoldiq: ${newRemaining.toInt()} so'm.",
              );
            },
          ),

          // 5. Kassa balansi
          ToolDef(
            name: 'finance_balance',
            description: "Joriy kassa qoldig'i (Kirimlar - Chiqimlar = Sof balans)",
            params: {},
            handler: (p) async {
              final incomes = store.filter(status: 'income').fold<num>(0, (sum, e) => sum + UzbekNlp.parseNumber(e.meta['amount']));
              final expenses = store.filter(status: 'expense').fold<num>(0, (sum, e) => sum + UzbekNlp.parseNumber(e.meta['amount']));
              final balance = incomes - expenses;

              return ToolResult.ok(
                action: 'finance_balance',
                data: {
                  'total_income': incomes,
                  'total_expense': expenses,
                  'balance': balance,
                },
                message: "Kassa holati: Jami kirim: ${incomes.toInt()} so'm, Chiqim: ${expenses.toInt()} so'm, Sof qoldiq: ${balance.toInt()} so'm.",
              );
            },
          ),

          // 6. Qarzlar ro'yxati
          ToolDef(
            name: 'finance_debt_list',
            description: "Barcha faol va yopilgan qarzlar/nasiyalar ro'yxati",
            params: {
              'type': const ParamDef(type: 'string', description: 'receivable | payable bo\'yicha filtr', required: false),
              'status': const ParamDef(type: 'string', description: 'active | closed bo\'yicha filtr', required: false),
            },
            handler: (p) async {
              final typeFilter = p['type']?.toString().toLowerCase().trim();
              final statusFilter = p['status']?.toString().toLowerCase().trim();

              var debts = store.all.where((e) => e.status == 'debt_active' || e.status == 'debt_closed').toList();
              if (typeFilter != null && typeFilter.isNotEmpty) {
                debts = debts.where((e) => '${e.meta['type']}'.toLowerCase() == typeFilter).toList();
              }
              if (statusFilter != null && statusFilter.isNotEmpty) {
                final targetStatus = statusFilter == 'closed' ? 'debt_closed' : 'debt_active';
                debts = debts.where((e) => e.status == targetStatus).toList();
              }

              return ToolResult.ok(
                action: 'finance_debt_list',
                data: debts.map((e) => e.toJson()).toList(),
                message: "Jami ${debts.length} ta qarz yozuvi topildi.",
              );
            },
          ),

          // 7. Amallar tarixi
          ToolDef(
            name: 'finance_history',
            description: "Kassadagi oxirgi amallar (kirim va chiqimlar xronologiyasi)",
            params: {
              'limit': const ParamDef(type: 'number', description: 'Yozuvlar soni', defaultValue: 30),
            },
            handler: (p) async {
              final limit = UzbekNlp.parseNumber(p['limit'] ?? 30).toInt();
              final history = store.all.reversed
                  .where((e) => e.status == 'income' || e.status == 'expense')
                  .take(limit)
                  .map((e) => e.toJson())
                  .toList();

              return ToolResult.ok(
                action: 'finance_history',
                data: history,
                message: "Oxirgi ${history.length} ta kassa amali chiqarildi.",
              );
            },
          ),

          // 8. Moliyaviy umumiy hisobot (P&L va Qarzdorlik tahlili)
          ToolDef(
            name: 'finance_report',
            description: "To'liq moliyaviy hisobot: tushum, xarajat, sof foyda va toifalar tahlili",
            params: {},
            handler: (p) async {
              final incomes = store.filter(status: 'income');
              final expenses = store.filter(status: 'expense');
              final activeDebts = store.filter(status: 'debt_active');

              num totalIncome = 0;
              final Map<String, num> incCategories = {};
              for (final inc in incomes) {
                final amt = UzbekNlp.parseNumber(inc.meta['amount']);
                totalIncome += amt;
                final cat = '${inc.meta['category'] ?? 'boshqa'}';
                incCategories[cat] = (incCategories[cat] ?? 0) + amt;
              }

              num totalExpense = 0;
              final Map<String, num> expCategories = {};
              for (final exp in expenses) {
                final amt = UzbekNlp.parseNumber(exp.meta['amount']);
                totalExpense += amt;
                final cat = '${exp.meta['category'] ?? 'boshqa'}';
                expCategories[cat] = (expCategories[cat] ?? 0) + amt;
              }

              final receivables = activeDebts
                  .where((e) => e.meta['type'] == 'receivable')
                  .fold<num>(0, (sum, e) => sum + UzbekNlp.parseNumber(e.meta['remaining']));
              final payables = activeDebts
                  .where((e) => e.meta['type'] == 'payable')
                  .fold<num>(0, (sum, e) => sum + UzbekNlp.parseNumber(e.meta['remaining']));

              final netProfit = totalIncome - totalExpense;

              return ToolResult.ok(
                action: 'finance_report',
                data: {
                  'total_income': totalIncome,
                  'total_expense': totalExpense,
                  'net_profit': netProfit,
                  'receivables_debt': receivables,
                  'payables_debt': payables,
                  'income_categories': incCategories,
                  'expense_categories': expCategories,
                },
                message: "Moliyaviy xulosa: Tushum: ${totalIncome.toInt()} so'm, Xarajat: ${totalExpense.toInt()} so'm, Sof foyda: ${netProfit.toInt()} so'm, Tashqi nasiyalar: ${receivables.toInt()} so'm.",
              );
            },
          ),

          // 9. Yozuvni o'chirish
          ToolDef(
            name: 'finance_delete',
            description: "Kassa yoki qarz yozuvini o'chirish (Faqat rahbar ruxsati bilan)",
            params: {
              'id': const ParamDef(type: 'string', description: 'Yozuv ID yoki nomi'),
            },
            handler: (p) async {
              final key = p['id'] ?? p['name'];
              final existing = store.find('$key');
              if (existing == null) return ToolResult.err(error: "'$key' moliyaviy yozuv topilmadi.");

              final removed = store.delete(existing.id);
              return ToolResult.ok(
                action: 'finance_delete',
                data: removed.toJson(),
                message: "'${removed.name}' moliyaviy yozuvi o'chirildi.",
              );
            },
          ),
        ],
      );
}

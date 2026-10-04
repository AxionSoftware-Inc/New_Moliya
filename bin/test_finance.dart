// ignore_for_file: avoid_print
import 'dart:io';
import 'package:be_core/be_core.dart';
import 'package:finance_app/finance_service.dart';

void main() async {
  print('================================================================');
  print('   MOLIYA VA KASSA: TO\'LIQ TEST SINOVI (RBAC & P&L WORKFLOW)');
  print('================================================================\n');

  final tempDir = Directory.systemTemp.createTempSync('finance_test_');
  final dbPath = '${tempDir.path}/finance_test_data.json';
  int passed = 0;
  int failed = 0;

  void assertTest(String desc, bool condition) {
    if (condition) {
      print('  [PASS] $desc');
      passed++;
    } else {
      print('  [FAIL] $desc');
      failed++;
    }
  }

  try {
    final service = await FinanceService.init(dbPath);
    final schema = service.schema;
    final security = SecurityManager();
    final director = SecurityManager.defaultAccounts.firstWhere((a) => a.role == UserRole.director);
    final cashier = SecurityManager.defaultAccounts.firstWhere((a) => a.role == UserRole.cashier);
    final employee = SecurityManager.defaultAccounts.firstWhere((a) => a.role == UserRole.employee);

    // 1. Kassaga kirim qilish (finance_income)
    final incTool = schema.tools.firstWhere((t) => t.name == 'finance_income');
    final incRes = await incTool.handler({
      'amount': 5000000,
      'from': 'Ali Savdo',
      'category': 'savdo',
      'note': 'Mahsulot sotuvidan tushum',
      'cashier': 'Malika',
    });
    assertTest("1.1. Kassaga 5 000 000 so'm kirim qilindi", incRes.success);
    final incEntity = service.store.filter(status: 'income').first;
    assertTest("1.2. Kirim summasi to'g'ri saqlandi", incEntity.meta['amount'] == 5000000);
    assertTest("1.3. Kassir Malika qayd etildi", incEntity.meta['cashier'] == 'Malika');

    // 2. Kassadan chiqim qilish (finance_expense)
    final expTool = schema.tools.firstWhere((t) => t.name == 'finance_expense');
    final expRes = await expTool.handler({
      'amount': 2000000,
      'to': 'Ofis ijarasi',
      'category': 'ijara',
      'note': 'Oktyabr oyi uchun ijara',
      'authorized_by': 'Karim',
    });
    assertTest("2.1. Kassadan 2 000 000 so'm chiqim qilindi", expRes.success);

    // 3. Kassa balansi tekshiruvi (finance_balance)
    final balTool = schema.tools.firstWhere((t) => t.name == 'finance_balance');
    final balRes = await balTool.handler({});
    assertTest("3.1. Kassa balansi muvaffaqiyatli hisoblandi", balRes.success);
    final balData = balRes.data as Map;
    assertTest("3.2. Jami kirim 5 mln so'm", balData['total_income'] == 5000000);
    assertTest("3.3. Jami chiqim 2 mln so'm", balData['total_expense'] == 2000000);
    assertTest("3.4. Sof kassa qoldig'i 3 mln so'm", balData['balance'] == 3000000);

    // 4. Nasiya berish (receivable)
    final debtTool = schema.tools.firstWhere((t) => t.name == 'finance_debt_add');
    final debtRes = await debtTool.handler({
      'person': 'Botir',
      'amount': 1500000,
      'type': 'receivable',
      'due_date': '3 kunda',
      'note': 'Qurilish materiallari uchun nasiya',
    });
    assertTest("4.1. Botirga 1.5 mln nasiya yozildi", debtRes.success);
    final debtEntity = service.store.find('Qarz: Botir')!;
    assertTest("4.2. Qarz turi 'receivable'", debtEntity.meta['type'] == 'receivable');
    assertTest("4.3. Qoldiq summa 1 500 000 so'm", debtEntity.meta['remaining'] == 1500000);

    // 5. Qarzni qisman so'ndirish va kassa bilan avtomat sinxronlash
    final debtCloseTool = schema.tools.firstWhere((t) => t.name == 'finance_debt_close');
    final partialCloseRes = await debtCloseTool.handler({
      'person': 'Botir',
      'amount': 500000,
      'sync_cash': true,
      'note': 'Birinchi qism to\'landi',
    });
    assertTest("5.1. Qisman 500 000 so'm to'lov qabul qilindi", partialCloseRes.success);
    final updatedDebt = service.store.find('Qarz: Botir')!;
    assertTest("5.2. Qarz qoldig'i 1 000 000 so'm qoldi", updatedDebt.meta['remaining'] == 1000000);
    assertTest("5.3. Qarz holati hali ham 'debt_active'", updatedDebt.status == 'debt_active');

    // 5.4. Kassa avtomat sinxronlanganini tekshirish (Kassa kirimlariga 500 ming qo'shilgan bo'lishi kerak!)
    final balRes2 = await balTool.handler({});
    final balData2 = balRes2.data as Map;
    assertTest("5.4. Kassa qoldig'i avtomatik 3.5 mln ga oshdi (Qarz to'lovi kirdi)", balData2['balance'] == 3500000);

    // 6. Qarzni to'liq yopish
    final fullCloseRes = await debtCloseTool.handler({
      'person': 'Botir',
      'amount': 1000000,
      'sync_cash': true,
    });
    assertTest("6.1. Qarz to'liq yopildi", fullCloseRes.success);
    final closedDebt = service.store.find('Qarz: Botir')!;
    assertTest("6.2. Qarz holati 'debt_closed' bo'ldi", closedDebt.status == 'debt_closed');
    assertTest("6.3. Qoldiq 0 so'm bo'ldi", closedDebt.meta['remaining'] == 0);

    // 7. Moliyaviy umumiy hisobot (finance_report)
    final repTool = schema.tools.firstWhere((t) => t.name == 'finance_report');
    final repRes = await repTool.handler({});
    assertTest("7.1. Moliyaviy hisobot tayyorlandi", repRes.success);
    final repData = repRes.data as Map;
    assertTest("7.2. Jami kirim 6.5 mln so'm (5 mln savdo + 1.5 mln qarz qaytishi)", repData['total_income'] == 6500000);
    assertTest("7.3. Jami xarajat 2 mln so'm", repData['total_expense'] == 2000000);
    assertTest("7.4. Sof foyda 4.5 mln so'm", repData['net_profit'] == 4500000);
    assertTest("7.5. Toifalar bo'yicha xarajatda 'ijara' 2 mln qayd etildi", repData['expense_categories']['ijara'] == 2000000);

    // 8. RBAC Xavfsizlik tekshiruvi
    assertTest("8.1. Kassir kassa amallarini bajara oladi", cashier.role == UserRole.cashier);
    assertTest("8.2. Direktor o'chirish huquqiga ega", security.canDeleteTask(director));
    assertTest("8.3. Oddiy xodim moliyaviy yozuvlarni o'chira OLMAYDI", !security.canDeleteTask(employee));

    // 9. O'chirish (finance_delete)
    final delTool = schema.tools.firstWhere((t) => t.name == 'finance_delete');
    final delRes = await delTool.handler({'id': incEntity.id});
    assertTest("9.1. Direktor yozuvni o'chira oldi", delRes.success && service.store.find(incEntity.id) == null);

  } finally {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }

  print('\n----------------------------------------------------------------');
  print('  NATIJA: Jami ${passed + failed} ta testdan $passed tasi MUVAFFAQITYATLI O\'TDI (Xatolar: $failed)');
  print('================================================================\n');

  if (failed > 0) exit(1);
}

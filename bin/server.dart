import 'dart:io';
import 'package:be_core/be_core.dart';
import 'package:finance_app/finance_service.dart';

void main(List<String> args) async {
  final storagePath = args.isNotEmpty ? args[0] : '${Directory.current.path}/finance_data.json';
  final service = await FinanceService.init(storagePath);
  final server = StandardAppServer(schema: service.schema, store: service.store);
  await server.start();
}

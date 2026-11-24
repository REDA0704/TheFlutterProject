import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_flutter_project/services/database_service.dart';

import 'support/demo_resultats.dart';

void main() {
  test('US7 : taux par discipline, global et année vide', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dossier = await Directory.systemTemp.createTemp('us7_');
    await databaseFactory.setDatabasesPath(dossier.path);
    final db = DatabaseService.instance;
    addTearDown(() async {
      await (await db.database).close();
      await dossier.delete(recursive: true);
    });
    await insererDemoResultats();
    expect(await db.tauxReussiteParDiscipline(annee: '2026-2027'), {
      'Java': 100.0,
      'Algo': 0.0,
      'HTML/CSS': 100.0,
    });
    expect(await db.tauxReussiteGlobal('2026-2027'), 75.0);
    expect(await db.tauxReussiteParDiscipline(annee: '2025-2026'), {
      'Java': 0.0,
      'Algo': 100.0,
    });
    expect(await db.tauxReussiteGlobal('2025-2026'), 50.0);
    expect(await db.tauxReussiteParDiscipline(annee: '2000-2001'), isEmpty);
  });
}

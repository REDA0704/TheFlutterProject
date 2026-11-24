import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_flutter_project/services/database_service.dart';

import 'support/demo_resultats.dart';

void main() {
  test('US6 : tri, recherche et filtre combiné', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dossier = await Directory.systemTemp.createTemp('us6_');
    await databaseFactory.setDatabasesPath(dossier.path);
    final db = DatabaseService.instance;
    addTearDown(() async {
      await (await db.database).close();
      await dossier.delete(recursive: true);
    });
    await insererDemoResultats();
    final tous = await db.getResultatsRecents();
    expect(tous.length, 6);
    expect(tous.first['nom'], 'DEMOALPHA');
    expect(tous.first['discipline'], 'Java');
    expect((await db.getResultatsRecents(texte: 'lucas')).length, 2);
    expect((await db.getResultatsRecents(texte: 'demobeta')).length, 1);
    expect((await db.getResultatsRecents(annee: '2025-2026')).length, 2);
    expect(
      await db.getResultatsRecents(texte: 'lucas', annee: '2025-2026'),
      isEmpty,
    );
  });
}

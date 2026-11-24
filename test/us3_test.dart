import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_flutter_project/models/candidat.dart';
import 'package:the_flutter_project/services/database_service.dart';

void main() {
  test('US3 : seuls adresse et motivation changent', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dossier = await Directory.systemTemp.createTemp('us3_');
    await databaseFactory.setDatabasesPath(dossier.path);
    final db = DatabaseService.instance;
    addTearDown(() async {
      await db.fermer();
      await dossier.delete(recursive: true);
    });
    Candidat candidat(String nom) => Candidat(
      nom: nom,
      prenom: 'Test',
      email: '$nom@example.test',
      age: 20,
      adresse: '10 rue Test',
      motivation: Motivation.poursuiteEtudes,
      anneeScolaire: '2026-2027',
    );
    final id = await db.insertCandidat(candidat('ALPHA'), motDePasse: 'secret123');
    final autre = await db.insertCandidat(candidat('BETA'), motDePasse: 'secret123');
    final avant = (await db.getCandidat(id))!.toMap();
    final autreAvant = (await db.getCandidat(autre))!.toMap();
    await db.updateProfil(
      id: id,
      adresse: '20 rue Test',
      motivation: Motivation.reconversionPro,
    );
    expect((await db.getCandidat(id))!.toMap(), {
      ...avant,
      'adresse': '20 rue Test',
      'motivation': 'reconversionPro',
    });
    expect((await db.getCandidat(autre))!.toMap(), autreAvant);
  });
}

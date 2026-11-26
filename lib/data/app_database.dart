import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('Categoria')
class Categorias extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer()(); // color ARGB, ej: 0xFF2196F3
}

@DataClassName('Nota')
class Notas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text().withLength(min: 1, max: 100)();
  TextColumn get contenido => text()();
  DateTimeColumn get fecha => dateTime().withDefault(currentDateAndTime)();
  IntColumn get categoriaId =>
      integer().references(Categorias, #id, onDelete: KeyAction.cascade)();
}

@DriftDatabase(tables: [Categorias, Notas], daos: [NotasDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_abrirConexion());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

@DriftAccessor(tables: [Notas, Categorias])
class NotasDao extends DatabaseAccessor<AppDatabase> with _$NotasDaoMixin {
  NotasDao(super.attachedDatabase);

  // Notas de una categoría, de la más reciente a la más antigua
  Future<List<Nota>> notasPorCategoria(int categoriaId) {
    return (select(notas)
          ..where((n) => n.categoriaId.equals(categoriaId))
          ..orderBy([(n) => OrderingTerm.desc(n.fecha)]))
        .get();
  }

  // Misma consulta, pero se actualiza sola
  Stream<List<Nota>> observarNotasPorCategoria(int categoriaId) {
    return (select(notas)
          ..where((n) => n.categoriaId.equals(categoriaId))
          ..orderBy([(n) => OrderingTerm.desc(n.fecha)]))
        .watch();
  }

  Future<int> insertarCategoria(CategoriasCompanion c) =>
      into(categorias).insert(c);

  Future<int> insertarNota(NotasCompanion n) => into(notas).insert(n);
}

LazyDatabase _abrirConexion() {
  return LazyDatabase(() async {
    final carpeta = await getApplicationDocumentsDirectory();
    final archivo = File(p.join(carpeta.path, 'notas.sqlite'));
    return NativeDatabase.createInBackground(archivo);
  });
}
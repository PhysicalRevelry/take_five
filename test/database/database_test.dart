import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_five/src/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase schema (Phase 1)', () {
    test('opens with an empty tasks table', () async {
      final items = await db.select(db.tasks).get();
      expect(items, isEmpty);
    });

    test('reports schema version 2', () {
      expect(db.schemaVersion, 2);
    });

    test('round-trips a row through the generated TaskRow/companion types',
        () async {
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              position: 1,
              title: 'Hello',
              description: const Value('world'),
            ),
          );

      final row = await db.select(db.tasks).getSingle();
      expect(row.id, isNotNull);
      expect(row.position, 1);
      expect(row.title, 'Hello');
      expect(row.description, 'world');
    });

    test('stores a null description when omitted', () async {
      await db.into(db.tasks).insert(
            TasksCompanion.insert(position: 1, title: 'No detail'),
          );

      final row = await db.select(db.tasks).getSingle();
      expect(row.description, isNull);
    });
  });
}

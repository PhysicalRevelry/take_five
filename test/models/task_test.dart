import 'package:flutter_test/flutter_test.dart';
import 'package:take_five/src/models/task.dart';

void main() {
  group('Task value semantics', () {
    test('instances with identical fields are equal and share a hashCode', () {
      const a = Task(id: 1, position: 1, title: 'x', description: 'y');
      const b = Task(id: 1, position: 1, title: 'x', description: 'y');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('differing fields make instances unequal', () {
      const base = Task(id: 1, position: 1, title: 'x', description: 'y');
      expect(
        base,
        isNot(const Task(id: 2, position: 1, title: 'x', description: 'y')),
      );
      expect(
        base,
        isNot(const Task(id: 1, position: 2, title: 'x', description: 'y')),
      );
      expect(
        base,
        isNot(const Task(id: 1, position: 1, title: 'z', description: 'y')),
      );
      expect(
        base,
        isNot(const Task(id: 1, position: 1, title: 'x', description: 'z')),
      );
    });

    test('null vs non-null description are not equal', () {
      const withNull = Task(id: 1, position: 1, title: 'x');
      const withEmpty =
          Task(id: 1, position: 1, title: 'x', description: '');
      expect(withNull, isNot(withEmpty));
    });
  });
}

import 'package:flutter/foundation.dart';

/// An immutable task as seen by the providers and UI, decoupled from the
/// Drift-generated row type so the database schema can change without rippling
/// into the rest of the app.
@immutable
class Task {
  const Task({
    required this.id,
    required this.position,
    required this.title,
    this.description,
  });

  /// Stable identity, independent of display ordering.
  final int id;

  /// 1-based display order.
  final int position;

  /// Short, required label.
  final String title;

  /// Optional free-form detail; null when absent.
  final String? description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          other.id == id &&
          other.position == position &&
          other.title == title &&
          other.description == description;

  @override
  int get hashCode => Object.hash(id, position, title, description);

  @override
  String toString() =>
      'Task(id: $id, position: $position, title: $title, '
      'description: $description)';
}

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
    this.onWheel = false,
  });

  /// Stable identity, independent of display ordering.
  final int id;

  /// 1-based display order.
  final int position;

  /// Short, required label.
  final String title;

  /// Optional free-form detail; null when absent.
  final String? description;

  /// Whether this task currently occupies a section of the spinning wheel.
  /// The wheel shows up to 15 tasks at once; landing on a task (when more than
  /// 15 exist) rotates it off and brings the next one on.
  final bool onWheel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          other.id == id &&
          other.position == position &&
          other.title == title &&
          other.description == description &&
          other.onWheel == onWheel;

  @override
  int get hashCode => Object.hash(id, position, title, description, onWheel);

  @override
  String toString() =>
      'Task(id: $id, position: $position, title: $title, '
      'description: $description, onWheel: $onWheel)';
}

/// Errors surfaced by the local task store. These are typed so the UI layer can
/// react to specific failures (e.g. show the list-full message) rather than
/// matching on strings.
library;

/// Thrown when adding a task would exceed [limit] stored tasks.
class TaskLimitExceededException implements Exception {
  const TaskLimitExceededException(this.limit);

  /// The maximum number of tasks the list may hold.
  final int limit;

  @override
  String toString() =>
      'TaskLimitExceededException: the list is limited to $limit tasks.';
}

/// Thrown when a task's field fails validation (e.g. an empty or over-length
/// title). Carries a human-readable [message] suitable for surfacing in the UI.
class InvalidTaskException implements Exception {
  const InvalidTaskException(this.message);

  /// Human-readable description of what was invalid.
  final String message;

  @override
  String toString() => 'InvalidTaskException: $message';
}

/// Thrown when an operation targets a task id that no longer exists.
class TaskNotFoundException implements Exception {
  const TaskNotFoundException(this.id);

  /// The id that could not be found.
  final int id;

  @override
  String toString() => 'TaskNotFoundException: no task with id $id.';
}

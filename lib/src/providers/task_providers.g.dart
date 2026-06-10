// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single, app-lifetime [AppDatabase] instance. Kept alive so the SQLite
/// connection is opened once and shared, and closed when the scope is disposed.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// The single, app-lifetime [AppDatabase] instance. Kept alive so the SQLite
/// connection is opened once and shared, and closed when the scope is disposed.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// The single, app-lifetime [AppDatabase] instance. Kept alive so the SQLite
  /// connection is opened once and shared, and closed when the scope is disposed.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

/// Reactive view of the stored tasks, ordered by position. Re-emits on every
/// mutation, so any consuming widget rebuilds automatically.

@ProviderFor(taskList)
final taskListProvider = TaskListProvider._();

/// Reactive view of the stored tasks, ordered by position. Re-emits on every
/// mutation, so any consuming widget rebuilds automatically.

final class TaskListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  /// Reactive view of the stored tasks, ordered by position. Re-emits on every
  /// mutation, so any consuming widget rebuilds automatically.
  TaskListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskListHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return taskList(ref);
  }
}

String _$taskListHash() => r'ee0b411af04c879fcc9e0abc50c7392451d61e54';

/// Write-side entry point for adding, editing, and deleting tasks. Kept alive
/// like [appDatabaseProvider] — it is a stateless facade over the shared
/// database, so there is nothing to dispose and no value in recreating it.

@ProviderFor(taskRepository)
final taskRepositoryProvider = TaskRepositoryProvider._();

/// Write-side entry point for adding, editing, and deleting tasks. Kept alive
/// like [appDatabaseProvider] — it is a stateless facade over the shared
/// database, so there is nothing to dispose and no value in recreating it.

final class TaskRepositoryProvider
    extends $FunctionalProvider<TaskRepository, TaskRepository, TaskRepository>
    with $Provider<TaskRepository> {
  /// Write-side entry point for adding, editing, and deleting tasks. Kept alive
  /// like [appDatabaseProvider] — it is a stateless facade over the shared
  /// database, so there is nothing to dispose and no value in recreating it.
  TaskRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskRepository create(Ref ref) {
    return taskRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskRepository>(value),
    );
  }
}

String _$taskRepositoryHash() => r'85e63b4826a3d6db7d188a8354c50d4d8b378f21';

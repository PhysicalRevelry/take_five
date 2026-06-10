import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../database/database_exceptions.dart';
import '../../models/task.dart';
import 'use_tasks_screen.dart';

/// The main list screen: shows the ordered tasks and supports add / edit /
/// delete. All logic comes from [useTasksScreen]; this build method only
/// renders the resulting model.
class TasksScreen extends HookConsumerWidget {
  const TasksScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = useTasksScreen(ref);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Column(
        children: [
          if (model.atCapacity)
            _CapBanner(maxTasks: model.maxTasks),
          if (model.belowMinimum)
            const _BelowMinBanner(),
          Expanded(
            child: model.tasks.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Could not load tasks: $error')),
              data: (tasks) => tasks.isEmpty
                  ? const _EmptyState()
                  : _TaskList(tasks: tasks, model: model),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: model.canAdd ? () => _add(context, model) : null,
        backgroundColor: model.canAdd ? null : Theme.of(context).disabledColor,
        tooltip: model.canAdd ? 'Add task' : 'List is full',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _add(BuildContext context, TasksScreenModel model) async {
    final result = await _showTaskForm(
      context,
      maxTitleLength: model.maxTitleLength,
      maxDescriptionLength: model.maxDescriptionLength,
    );
    if (result == null || !context.mounted) return;
    await _runMutation(
      context,
      () => model.onAdd(
        title: result.title,
        description: result.description,
      ),
    );
  }
}

/// Shown above the list when the task cap has been reached.
class _CapBanner extends StatelessWidget {
  const _CapBanner({required this.maxTasks});

  final int maxTasks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        'Maximum of $maxTasks tasks reached. Delete one to add another.',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

/// Shown at the top of the list while it holds at least one task but fewer than
/// the recommended minimum, nudging the user toward a usable wheel.
class _BelowMinBanner extends StatelessWidget {
  const _BelowMinBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        'Please add at least five tasks to get started.',
        style: TextStyle(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No tasks yet. Tap + to add your first one.'),
            SizedBox(height: 8),
            Text(
              'Start with five tasks, and you can add up to fifty.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks, required this.model});

  final List<Task> tasks;
  final TasksScreenModel model;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return ListTile(
          leading: CircleAvatar(child: Text('${task.position}')),
          title: Text(task.title),
          subtitle:
              task.description == null ? null : Text(task.description!),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: () => _edit(context, task),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => _runMutation(
                  context,
                  () => model.onDelete(task.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Task task) async {
    final result = await _showTaskForm(
      context,
      maxTitleLength: model.maxTitleLength,
      maxDescriptionLength: model.maxDescriptionLength,
      initial: task,
    );
    if (result == null || !context.mounted) return;
    await _runMutation(
      context,
      () => model.onEdit(
        id: task.id,
        title: result.title,
        description: result.description,
      ),
    );
  }
}

/// Runs a mutation and surfaces any domain error as a SnackBar. Guards against
/// the rare case (e.g. cap raced) where the UI guard was bypassed.
Future<void> _runMutation(
  BuildContext context,
  Future<void> Function() mutation,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await mutation();
  } on InvalidTaskException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on TaskLimitExceededException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('List is limited to ${e.limit} tasks.')),
    );
  } on TaskNotFoundException {
    messenger.showSnackBar(
      const SnackBar(content: Text('That task no longer exists.')),
    );
  }
}

/// Result of the add/edit form.
class _TaskFormResult {
  const _TaskFormResult({required this.title, this.description});

  final String title;
  final String? description;
}

/// Opens the add/edit dialog, returning the entered values or null if cancelled.
Future<_TaskFormResult?> _showTaskForm(
  BuildContext context, {
  required int maxTitleLength,
  required int maxDescriptionLength,
  Task? initial,
}) {
  return showDialog<_TaskFormResult>(
    context: context,
    builder: (_) => _TaskFormDialog(
      maxTitleLength: maxTitleLength,
      maxDescriptionLength: maxDescriptionLength,
      initial: initial,
    ),
  );
}

/// A validated form for creating or editing a task.
class _TaskFormDialog extends HookWidget {
  const _TaskFormDialog({
    required this.maxTitleLength,
    required this.maxDescriptionLength,
    this.initial,
  });

  final int maxTitleLength;
  final int maxDescriptionLength;
  final Task? initial;

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final titleController =
        useTextEditingController(text: initial?.title ?? '');
    final descriptionController =
        useTextEditingController(text: initial?.description ?? '');
    final isEditing = initial != null;

    void submit() {
      if (!formKey.currentState!.validate()) return;
      final description = descriptionController.text.trim();
      Navigator.of(context).pop(
        _TaskFormResult(
          title: titleController.text.trim(),
          description: description.isEmpty ? null : description,
        ),
      );
    }

    return AlertDialog(
      title: Text(isEditing ? 'Edit task' : 'Add task'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: titleController,
              autofocus: true,
              maxLength: maxTitleLength,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required.';
                }
                if (value.trim().runes.length > maxTitleLength) {
                  return 'Title must be $maxTitleLength characters or fewer.';
                }
                return null;
              },
              onFieldSubmitted: (_) => submit(),
            ),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLength: maxDescriptionLength,
              minLines: 1,
              maxLines: 3,
              validator: (value) {
                if (value != null &&
                    value.trim().runes.length > maxDescriptionLength) {
                  return 'Description must be $maxDescriptionLength '
                      'characters or fewer.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: submit,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

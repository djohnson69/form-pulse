/// Task status enumeration
enum TaskStatus {
  todo,
  inProgress,
  completed,
  blocked;

  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.blocked:
        return 'Blocked';
    }
  }

  bool get isTerminal => this == TaskStatus.completed;
}

/// Training certification status enumeration
enum TrainingStatus {
  /// Not started
  notStarted,
  
  /// In progress
  inProgress,
  
  /// Completed and certified
  certified,
  
  /// Certification expired
  expired,
  
  /// Due for recertification
  dueForRecert,
  
  /// Failed certification
  failed;

  /// Get display name for the status
  String get displayName {
    switch (this) {
      case TrainingStatus.notStarted:
        return 'Not Started';
      case TrainingStatus.inProgress:
        return 'In Progress';
      case TrainingStatus.certified:
        return 'Certified';
      case TrainingStatus.expired:
        return 'Expired';
      case TrainingStatus.dueForRecert:
        return 'Due for Recertification';
      case TrainingStatus.failed:
        return 'Failed';
    }
  }

  /// Check if training is valid
  bool get isValid {
    return this == TrainingStatus.certified;
  }

  /// Check if action required
  bool get requiresAction {
    return this == TrainingStatus.expired || 
           this == TrainingStatus.dueForRecert ||
           this == TrainingStatus.notStarted;
  }
}

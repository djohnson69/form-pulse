/// Form submission status enumeration
enum SubmissionStatus {
  /// Draft - saved locally but not submitted
  draft,
  
  /// Pending sync - waiting for network connection
  pendingSync,
  
  /// Submitted - successfully sent to server
  submitted,
  
  /// Under review
  underReview,
  
  /// Approved
  approved,
  
  /// Rejected
  rejected,
  
  /// Requires changes
  requiresChanges,
  
  /// Archived
  archived;

  /// Get display name for the status
  String get displayName {
    switch (this) {
      case SubmissionStatus.draft:
        return 'Draft';
      case SubmissionStatus.pendingSync:
        return 'Pending Sync';
      case SubmissionStatus.submitted:
        return 'Submitted';
      case SubmissionStatus.underReview:
        return 'Under Review';
      case SubmissionStatus.approved:
        return 'Approved';
      case SubmissionStatus.rejected:
        return 'Rejected';
      case SubmissionStatus.requiresChanges:
        return 'Requires Changes';
      case SubmissionStatus.archived:
        return 'Archived';
    }
  }

  /// Check if submission can be edited
  bool get canEdit {
    return this == SubmissionStatus.draft || 
           this == SubmissionStatus.requiresChanges;
  }

  /// Check if submission is final
  bool get isFinal {
    return this == SubmissionStatus.approved || 
           this == SubmissionStatus.archived;
  }
}

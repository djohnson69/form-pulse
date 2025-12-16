/// Form Bridge - Shared Models and Utilities
///
/// This library contains all shared domain models, DTOs, and utilities
/// used across the mobile, web, and backend applications.
library;

// Domain Models
export 'src/models/user.dart';
export 'src/models/form.dart';
export 'src/models/form_submission.dart';
export 'src/models/employee.dart';
export 'src/models/training.dart';
export 'src/models/document.dart';
export 'src/models/client.dart';
export 'src/models/vendor.dart';
export 'src/models/notification.dart';
export 'src/models/news_item.dart';
export 'src/models/job_site.dart';
export 'src/models/equipment.dart';

// Enums
export 'src/enums/user_role.dart';
export 'src/enums/form_field_type.dart';
export 'src/enums/submission_status.dart';
export 'src/enums/training_status.dart';

// Constants
export 'src/constants/api_constants.dart';
export 'src/constants/app_constants.dart';

// Utilities
export 'src/utils/date_time_utils.dart';
export 'src/utils/validation_utils.dart';
export 'src/utils/encryption_utils.dart';

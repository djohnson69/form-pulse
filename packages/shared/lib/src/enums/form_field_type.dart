/// Form field type enumeration
enum FormFieldType {
  /// Single-line text input
  text,
  
  /// Multi-line text area
  textarea,
  
  /// Number input
  number,
  
  /// Date picker
  date,
  
  /// Time picker
  time,
  
  /// Date and time picker
  datetime,
  
  /// Email input with validation
  email,
  
  /// Phone number input
  phone,
  
  /// Single selection dropdown
  dropdown,
  
  /// Multiple selection checkboxes
  checkbox,
  
  /// Single selection radio buttons
  radio,
  
  /// Yes/No toggle switch
  toggle,
  
  /// File upload (single)
  file,
  
  /// Multiple file upload
  files,
  
  /// Photo capture
  photo,
  
  /// Video capture
  video,
  
  /// Signature capture
  signature,
  
  /// GPS location capture
  location,
  
  /// Barcode/QR code scanner
  barcode,
  
  /// RFID tag reader
  rfid,
  
  /// Repeating group of fields
  repeater,
  
  /// Tabular input (rows x columns)
  table,
  
  /// Computed/calculated field (readonly)
  computed,

  /// Section header (non-input)
  sectionHeader,
  
  /// Informational text (non-input)
  infoText;

  /// Get display name for the field type
  String get displayName {
    switch (this) {
      case FormFieldType.text:
        return 'Text';
      case FormFieldType.textarea:
        return 'Text Area';
      case FormFieldType.number:
        return 'Number';
      case FormFieldType.date:
        return 'Date';
      case FormFieldType.time:
        return 'Time';
      case FormFieldType.datetime:
        return 'Date & Time';
      case FormFieldType.email:
        return 'Email';
      case FormFieldType.phone:
        return 'Phone';
      case FormFieldType.dropdown:
        return 'Dropdown';
      case FormFieldType.checkbox:
        return 'Checkbox';
      case FormFieldType.radio:
        return 'Radio';
      case FormFieldType.toggle:
        return 'Toggle';
      case FormFieldType.file:
        return 'File Upload';
      case FormFieldType.files:
        return 'Multiple Files';
      case FormFieldType.photo:
        return 'Photo';
      case FormFieldType.video:
        return 'Video';
      case FormFieldType.signature:
        return 'Signature';
      case FormFieldType.location:
        return 'GPS Location';
      case FormFieldType.barcode:
        return 'Barcode/QR';
      case FormFieldType.rfid:
        return 'RFID';
      case FormFieldType.repeater:
        return 'Repeater';
      case FormFieldType.table:
        return 'Table';
      case FormFieldType.computed:
        return 'Computed';
      case FormFieldType.sectionHeader:
        return 'Section Header';
      case FormFieldType.infoText:
        return 'Information';
    }
  }

  /// Check if field type accepts user input
  bool get isInputField {
    return this != FormFieldType.sectionHeader && 
           this != FormFieldType.infoText &&
           this != FormFieldType.computed;
  }

  /// Check if field type involves media capture
  bool get isMediaField {
    return this == FormFieldType.photo || 
           this == FormFieldType.video ||
           this == FormFieldType.file ||
           this == FormFieldType.files;
  }
}

<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->


## Form Force Shared Package

This package contains shared models, utilities, and constants for the Form Force 2.0 platform. It is used by both the mobile/web app and backend for consistent data structures and business logic.


## Features
- Shared data models (forms, users, orgs, submissions)
- Common utilities and helpers
- Constants for validation and field types


## Getting started
Add this package as a dependency in your Dart/Flutter project:

```yaml
dependencies:
	shared:
		path: ../shared
```


## Usage
Import shared models and utilities:

```dart
import 'package:shared/shared.dart';

final form = FormModel(...);
```


## Additional information
See the main project README for more details. Contributions welcome!

import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('Model serialization', () {
    test('LocationData parses integer coordinates', () {
      final json = {
        'latitude': 45,
        'longitude': -120,
        'altitude': 200,
        'accuracy': 5,
        'timestamp': DateTime.utc(2024, 1, 1).toIso8601String(),
        'address': 'Test Site',
      };

      final location = LocationData.fromJson(json);

      expect(location.latitude, 45.0);
      expect(location.longitude, -120.0);
      expect(location.altitude, 200.0);
      expect(location.accuracy, 5.0);
      expect(location.address, 'Test Site');
    });

    test('Training parses numeric score values', () {
      final json = {
        'id': 'training-1',
        'employeeId': 'emp-1',
        'trainingName': 'Fall Protection',
        'status': 'certified',
        'score': 95,
      };

      final training = Training.fromJson(json);

      expect(training.score, 95.0);
      expect(training.status, TrainingStatus.certified);
    });
  });
}

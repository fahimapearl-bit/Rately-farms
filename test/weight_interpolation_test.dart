import 'package:flutter_test/flutter_test.dart';
import 'package:rately_farms/sales_screen.dart';

void main() {
  DateTime day(int d) => DateTime(2026, 11, d);

  final points = [
    WeightPoint(day(10), 1.0),
    WeightPoint(day(20), 1.4),
  ];

  test('exact date -> recorded value, not estimated', () {
    final r = interpolateWeight(points, day(10))!;
    expect(r.kg, 1.0);
    expect(r.isEstimated, false);
  });

  test('between two points -> linear interpolation, estimated', () {
    final r = interpolateWeight(points, day(15))!;
    // Worked example: 1.000 + (1.400 - 1.000) * (15-10)/(20-10) = 1.200 kg
    expect(r.kg, closeTo(1.2, 1e-9));
    expect(r.isEstimated, true);
  });

  test('one-sided -> nearest value, no extrapolation, estimated', () {
    final after = interpolateWeight(points, day(25))!;
    expect(after.kg, 1.4);
    expect(after.isEstimated, true);

    final before = interpolateWeight(points, day(5))!;
    expect(before.kg, 1.0);
    expect(before.isEstimated, true);
  });

  test('no data at all -> null (UI shows —)', () {
    expect(interpolateWeight([], day(15)), isNull);
  });

  test('unsorted input works the same', () {
    final shuffled = points.reversed.toList();
    final r = interpolateWeight(shuffled, day(15))!;
    expect(r.kg, closeTo(1.2, 1e-9));
    expect(r.isEstimated, true);
  });
}

class PoultryStandards {
  // ব্রয়লার (Cobb 500 / Ross 308) - বাংলাদেশে বহুল ব্যবহৃত স্ট্যান্ডার্ড
  static const Map<int, double> broilerMilestones = {
    0: 42,
    7: 190,
    14: 480,
    21: 950,
    28: 1550,
    35: 2200,
    42: 2850,
  };

  // সোনালী মুরগি (Sonali) - দেশীয় আবহাওয়া উপযোগী
  static const Map<int, double> sonaliMilestones = {
    0: 32,
    7: 65,
    14: 120,
    21: 200,
    28: 310,
    35: 440,
    42: 590,
    49: 750,
    56: 880,
    63: 1000,
    70: 1100,
  };

  // লেয়ার (Commercial Layer - যেমন Hy-Line Brown / Novogen)
  static const Map<int, double> layerMilestones = {
    0: 36,
    7: 70,
    14: 125,
    21: 200,
    28: 300,
    35: 410,
    42: 530,
    56: 800,
    70: 1050,
    84: 1260,
    112: 1550,
    140: 1800,
  };

  /// বয়স (দিন), Production Category এবং Breed অনুযায়ী প্রতিদিনের আদর্শ ওজন (গ্রাম)
  static double? getStandardWeight({
    required int ageInDays,
    required String? category,
    required String? breed,
  }) {
    if (ageInDays < 0) return null;

    Map<int, double> milestones;
    final catLower = (category ?? '').toLowerCase();
    final breedLower = (breed ?? '').toLowerCase();

    if (catLower.contains('broiler') || breedLower.contains('broiler') || breedLower.contains('cobb')) {
      milestones = broilerMilestones;
    } else if (catLower.contains('sonali') || breedLower.contains('sonali')) {
      milestones = sonaliMilestones;
    } else if (catLower.contains('layer') || breedLower.contains('layer')) {
      milestones = layerMilestones;
    } else {
      // ডিফল্ট হিসেবে সোনালী বা ব্রয়লার অনুমিত
      if (catLower.contains('meat')) {
        milestones = broilerMilestones;
      } else {
        milestones = sonaliMilestones;
      }
    }

    final days = milestones.keys.toList()..sort();
    if (ageInDays <= days.first) return milestones[days.first];
    if (ageInDays >= days.last) return milestones[days.last];

    // Linear Interpolation: নির্দিষ্ট দিনের আগের ও পরের মাইলস্টোন বের করে মাঝের মান হিসাব
    int lowerDay = days.first;
    int upperDay = days.last;

    for (int i = 0; i < days.length - 1; i++) {
      if (ageInDays >= days[i] && ageInDays <= days[i + 1]) {
        lowerDay = days[i];
        upperDay = days[i + 1];
        break;
      }
    }

    final double lowerWeight = milestones[lowerDay]!;
    final double upperWeight = milestones[upperDay]!;
    final double fraction = (ageInDays - lowerDay) / (upperDay - lowerDay);

    return double.parse((lowerWeight + fraction * (upperWeight - lowerWeight)).toStringAsFixed(1));
  }

  /// প্রকৃত ওজন বনাম আদর্শ ওজনের পারফরম্যান্স মূল্যায়ন
  static WeightEvaluation evaluate({
    required double actualWeight,
    required double standardWeight,
  }) {
    if (standardWeight <= 0) {
      return WeightEvaluation(
        diffGrams: 0,
        diffPercent: 0,
        status: 'No Standard',
        colorHex: 0xFF757575,
        advice: 'কোনো স্ট্যান্ডার্ড পাওয়া যায়নি',
      );
    }

    final diffGrams = actualWeight - standardWeight;
    final diffPercent = (diffGrams / standardWeight) * 100;

    if (diffPercent >= 5.0) {
      return WeightEvaluation(
        diffGrams: diffGrams,
        diffPercent: diffPercent,
        status: 'Ahead (+)',
        colorHex: 0xFF2E7D32, // Dark Green
        advice: 'পাখির বৃদ্ধি আদর্শের চেয়ে চমৎকার!',
      );
    } else if (diffPercent <= -5.0) {
      return WeightEvaluation(
        diffGrams: diffGrams,
        diffPercent: diffPercent,
        status: 'Lagging (-)',
        colorHex: 0xFFC62828, // Dark Red
        advice: 'আদর্শের চেয়ে পিছিয়ে; খাদ্য ও স্বাস্থ্য পরীক্ষা করুন।',
      );
    } else {
      return WeightEvaluation(
        diffGrams: diffGrams,
        diffPercent: diffPercent,
        status: 'On Target (±5%)',
        colorHex: 0xFF1565C0, // Dark Blue
        advice: 'বৃদ্ধির হার স্বাভাবিক সীমার মধ্যে রয়েছে।',
      );
    }
  }
}

class WeightEvaluation {
  final double diffGrams;
  final double diffPercent;
  final String status;
  final int colorHex;
  final String advice;

  WeightEvaluation({
    required this.diffGrams,
    required this.diffPercent,
    required this.status,
    required this.colorHex,
    required this.advice,
  });
}

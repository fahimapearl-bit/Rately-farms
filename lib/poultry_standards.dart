import 'package:flutter/material.dart';

enum GrowthStatus { ahead, onTarget, behind }

class StandardBenchmarkEvaluation {
  final double targetWeightGrams;
  final String breedBenchmarkName;
  final double diffGrams;
  final double diffPercent;
  final GrowthStatus status;
  final String advice;
  final int colorHex;

  StandardBenchmarkEvaluation({
    required this.targetWeightGrams,
    required this.breedBenchmarkName,
    required this.diffGrams,
    required this.diffPercent,
    required this.status,
    required this.advice,
    required this.colorHex,
  });
}

class PoultryStandardsService {
  /// বয়স (দিন), জাত ও ক্যাটাগরি অনুযায়ী টার্গেট ওজন ও পারফরম্যান্স মূল্যায়ন
  static StandardBenchmarkEvaluation evaluate({
    required String? productionType,
    required String? productionCategory,
    required String? breed,
    required int ageDays,
    required double actualWeightKg,
  }) {
    final catLower = (productionCategory ?? '').toLowerCase();
    final breedLower = (breed ?? '').toLowerCase();
    final typeLower = (productionType ?? '').toLowerCase();

    String benchmarkName = 'Broiler (Cobb 500)';
    Map<int, double> milestones = PoultryStandards.broilerMilestones;

    if (catLower.contains('sonali') || breedLower.contains('sonali') || typeLower.contains('sonali')) {
      benchmarkName = 'Sonali Standard';
      milestones = PoultryStandards.sonaliMilestones;
    } else if (catLower.contains('layer') || breedLower.contains('layer') || typeLower.contains('layer') || typeLower.contains('egg')) {
      benchmarkName = 'Commercial Layer';
      milestones = PoultryStandards.layerMilestones;
    } else if (catLower.contains('broiler') || breedLower.contains('broiler') || breedLower.contains('cobb') || typeLower.contains('meat')) {
      benchmarkName = 'Broiler (Cobb 500)';
      milestones = PoultryStandards.broilerMilestones;
    }

    double targetGrams = 0.0;
    if (ageDays >= 0) {
      final days = milestones.keys.toList()..sort();
      if (ageDays <= days.first) {
        targetGrams = milestones[days.first]!;
      } else if (ageDays >= days.last) {
        targetGrams = milestones[days.last]!;
      } else {
        int lowerDay = days.first;
        int upperDay = days.last;
        for (int i = 0; i < days.length - 1; i++) {
          if (ageDays >= days[i] && ageDays <= days[i + 1]) {
            lowerDay = days[i];
            upperDay = days[i + 1];
            break;
          }
        }
        final double lowerWeight = milestones[lowerDay]!;
        final double upperWeight = milestones[upperDay]!;
        final double fraction = (ageDays - lowerDay) / (upperDay - lowerDay);
        targetGrams = lowerWeight + fraction * (upperWeight - lowerWeight);
      }
    }

    final double actualGrams = actualWeightKg * 1000.0;
    final double diffGrams = targetGrams > 0 ? (actualGrams - targetGrams) : 0.0;
    final double diffPercent = targetGrams > 0 ? (diffGrams / targetGrams) * 100.0 : 0.0;

    GrowthStatus status = GrowthStatus.onTarget;
    String advice = 'Growth is normal and on track.';
    int colorHex = 0xFF1565C0;

    if (diffPercent >= 5.0) {
      status = GrowthStatus.ahead;
      advice = 'Flock growth is above standard!';
      colorHex = 0xFF2E7D32;
    } else if (diffPercent <= -5.0) {
      status = GrowthStatus.behind;
      advice = 'Flock is lagging behind target. Check feed and health.';
      colorHex = 0xFFC62828;
    }

    return StandardBenchmarkEvaluation(
      targetWeightGrams: double.parse(targetGrams.toStringAsFixed(1)),
      breedBenchmarkName: benchmarkName,
      diffGrams: double.parse(diffGrams.toStringAsFixed(1)),
      diffPercent: double.parse(diffPercent.toStringAsFixed(1)),
      status: status,
      advice: advice,
      colorHex: colorHex,
    );
  }
}

class PoultryStandards {
  // ব্রয়লার (Cobb 500 / Ross 308)
  static const Map<int, double> broilerMilestones = {
    0: 42,
    7: 190,
    14: 480,
    21: 950,
    28: 1550,
    35: 2200,
    42: 2850,
  };

  // সোনালী মুরগি (Sonali)
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

  // লেয়ার (Commercial Layer)
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

  static double? getStandardWeight({
    required int ageInDays,
    required String? category,
    required String? breed,
  }) {
    if (ageInDays < 0) return null;
    final ev = PoultryStandardsService.evaluate(
      productionType: null,
      productionCategory: category,
      breed: breed,
      ageDays: ageInDays,
      actualWeightKg: 0,
    );
    return ev.targetWeightGrams;
  }

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
        colorHex: 0xFF2E7D32,
        advice: 'পাখির বৃদ্ধি আদর্শের চেয়ে চমৎকার!',
      );
    } else if (diffPercent <= -5.0) {
      return WeightEvaluation(
        diffGrams: diffGrams,
        diffPercent: diffPercent,
        status: 'Lagging (-)',
        colorHex: 0xFFC62828,
        advice: 'আদর্শের চেয়ে পিছিয়ে; খাদ্য ও স্বাস্থ্য পরীক্ষা করুন।',
      );
    } else {
      return WeightEvaluation(
        diffGrams: diffGrams,
        diffPercent: diffPercent,
        status: 'On Target (±5%)',
        colorHex: 0xFF1565C0,
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

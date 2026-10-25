class Batch {
  final String id;
  final String userId;
  final String name;
  final String productionType;
  final String productionCategory;
  final String breed;
  final DateTime startDate;
  final int initialBirds;

  const Batch({
    required this.id,
    required this.userId,
    required this.name,
    required this.productionType,
    required this.productionCategory,
    required this.breed,
    required this.startDate,
    required this.initialBirds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'production_type': productionType,
        'production_category': productionCategory,
        'breed': breed,
        'start_date': startDate.toIso8601String(),
        'initial_birds': initialBirds,
      };

  factory Batch.fromJson(Map<String, dynamic> json) => Batch(
        id: '${json['id'] ?? ''}',
        userId: '${json['user_id'] ?? ''}',
        name: '${json['name'] ?? json['batch_name'] ?? ''}',
        productionType:
            '${json['production_type'] ?? json['type'] ?? 'Bird Production'}',
        productionCategory: '${json['production_category'] ?? json['category'] ?? ''}',
        breed: '${json['breed'] ?? ''}',
        startDate: DateTime.parse(
          '${json['start_date'] ?? json['startDate']}',
        ),
        initialBirds: (json['initial_birds'] ?? json['initialBirds'] ?? 0) as int,
      );
}

class DailyRecord {
  final String id;
  final String userId;
  final String batchId;
  final DateTime date;
  final String shedNumber;
  final String feedType;
  final double feedKg;
  final double waterLitre;
  final int eggsCollected;
  final int mortality;
  final String remarks;

  const DailyRecord({
    required this.id,
    required this.userId,
    required this.batchId,
    required this.date,
    required this.shedNumber,
    required this.feedType,
    required this.feedKg,
    required this.waterLitre,
    required this.eggsCollected,
    required this.mortality,
    required this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'batch_id': batchId,
        'record_date': date.toIso8601String(),
        'shed_number': shedNumber,
        'feed_type': feedType,
        'feed_kg': feedKg,
        'water_litre': waterLitre,
        'eggs_collected': eggsCollected,
        'mortality': mortality,
        'remarks': remarks,
      };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        id: '${json['id'] ?? ''}',
        userId: '${json['user_id'] ?? ''}',
        batchId: '${json['batch_id'] ?? json['batchId'] ?? ''}',
        date: DateTime.parse('${json['record_date'] ?? json['date']}'),
        shedNumber: '${json['shed_number'] ?? ''}',
        feedType: '${json['feed_type'] ?? ''}',
        feedKg: ((json['feed_kg'] ?? json['feed'] ?? 0) as num).toDouble(),
        waterLitre:
            ((json['water_litre'] ?? json['water'] ?? 0) as num).toDouble(),
        eggsCollected: (json['eggs_collected'] ?? json['eggs'] ?? 0) as int,
        mortality: (json['mortality'] ?? 0) as int,
        remarks: '${json['remarks'] ?? ''}',
      );
}

class Expense {
  final String id;
  final String userId;
  final String batchId;
  final DateTime date;
  final String type;
  final String description;
  final double amount;
  final String remarks;

  const Expense({
    required this.id,
    required this.userId,
    required this.batchId,
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'batch_id': batchId,
        'expense_date': date.toIso8601String(),
        'expense_type': type,
        'description': description,
        'amount': amount,
        'remarks': remarks,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: '${json['id'] ?? ''}',
        userId: '${json['user_id'] ?? ''}',
        batchId: '${json['batch_id'] ?? json['batchId'] ?? ''}',
        date: DateTime.parse('${json['expense_date'] ?? json['date']}'),
        type: '${json['expense_type'] ?? json['category'] ?? ''}',
        description: '${json['description'] ?? json['note'] ?? ''}',
        amount: ((json['amount'] ?? 0) as num).toDouble(),
        remarks: '${json['remarks'] ?? ''}',
      );
}

class Sale {
  final String id;
  final String userId;
  final String batchId;
  final DateTime date;
  final String type;
  final int quantity;
  final double? weightKg;
  final double unitPrice;
  final String buyerName;
  final String remarks;

  const Sale({
    required this.id,
    required this.userId,
    required this.batchId,
    required this.date,
    required this.type,
    required this.quantity,
    required this.weightKg,
    required this.unitPrice,
    required this.buyerName,
    required this.remarks,
  });

  double get totalAmount =>
      type == 'Bird' && weightKg != null ? weightKg! * unitPrice : quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'batch_id': batchId,
        'sale_date': date.toIso8601String(),
        'sale_type': type,
        'quantity': quantity,
        'weight_kg': weightKg,
        'unit_price': unitPrice,
        'buyer_name': buyerName,
        'remarks': remarks,
      };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: '${json['id'] ?? ''}',
        userId: '${json['user_id'] ?? ''}',
        batchId: '${json['batch_id'] ?? json['batchId'] ?? ''}',
        date: DateTime.parse('${json['sale_date'] ?? json['date']}'),
        type: '${json['sale_type'] ?? json['type'] ?? 'Table Eggs'}',
        quantity: (json['quantity'] ?? json['eggs_sold'] ?? 0) as int,
        weightKg: (json['weight_kg'] ?? json['totalWeightKg']) == null
            ? null
            : ((json['weight_kg'] ?? json['totalWeightKg']) as num).toDouble(),
        unitPrice: ((json['unit_price'] ?? json['pricePerEgg'] ?? json['pricePerKg'] ?? 0) as num).toDouble(),
        buyerName: '${json['buyer_name'] ?? json['buyerName'] ?? ''}',
        remarks: '${json['remarks'] ?? ''}',
      );
}

class WeeklyWeight {
  final String id;
  final String userId;
  final String batchId;
  final DateTime date;
  final int sampleCount;
  final double averageWeightKg;
  final String remarks;

  const WeeklyWeight({
    required this.id,
    required this.userId,
    required this.batchId,
    required this.date,
    required this.sampleCount,
    required this.averageWeightKg,
    required this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'batch_id': batchId,
        'weight_date': date.toIso8601String(),
        'sample_count': sampleCount,
        'average_weight_kg': averageWeightKg,
        'remarks': remarks,
      };

  factory WeeklyWeight.fromJson(Map<String, dynamic> json) => WeeklyWeight(
        id: '${json['id'] ?? ''}',
        userId: '${json['user_id'] ?? ''}',
        batchId: '${json['batch_id'] ?? ''}',
        date: DateTime.parse('${json['weight_date'] ?? json['date']}'),
        sampleCount: (json['sample_count'] ?? 0) as int,
        averageWeightKg: ((json['average_weight_kg'] ?? 0) as num).toDouble(),
        remarks: '${json['remarks'] ?? ''}',
      );
}

class MarketPrice {
  final String id;
  final String userId;
  final DateTime date;
  final String type;
  final String category;
  final String breed;
  final String unit;
  final double price;
  final String marketName;
  final String remarks;

  const MarketPrice({
    required this.id,
    required this.userId,
    required this.date,
    required this.type,
    required this.category,
    required this.breed,
    required this.unit,
    required this.price,
    required this.marketName,
    required this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'price_date': date.toIso8601String(),
        'price_type': type,
        'production_category': category,
        'breed': breed,
        'unit': unit,
        'price': price,
        'market_name': marketName,
        'remarks': remarks,
      };

  factory MarketPrice.fromJson(Map<String, dynamic> json) => MarketPrice(
        id: '${json['id'] ?? ''}',
        userId: '${json['user_id'] ?? ''}',
        date: DateTime.parse('${json['price_date'] ?? json['date']}'),
        type: '${json['price_type'] ?? json['itemType'] ?? ''}',
        category: '${json['production_category'] ?? ''}',
        breed: '${json['breed'] ?? json['name'] ?? ''}',
        unit: '${json['unit'] ?? (json['itemType'] == 'Egg' ? 'piece' : 'kg')}',
        price: ((json['price'] ?? 0) as num).toDouble(),
        marketName: '${json['market_name'] ?? ''}',
        remarks: '${json['remarks'] ?? ''}',
      );
}

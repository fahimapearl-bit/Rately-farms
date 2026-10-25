# Rately Farms — final schema implementation

এই phase-এ app-এর নতুন data design প্রস্তুত করা হয়েছে। Supabase credentials না থাকায় existing local UI এখনো একইভাবে চালু আছে; নতুন model এবং storage layer পরের screen migration-এর ভিত্তি হিসেবে যোগ হয়েছে।

## Entities

- `profiles`: full name, mobile number, farm name
- `batches`: production type/category, written breed, start date, initial birds
- `daily_records`: shed number, feed type, feed, water, eggs, mortality
- `expenses`: batch-wise daily expense entries
- `sales`: bird, table egg, বা hatching egg sale in one table
- `weekly_weights`: batch-wise sample count and average weight
- `market_prices`: bird price/kg and egg price/piece

## Files added

- `lib/models.dart`: Supabase-compatible Dart models
- `lib/local_store.dart`: offline persistence for the new entities
- `../rately-farms-supabase-schema.sql`: Supabase tables, indexes, profile trigger, and RLS policies

## Next migration step

1. Replace the old models in `main.dart` with imports from `models.dart`.
2. Migrate the batch form: production type -> category -> written breed.
3. Add `shed_number` and `feed_type` to daily records.
4. Replace `EggSale` and `BirdSale` with `Sale`.
5. Connect expenses, weekly weights, and market prices to the new local store.
6. Add Supabase initialization and Auth after the local flow is stable.

# Sales cloud migration

`EggSale` এবং `BirdSale` পুরনো local models-এর বদলে `models.dart`-এর একক `Sale` model ব্যবহার করা হয়েছে।

## Official screen

Home → `Sales (Cloud)`

Supported sale types:

- Bird — quantity + total weight (kg) + price/kg
- Table Eggs — quantity + price/piece
- Hatching Eggs — quantity + price/piece

## Supabase mapping

`Sale` rows are written to `public.sales`:

- `sale_type`: Bird, Table Eggs, Hatching Eggs
- `quantity`
- `weight_kg` (Bird-এর ক্ষেত্রে)
- `unit_price`
- `buyer_name`
- `remarks`
- `batch_id`
- `user_id`

The old Home buttons are marked `Legacy ... (Local)` so they are not confused with the official cloud screen. They should be removed after the cloud screen is verified.

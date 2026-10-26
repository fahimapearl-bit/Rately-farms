# Phase 8 — Cloud DataTables

Phase 8 makes the Home list screens Supabase-first and uses horizontally scrollable Material `DataTable` layouts for mobile.

## Cloud list routes

`Batch List` now opens `CloudBatchListScreen`, which reads `public.batches` through `SupabaseRepository.getBatches()` and supports refresh and delete. Batch deletion follows the database cascade and therefore warns that related daily records, expenses and sales will also be deleted.

`Daily Records List` now opens `CloudDailyRecordsScreen`, which reads `public.daily_records` and `public.batches`, shows the batch name, and supports refresh and delete through Supabase.

## DataTable screens

The official screens now show tables for Batch, Daily Records, Sales, Expenses, Weekly Average Weight and Market Price. Tables are wrapped in horizontal scrolling so mobile users can swipe to see all columns. Action columns contain delete buttons where the current repository supports deletion.

The old local-only screen classes remain in `main.dart` temporarily so existing code still compiles, but their Home navigation entries were replaced with the cloud-first screens.

library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

String get kSupabaseUrl =>
    dotenv.maybeGet('SUPABASE_URL') ??
    const String.fromEnvironment('SUPABASE_URL', defaultValue: '');

String get kSupabaseAnonKey =>
    dotenv.maybeGet('SUPABASE_ANON_KEY') ??
    const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

bool get kSupabaseConfigIsPlaceholder =>
    kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty;

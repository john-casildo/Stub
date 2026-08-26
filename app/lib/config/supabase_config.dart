/// Supabase project connection. The anon key is a public, client-safe key
/// by design (RLS is what actually protects data, not secrecy of this key)
/// — see the `supabase` skill's security checklist for what RLS policies
/// this project needs before any table goes live. Never put the
/// service_role/secret key here or anywhere in the Flutter app.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://jlygdlftvvgmekjcawgr.supabase.co';

  /// The publishable key (Supabase's current key format, replacing the
  /// legacy JWT-style anon key). Client-safe by design — RLS policies are
  /// what actually protect data, not secrecy of this value.
  static const String publishableKey =
      'sb_publishable_CaGKsYSwsz3Wx4YEOhkcig_Q3g8M2yw';
}

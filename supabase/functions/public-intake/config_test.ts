import { isSupabaseUrl } from "./config.ts";

Deno.test("supabase_url_requires_tls_except_for_explicit_loopback", () => {
  for (
    const value of [
      "https://project.supabase.co",
      "http://localhost:54321",
      "http://127.0.0.1:54321",
      "http://[::1]:54321",
    ]
  ) {
    if (!isSupabaseUrl(value)) {
      throw new Error(`expected allowed Supabase URL: ${value}`);
    }
  }

  for (
    const value of [
      "http://project.supabase.co",
      "http://203.0.113.10:54321",
      "https://user:password@project.supabase.co",
      "https://project.supabase.co/path",
    ]
  ) {
    if (isSupabaseUrl(value)) {
      throw new Error(`expected rejected Supabase URL: ${value}`);
    }
  }
});

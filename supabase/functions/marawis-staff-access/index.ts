import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

async function sameSecret(candidate: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(candidate)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  const a = new Uint8Array(left);
  const b = new Uint8Array(right);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json(405, { error: "Metode tidak diizinkan." });
  }

  const passwordSecret = Deno.env.get("MARAWIS_STAFF_PASSWORD");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!passwordSecret || !supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(503, { error: "Verifikasi akses pengurus belum dikonfigurasi." });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\\s+/i, "");
  if (!token) return json(401, { error: "Silakan login terlebih dahulu." });

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData.user) {
    return json(401, { error: "Sesi login tidak valid. Silakan login ulang." });
  }

  let body: { role?: unknown; password?: unknown };
  try {
    body = await request.json();
  } catch {
    return json(400, { error: "Permintaan tidak valid." });
  }
  const role = body.role;
  const password = body.password;
  if (role !== "pengurus" && role !== "pembina") {
    return json(400, { error: "Pilihan akses tidak valid." });
  }
  if (typeof password !== "string" || password.length < 1 || password.length > 128) {
    return json(400, { error: "Password kedua wajib diisi." });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const { count, error: countError } = await admin
    .from("staff_access_attempts")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userData.user.id)
    .gte("attempted_at", tenMinutesAgo);
  if (countError) return json(503, { error: "Verifikasi sedang bermasalah. Coba lagi nanti." });
  if ((count ?? 0) >= 5) {
    return json(429, { error: "Terlalu banyak percobaan. Coba lagi dalam 10 menit." });
  }

  const { error: attemptError } = await admin
    .from("staff_access_attempts")
    .insert({ user_id: userData.user.id });
  if (attemptError) return json(503, { error: "Verifikasi sedang bermasalah. Coba lagi nanti." });

  if (!(await sameSecret(password, passwordSecret))) {
    return json(401, { error: "Password kedua salah." });
  }

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("id, role")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (profileError || !profile) {
    return json(404, { error: "Profil anggota belum tersedia." });
  }
  if (!["anggota", "pengurus", "pembina"].includes(profile.role)) {
    return json(403, { error: "Role akun tidak diizinkan." });
  }

  const { error: updateError } = await admin
    .from("profiles")
    .update({ role })
    .eq("id", userData.user.id);
  if (updateError) {
    return json(500, { error: "Role belum berhasil diperbarui. Coba lagi." });
  }

  await admin.from("audit_logs").insert({
    actor_id: userData.user.id,
    action: "staff_role_granted",
    target_table: "profiles",
    target_id: userData.user.id,
    details: { role },
  });

  // Keep only recent attempts; this is best-effort housekeeping.
  await admin
    .from("staff_access_attempts")
    .delete()
    .lt("attempted_at", new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString());

  return json(200, { success: true, role });
});

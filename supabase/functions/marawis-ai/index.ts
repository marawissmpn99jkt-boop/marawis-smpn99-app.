import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), {
    status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await supabase.auth.getUser();
    if (error || !data.user) return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
    const apiKey = Deno.env.get("GROQ_API_KEY");
    if (!apiKey) return new Response(JSON.stringify({ error: "GROQ_API_KEY is not configured" }), {
      status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
    const body = await req.json();
    const message = String(body.message ?? "").trim();
    if (!message || message.length > 2000) return new Response(JSON.stringify({ error: "Message must contain 1-2000 characters" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
    const history = Array.isArray(body.history) ? body.history.slice(-8) : [];
    const safeHistory = history
      .filter((m: any) => m && ["user", "assistant"].includes(m.role) && typeof m.content === "string")
      .map((m: any) => ({ role: m.role, content: m.content.slice(0, 2000) }));
    const completion = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": "Bearer " + apiKey, "Content-Type": "application/json" },
      signal: AbortSignal.timeout(25000),
      body: JSON.stringify({
        model: "openai/gpt-oss-20b", reasoning_effort: "low", max_completion_tokens: 900,
        messages: [
          { role: "system", content: "Kamu adalah AI Assistant resmi Marawis SMPN 99 Jakarta. Gaya jawaban harus terasa seperti asisten AI profesional: ramah, natural, cerdas, jelas, terstruktur, dan enak dibaca oleh pelajar. Selalu jawab dalam bahasa Indonesia yang baik dan tidak kaku. FORMAT WAJIB: gunakan paragraf pendek; awali dengan jawaban inti; gunakan heading Markdown (##) hanya jika jawaban cukup panjang; gunakan bullet atau numbering untuk langkah/daftar; tebalkan istilah penting seperlunya; beri jarak antarbagian. DILARANG membuat tabel Markdown kecuali pengguna secara eksplisit meminta tabel. Jangan menampilkan simbol tabel mentah, delimiter pipa, atau format data mentah. Hindari jawaban satu paragraf panjang, pengulangan, basa-basi berlebihan, dan daftar yang tidak diperlukan. Untuk pertanyaan sederhana, jawab singkat 2-5 kalimat. Untuk permintaan panduan, berikan langkah berurutan yang praktis. Bantu topik organisasi, kegiatan, program kerja, latihan, kerja sama tim, dan pengetahuan umum Marawis. Jangan mengaku mengetahui jadwal, data anggota, saldo kas, atau informasi privat yang tidak diberikan dalam percakapan. Jangan meminta password, kode OTP, atau data pribadi. Jika tidak tahu, katakan dengan jujur. Untuk pertanyaan di luar konteks, tetap bantu secara aman dan sopan." },
          ...safeHistory,
          { role: "user", content: message },
        ],
      }),
    });
    const providerText = await completion.text();
    let result: any = {};
    try { result = JSON.parse(providerText); } catch (_) { /* provider returned non-JSON */ }
    if (!completion.ok) {
      const providerMessage = String(result?.error?.message ?? "Tidak ada detail dari penyedia AI").slice(0, 500);
      console.error("Groq provider error", { status: completion.status, message: providerMessage });
      return new Response(JSON.stringify({
        error: "AI_PROVIDER_ERROR",
        message: "Penyedia AI menolak permintaan (HTTP " + completion.status + "): " + providerMessage,
      }), { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    const reply = result.choices?.[0]?.message?.content?.trim();
    if (!reply) {
      console.error("Groq returned an empty completion", { status: completion.status });
      return new Response(JSON.stringify({ error: "EMPTY_AI_RESPONSE", message: "Penyedia AI mengirim jawaban kosong." }), {
        status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ reply }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("marawis-ai request failed", error instanceof Error ? error.message : String(error));
    return new Response(JSON.stringify({ error: "Unable to process request", message: "Fungsi AI gagal memproses permintaan." }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
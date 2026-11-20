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
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile", temperature: 0.55, max_tokens: 700,
        messages: [
          { role: "system", content: "Kamu adalah Marawis Assistant untuk organisasi Marawis SMPN 99 Jakarta. Jawab dalam bahasa Indonesia yang ramah, jelas, ringkas, dan sesuai usia pelajar. Bantu topik organisasi, kegiatan, program kerja, latihan, kerja sama tim, dan pengetahuan umum Marawis. Jangan mengaku mengetahui jadwal, data anggota, saldo kas, atau informasi privat yang tidak diberikan dalam percakapan. Jangan meminta password, kode OTP, atau data pribadi. Jika tidak tahu, katakan dengan jujur. Untuk pertanyaan di luar konteks, tetap bantu secara aman dan sopan." },
          ...safeHistory,
          { role: "user", content: message },
        ],
      }),
    });
    const result = await completion.json();
    if (!completion.ok) return new Response(JSON.stringify({ error: "AI provider request failed" }), {
      status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
    const reply = result.choices?.[0]?.message?.content?.trim();
    if (!reply) throw new Error("Empty AI response");
    return new Response(JSON.stringify({ reply }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (_) {
    return new Response(JSON.stringify({ error: "Unable to process request" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
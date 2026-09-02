import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const MAX_ANALYSES_PER_HOUR = 15;

const PROMPT = `Tu és um nutricionista especializado em estimar calorias e macros a partir de fotos de comida.
Analisa a foto da refeição e responde EXCLUSIVAMENTE com JSON válido (sem markdown, sem comentários), neste formato exato:
{
  "mealName": "nome curto da refeição, ex: Almoço",
  "totalCalories": <soma das calorias>,
  "totalProtein": <soma das proteínas em gramas>,
  "items": [
    {
      "name": "nome do alimento em português",
      "calories": <kcal estimadas>,
      "protein": <gramas de proteína>,
      "carbs": <gramas de hidratos de carbono>,
      "fat": <gramas de gordura>,
      "grams": <peso estimado em gramas>,
      "confidence": <0.0 a 1.0, confiança na estimativa>
    }
  ]
}
Regras:
- Identifica cada alimento visível no prato.
- Estima porções realistas por gramas (usa referências: 1 porção de arroz ~150g, 1 ovo ~50g, etc).
- Estima macros (proteína, hidratos, gordura) com base nos alimentos e porções.
- Não inventes alimentos que não vês.
- Se não houver comida na foto, retorna { "mealName": "Sem comida detectada", "totalCalories": 0, "totalProtein": 0, "items": [] }.
- Valores de calorias devem ser números inteiros; macros podem ter 1 casa decimal.`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

function extractJson(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : trimmed;
  return JSON.parse(candidate);
}

async function checkRateLimit(supabase: SupabaseClient, userId: string): Promise<boolean> {
  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from("analysis_logs")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", hourAgo);
  if (error) return false;
  return (count ?? 0) < MAX_ANALYSES_PER_HOUR;
}

async function logAnalysis(supabase: SupabaseClient, userId: string): Promise<void> {
  await supabase.from("analysis_logs").insert({ user_id: userId });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!GEMINI_API_KEY || !SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({ error: "Variáveis de ambiente não configuradas" }, 500);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Não autenticado" }, 401);
    }
    const { data: userData, error } = await supabase.auth.getUser(authHeader.slice(7));
    if (error || !userData.user) {
      return json({ error: "Sessão inválida" }, 401);
    }
    const userId = userData.user.id;

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const allowed = await checkRateLimit(admin, userId);
    if (!allowed) {
      return json({ error: "Limite de análises excedido. Tenta novamente mais tarde." }, 429);
    }
    await logAnalysis(admin, userId);

    let body: { imageUrl?: string };
    try {
      body = await req.json();
    } catch {
      return json({ error: "Body inválido" }, 400);
    }

    const { imageUrl } = body;
    if (!imageUrl) return json({ error: "imageUrl é obrigatório" }, 400);

    let image: ArrayBuffer;
    let mimeType = "image/jpeg";
    try {
      const imageResp = await fetch(imageUrl);
      if (!imageResp.ok) throw new Error(`fetch ${imageResp.status}`);
      image = await imageResp.arrayBuffer();
      mimeType = imageResp.headers.get("content-type") ?? mimeType;
    } catch {
      return json({ error: "Não foi possível descarregar a imagem" }, 502);
    }

    const geminiResp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: PROMPT },
                { inlineData: { mimeType, data: bytesToBase64(new Uint8Array(image)) } },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
          },
        }),
      },
    );

    if (!geminiResp.ok) {
      const detail = await geminiResp.text();
      return json({ error: `Gemini falhou (${geminiResp.status}): ${detail}` }, 502);
    }

    const geminiData = await geminiResp.json();
    const text = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      return json({ error: "Gemini não devolveu texto" }, 502);
    }

    try {
      return json(extractJson(text));
    } catch {
      return json({ error: "Resposta da IA não é JSON válido" }, 502);
    }
  } catch (e) {
    return json({ error: `Erro interno: ${e}` }, 500);
  }
});
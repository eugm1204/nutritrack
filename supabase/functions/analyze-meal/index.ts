import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const PROMPT = `Tu és um nutricionista especializado em estimar calorias a partir de fotos de comida.
Analisa a foto da refeição e responde EXCLUSIVAMENTE com JSON válido (sem markdown, sem comentários), neste formato exato:
{
  "mealName": "nome curto da refeição, ex: Almoço",
  "totalCalories": <soma das calorias>,
  "items": [
    {
      "name": "nome do alimento em português",
      "calories": <kcal estimadas>,
      "grams": <peso estimado em gramas>,
      "confidence": <0.0 a 1.0, confiança na estimativa>
    }
  ]
}
Regras:
- Identifica cada alimento visível no prato.
- Estima porções realistas por gramas (usa referências: 1 porção de arroz ~150g, 1 ovo ~50g, etc).
- Não inventes alimentos que não vês.
- Se não houver comida na foto, retorna { "mealName": "Sem comida detectada", "totalCalories": 0, "items": [] }.
- Valores de calorias devem ser números inteiros.`;

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!GEMINI_API_KEY || !SUPABASE_URL || !SUPABASE_ANON_KEY) {
      return json({ error: "Variáveis de ambiente não configuradas" }, 500);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Não autenticado" }, 401);
    }
    const { error } = await supabase.auth.getUser(authHeader.slice(7));
    if (error) {
      return json({ error: "Sessão inválida" }, 401);
    }

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
            maxOutputTokens: 2048,
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
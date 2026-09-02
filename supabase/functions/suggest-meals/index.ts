import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const MAX_ANALYSES_PER_HOUR = 15;

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

interface SuggestBody {
  kcalRestantes?: number;
  objective?: string;
  protein?: number;
  carbs?: number;
  fat?: number;
  proteinGoal?: number;
  carbsGoal?: number;
  fatGoal?: number;
}

function buildPrompt(body: SuggestBody): string {
  const kcal = body.kcalRestantes ?? 500;
  const objective = body.objective ?? "maintain";
  const objectiveText =
    objective === "lose"
      ? "perder peso (dá preferência a opções leves e proteicas)"
      : objective === "gain"
        ? "ganhar massa (dá preferência a opções ricas em proteína e calorias densas)"
        : "manter o peso (opções equilibradas)";

  const macrosLine =
    `Consumido hoje: ${body.protein ?? 0}g proteína, ${body.carbs ?? 0}g hidratos, ${body.fat ?? 0}g gordura. ` +
    `Metas: P ${body.proteinGoal ?? "?"}g, H ${body.carbsGoal ?? "?"}g, G ${body.fatGoal ?? "?"}g. ` +
    (body.proteinGoal
      ? `Dá prioridade a opções que ajudem a atingir a meta de proteína de ${body.proteinGoal}g.`
      : "");

  return `Tu és um nutricionista amigável. O utilizador tem ${kcal} kcal restantes hoje e o objetivo é ${objectiveText}.
${macrosLine}
Sugere 3 refeições ou lanches que caibam dentro destas ${kcal} kcal (cada uma com calorias <= ${kcal}), variadas: uma leve, uma equilibrada e uma prática/rápida.
Responde EXCLUSIVAMENTE com JSON válido, neste formato:
{
  "suggestions": [
    {
      "name": "nome apetitoso da refeição",
      "description": "descrição curta e apetitosa do que comer",
      "calories": <kcal>,
      "protein": <gramas>,
      "carbs": <gramas>,
      "fat": <gramas>
    }
  ]
}
Regras: valores de calorias inteiros; macros com 1 casa decimal; em português de Portugal.`;
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

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const allowed = await checkRateLimit(admin, userData.user.id);
    if (!allowed) {
      return json({ error: "Limite de pedidos excedido. Tenta novamente mais tarde." }, 429);
    }
    await logAnalysis(admin, userData.user.id);

    let body: SuggestBody = {};
    try {
      body = await req.json();
    } catch {
      return json({ error: "Body inválido" }, 400);
    }

    const geminiResp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: buildPrompt(body) }] }],
          generationConfig: {
            temperature: 0.7,
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
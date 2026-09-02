# NutriTrack 🍽️

App de tracking de calorias com estimativa por foto via IA (Gemini).
**Alvo atual: iOS** (build cloud via GitHub Actions) + **web** para teste imediato no telemóvel.

## Localização do projeto

`C:\Users\dznga\Desktop\calorie_tracker`

## Stack

- **Flutter** — UI (iOS + web)
- **Supabase** — autenticação, Postgres (metas/refeições), storage (fotos), edge functions
- **Google Gemini** — visão: identifica alimentos e estima calorias

## Funcionalidades

- 📷 Foto do prato → IA estima calorias e itens (editáveis antes de guardar)
- 🍎 Adicionar sem foto: banco de alimentos (Open Food Facts + lista local) ou registo manual
- 🔑 Login com senha ou link mágico (email)
- 📅 Histórico: ver/apagar refeições de dias anteriores
- 🎯 Meta diária de calorias com anel de progresso
- 📊 Gráfico dos últimos 7 dias
- ⚙️ Definições: meta diária, peso e objetivo (perder/manter/ganhar)

## Setup

### 1. Supabase

1. Cria um projeto em [supabase.com](https://supabase.com).
2. No **SQL Editor**, cola e corre o conteúdo de [`supabase/schema.sql`](supabase/schema.sql) (tabelas `profiles` e `meals`, RLS, bucket `meal-photos`).
3. Cria a edge function (deploy automático no dashboard ou CLI):
   - Nome: `analyze-meal`
   - Conteúdo: `supabase/functions/analyze-meal/index.ts`
4. Nas **Edge Function Secrets**, define:
   - `GEMINI_API_KEY` — cria em [aistudio.google.com](https://aistudio.google.com) (tier grátis)
   - `GEMINI_MODEL` *(opcional)* — default `gemini-2.0-flash`
5. Em **Authentication → Providers**, ativa Email (desativa "Confirm email" para login imediato).

### 2. Testar já no iPhone (web, sem Mac)

1. Sobe o projeto para um repositório GitHub.
2. Em **Settings → Secrets and variables → Actions**, cria:
   - `SUPABASE_URL` — Settings → API no Supabase
   - `SUPABASE_ANON_KEY` — a chave anon (publishable)
3. O workflow `build-web.yml` publica o app em **GitHub Pages**.
4. Abre `https://<utilizador>.github.io/<repo>/` no Safari do iPhone → **Partilhar → Adicionar ao ecrã de início** para usar como app.

Teste local:

```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON
```

> Nota: no iPhone, a câmara no Safari pode exigir permissão; o fluxo de galeria funciona sempre.

### 3. Build iOS (.ipa)

Sem Mac nem Apple Developer paga, o `.ipa` não é gerável — o workflow `build-ios.yml` está pronto:

- Trigger manual (**Actions → Build iOS → Run workflow**) ou com tag `v*`.
- Sem certificados: gera `.ipa` **não assinado** (artefato descarregável).
- Com conta Apple Developer paga ($99/ano), adiciona os secrets para `.ipa` assinado:
  - `APPLE_CERTIFICATE_P12` (certificado exportado, base64)
  - `APPLE_CERTIFICATE_PASSWORD`
  - `APPLE_PROFILE` (provisioning profile, base64)
  - `KEYCHAIN_PASSWORD`
- Instalar num iPhone sem Mac: ferramentas como Sideloadly precisam de conta paga ou de um Mac.

## Estrutura

```
lib/
  core/          config, tema, router
  models/        Meal, MealItem, Profile, VisionAnalysis
  services/      visão IA, repositórios (meals, profile)
  providers/     providers Riverpod
  features/
    auth/        login/registo
    dashboard/   anel de calorias + refeições do dia + gráfico semanal
    add_meal/    foto → análise IA → confirmação/edição
    settings/    meta diária, peso, objetivo
supabase/
  schema.sql                        schema + RLS + bucket
  functions/analyze-meal/index.ts   edge function (Gemini)
.github/workflows/
  build-web.yml                     deploy GitHub Pages (teste no iPhone)
  build-ios.yml                     build do .ipa (pronto para o futuro)
```

## Testes

```bash
flutter analyze
flutter test
```
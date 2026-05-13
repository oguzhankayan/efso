# efso

> Open source · MIT lisanslı · iOS app + Supabase backend

**Türkiye-first AI iletişim koçu.** Zor mesaj ekran görüntüsünü ver, üç farklı tonda üç cevap üret. Ya da konuşmayı/profili elle yaz, üret. Asistan sesi gözlemci, çıktı sesi karşı tarafa atılacak gerçek mesaj.

App Store kategorisi: **Lifestyle** (dating-first ama "iletişim koçu" konumlanması). Brand karakteri: GenZ tempo, sokak zekası, internet rahat ama klişe değil, bilinçli ironi. 6 arketip × 5 ton matrisi.

Status: **submission-ready dilim**. Kalan: Faz D (TestFlight signing + archive + invite) + 2 user-action (gicik.app yerine efso.app yayınlama, sandbox trial doğrulaması).

---

## Repo yapısı

```
efso/
├── README.md            # bu dosya
├── CLAUDE.md            # full project context (Claude Code için)
├── HANDOFF.md           # production-readiness handoff (state + kalan iş)
├── BUILD_PLAN.md        # legacy phase 0-7 planı (Phase 0-3 tamam, 4-5 büyük ölçüde, ref olarak kalıyor)
├── prompt.md            # orijinal master brief (arşiv)
│
├── efso-ios/           # SwiftUI iOS app (iOS 17+, Swift 6)
│   ├── README.md
│   ├── SETUP.md         # 5-10 dk Xcode kurulum
│   ├── project.yml      # xcodegen spec
│   ├── Debug.xcconfig.template
│   ├── Release.xcconfig.template
│   ├── Efso/
│   │   ├── App/         # entry, AppDelegate, RootView, Configuration
│   │   ├── DesignSystem/
│   │   ├── Features/    # auth, onboarding, main, modes, profile, settings
│   │   ├── Core/        # networking, auth, storage, subscription, analytics
│   │   ├── Models/
│   │   └── Resources/   # fonts, assets, calibration-questions.json
│   ├── EfsoTests/
│   └── EfsoUITests/
│
└── efso-backend/       # Supabase + Edge Functions
    ├── README.md
    ├── supabase/
    │   ├── config.toml
    │   ├── migrations/  # initial schema, storage, tonla mode, cron
    │   └── functions/   # parse-screenshot, generate-replies, calibrate,
    │                    # delete-account, cleanup-storage, prompt-feedback,
    │                    # create-text-conversation, revenuecat-webhook
    ├── prompts/         # L0 identity, L1 modes, L2 constraints, L3 schemas,
    │                    # L4 runtime, archetypes/, tones/, stage1_parser
    └── scripts/         # seed-prompts + 6 eval matrix script
```

## Hızlı başlangıç

```bash
# 1. Backend
cd efso-backend
cp .env.local.example .env.local && fill secrets
deno run --allow-read --allow-net --allow-env scripts/seed-prompts.ts
supabase functions deploy parse-screenshot generate-replies calibrate \
  delete-account cleanup-storage prompt-feedback create-text-conversation

# 2. iOS
cd ../efso-ios
brew install xcodegen
cp Debug.xcconfig.template Debug.xcconfig && fill secrets
cp Release.xcconfig.template Release.xcconfig && fill secrets
xcodegen generate
open Efso.xcodeproj
```

Detay: `efso-backend/README.md` ve `efso-ios/SETUP.md`.

---

## Faz durumu

| Faz | Kapsam | Durum |
|---|---|---|
| 0 | Bootstrap (repo, scaffolding, design tokens, Apple Sign In) | ✅ |
| 1 | Onboarding 12 ekran, calibrate endpoint, deterministik arketip | ✅ |
| 2 | Vision pipeline (parse + generate streaming, prompt cache, failover) | ✅ |
| 3 | 4 mod (cevap, açılış, tonla, davet) + manuel giriş + history + arketip kart | ✅ |
| 4 | Subscription (StoreKit 2 + RC + restore + cost ceiling) | %90 — webhook canlı test + yıllık ürün wire kaldı |
| 5 | Polish (animasyon, haptic, empty/error states, VO, App Store metadata) | %85 — App Store screenshot/description kaldı |
| **A** | 8 submission blocker (privacy manifest, armv7, AppIcon, vs) | ✅ |
| **B** | 4 prod bug + 6 dead-tap | ✅ |
| **C** | App Review compliance + iOS stability + UX polish | ✅ |
| **D** | TestFlight (signing, archive, beta invite) | ⏳ user manual |
| 7 | Post-launch (widget, AppShortcuts, push series, prompt versioning UI) | ⏳ |

---

## Stack

**iOS:** SwiftUI · iOS 17+ · Swift 6 strict concurrency · MV pattern (`@Observable`) · async/await · StoreKit 2 + RevenueCat · PhotosUI · Apple Sign In · Sentry + PostHog + Mixpanel · Lottie · SafariServices

**Backend:** Supabase (Postgres + Auth + Storage + Edge Functions/Deno+TS) · RLS her tabloda · pg_cron + pg_net (24h screenshot delete) · vault (service_role_key)

**LLM:**
- Stage 1 parse: Gemini 2.5 Flash (vision, JSON, ~$0.001, ~1.5s) — manuel girişte atlanır
- Stage 2 generate: Claude Sonnet 4.5 (streaming SSE, prompt caching L0+L2+L3 ~%75 cost↓, ~$0.012)
- Failover: GPT-5
- Per-user/gün hard cap: **$0.50** (server-side enforce)

---

## Brand özeti

**Asistan sesi (`observation` alanı, kullanıcıya):** lowercase, GenZ tempo, sokak zekası, kestirme. Klişe yok, "harikasın" yok, abicilik yok. *"üç gün sustu, sonra 'selam' attı. valla bu sıfırdan değil, korkudan."*

**Output sesi (karşı tarafa atılacak mesaj):** kullanıcının seçtiği tonda. Asistan sesi sızdırılmaz.

**6 arketip:** dryroaster (🥀 EFSO), observer (🪨 AĞIR), softie_with_edges (🍬 TATLI), chaos_agent (🔥 ALEV), strategist (✨ HAVALI), romantic_pessimist (🎀 NAZLI).

**5 ton:** flörtöz, esprili, direkt, sıcak, gizemli. Tüm modlar/tonlar free tier'a açık; throttle = günde 3 üretim. Premium = sınırsız.

---

## Veri politikası

- Ekran görüntüsü 24 saat sonra otomatik silinir (pg_cron live)
- Konuşma 30 gün tutulur (cron user-side, doc'da)
- AI consent ilk launch'ta zorunlu, ProfileView'dan geri çekilebilir
- In-app account deletion (Apple Guideline 5.1.1) — `delete-account` edge function
- Privacy Manifest tam: 8 collected data type, tracking false
- Sentry PII off, breadcrumb truncate

---

## Lisans

MIT — © 2026 Oğuzhan Kayan. Detay: [LICENSE](LICENSE).

Kişisel/ticari kullanım, fork, değişiklik ve dağıtım serbest. Tek koşul: telif notunu koru.

## Katkı

Issue/PR açmadan önce `CLAUDE.md` (proje context'i) ve `HANDOFF.md`'yi (mevcut durum) okumanı öneririm. Stil: küçük & focused PR, Türkçe yorum + İngilizce identifier, test mecburi (Models / ViewModels / API client için unit test).

Backend secret'ları için: `efso-backend/.env.local.example` → kopyala doldur.
iOS secret'ları için: `efso-ios/{Debug,Release}.xcconfig.template` → kopyala doldur.

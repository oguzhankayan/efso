# efso — App Icon Creative Spec

## Ürün kimliği

**efso**, Türkiye pazarına yönelik bir AI iletişim koçu. Kullanıcı zor mesajların ekran görüntüsünü yükler, app durumu analiz edip farklı tonlarda cevap önerileri üretir. Dating-first ama App Store'da "iletişim koçu" olarak konumlanır.

**Hedef kitle:** 18-30 yaş, Türkiye, dijital iletişimde yardım arayan. Tinder/Bumble/Instagram DM kullanıcıları ağırlıklı ama iş ve arkadaş iletişimi de kapsanır.

**Marka sesi:** lowercase, ironik mesafeli, gözlemci. "seni yargılamıyor ama gördüğünü söylüyor."

---

## Mevcut brand mark

App icon'un temel formu zaten tasarlandı (in-app SwiftUI vector olarak yaşıyor):

- **Speech bubble** — asimetrik, tail sol-alta kıvrık (mesajlaşma referansı)
- İçinde italic serif **"e"** harfi (marka harfi, "efso"nun baş harfi)
- Bubble etrafında **holographic chrome stroke** (ince, 1.5-2px eşdeğeri)
- Arka plan: koyu iris → inkstone diagonal gradient

Bu formu koruyarak yüksek çözünürlüklü, App Store'a hazır bir icon üretilecek.

---

## Renk paleti

### Yüzeyler (arka plan)
| Token | Hex | Açıklama |
|-------|-----|----------|
| bg0 (inkstone) | `#0E0A14` | En dip karanlık — icon arka planı |
| bg1 (plum ink) | `#15101F` | Bubble fill |
| bg2 (iris depth) | `#1C1530` | Gradient üst köşe |

### Metin
| Token | Hex | Açıklama |
|-------|-----|----------|
| ink (paper warm) | `#F4EFE6` | "e" harfi rengi — saf beyaz değil, sıcak kağıt tonu |

### Accent'ler
| Token | Hex | Kullanım |
|-------|-----|----------|
| chrome lilac | `#C9A8FF` | Holographic stroke başlangıç + bitiş |
| soft pink | `#FFC8E1` | Holographic stroke stop 2 |
| highlighter lime | `#E8FF6B` | Holographic stroke stop 3 |
| sky blue | `#9DD9FF` | Holographic stroke stop 4 |

### Holographic gradient (stroke üzerinde)
```
0%   → #C9A8FF (chrome lilac)
28%  → #FFC8E1 (soft pink)
52%  → #E8FF6B (highlighter lime)
78%  → #9DD9FF (sky blue)
100% → #C9A8FF (chrome lilac — loop)
```
Açı: ~110° (sol-üstten sağ-alta). Pastel ve chrome hissi — neon değil.

### Glow (opsiyonel)
| Token | Hex + Alpha | Açıklama |
|-------|-------------|----------|
| purple glow | `#C9A8FF` @ 30% | Bubble arkasında hafif halo |
| pink glow | `#FFC8E1` @ 25% | Sıcak difüz ışık |

---

## Tipografi

- "e" harfi: **serif italic, medium weight**
- Hedef font: **Fraunces Italic** (Google Fonts, open source)
- Fallback: Apple New York Italic veya herhangi bir editorial serif italic
- Harf büyüklüğü: lowercase "e" — BÜYÜK HARF DEĞİL
- Harfin pozisyonu: bubble'ın optik merkezinde, hafif yukarı (bubble tail'den dolayı optik merkez geometrik merkezin biraz üstünde)

---

## Bubble geometrisi

- Organik, tam yuvarlak değil — soft rounded rectangle/oval hissi
- Sol-alt köşeden kısa, içe kıvrık tail (klasik chat bubble tail'i, sivri değil, yumuşak)
- Simetri: üst kısım hafif daha geniş, alt kısım tail'e doğru daralır
- Kenar stroke: holographic gradient, ~1.5-2% icon genişliği kalınlığında

---

## Arka plan

- **Diagonal gradient**: iris depth (#1C1530) sağ-üstten → inkstone (#0E0A14) sol-alta
- Düz siyah değil — koyu mor derinlik hissi
- Opsiyonel: bubble'ın arkasında çok hafif purple glow (abartısız, difüz)

---

## Yapılmaması gerekenler

- Neon / parlak renkler kullanma — palet pastel-chrome, loud değil
- Bubble'ı tam ortaya koyma — tail'den dolayı optik denge biraz sola-yukarı kaymalı
- Beyaz (#FFFFFF) kullanma — metin rengi paper warm (#F4EFE6)
- Gradient'i gökkuşağı gibi yapma — chrome/holographic hissi, rainbow değil
- İkon içine "efso" yazma — sadece "e" harfi
- Drop shadow veya 3D efekt ekleme — flat ama derinlikli (glow ile, shadow ile değil)
- Siyah outline/border — icon kenarında Apple zaten mask uyguluyor

---

## Teslimat

- **1024×1024 px** PNG (App Store)
- Şeffaf arka plan yok — dolu kare (Apple superellipse mask uyguluyor)
- sRGB renk uzayı
- Opsiyonel: 512×512 ve 180×180 varyantlar (küçük boyutta "e" okunabilirliği test için)

---

## Referans mood

"Gece yarısı mor bir odada, masanın üstündeki holographic sticker'dan yansıyan ışık." Lüks değil, pahalı değil — ama cheap hiç değil. Y2K nostalji + modern editorial temizlik.

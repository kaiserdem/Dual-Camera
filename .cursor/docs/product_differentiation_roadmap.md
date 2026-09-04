# Product Differentiation Roadmap

Статус: **пропозиція (не затверджено до реалізації)**  
Джерело ідеї: зовнішня продуктова порада (Dual Shorts / Reaction + Dashcam & Travel + StoreKit Pro)  
Оновлено: 2026-08-21

## Мета документа

Зафіксувати оцінку поради відносно поточного Dual Camera ядра і перетворити її на **наш** беклог: що беремо, що адаптуємо, що відкладаємо. Коли вирішимо щось робити — звідси створюємо окремі specs у `.cursor/specs/`.

---

## Вердикт: наскільки це елегантно для нас

**Загалом — сильний напрям, добре лягає на існуюче ядро**, але не варто копіювати пораду 1:1.

| Аспект | Оцінка | Чому |
|--------|--------|------|
| Розширення `DualFrameCompositor` оверлеями | Відмінно | У нас уже є кадр-за-кадром compose перед `AVAssetWriter` — watermark / stamp / preset frames — природне наступне розширення |
| CoreLocation + телеметрія на кадрі | Добре | On-device, $0, чіткий use-case; потрібні privacy keys і UX дозволів |
| Повторне використання `MotionManager` | Добре | Leveler уже є; G-force / compass на штампі — дешеве розширення того ж CoreMotion |
| StoreKit 2 paywall для Pro-шарів | Логічно | Не чіпає AV-ядро; Pro = overlays / presets / no-watermark |
| Заміна `Photo \| Video` на 3 «продуктові» режими | Слабко як є | Ламає звичну камерну ментальну модель і змішує *capture mode* з *product persona* |
| «Це захистить від Guideline 4.3» | Переоцінено | 4.3 — про унікальність продукту й метаданих, не лише про наявність CoreLocation. Режими допомагають, але не гарантія |
| Оцінки «1–2 дні» на етап | Оптимістично | Compositor + live preview parity + permissions + Pro gating + QA на девайсі = довше |

**Висновок:** беремо стратегію «два signature-режими поверх dual composite», **не** ламаємо Photo/Video, **не** обіцяємо собі, що одного dashcam-штампа вистачить проти 4.3.

---

## Що вже є в архітектурі (навіщо порада «сідає»)

- `AVCaptureMultiCamSession` + dual preview
- `DualVideoEngine` / `DualVideoRecorder` + `DualFrameCompositor` / `DualImageCompositor`
- Layouts: PiP / Vertical / Horizontal + border/shape
- `CaptureLayoutContext` — snapshot на старті take (ідеально для preset + stamp config)
- `MotionManager` (CoreMotion) для leveler
- Settings persistence (`AppSettings`) + video export options
- Збереження в Photos без бекенду

Тобто порада правильно цілить у **шар композитингу та product modes**, а не в перепис камери.

---

## Рекомендована модель режимів (адаптація поради)

Не замінювати:

`Photo | Video`

А додати **Product Mode** (persona) окремим рівнем:

```
Capture:   Photo | Video
Product:   Custom Dual | Reaction Shorts | Dashcam Travel
```

| Product mode | Що робить | База |
|--------------|-----------|------|
| **Custom Dual** | Поточний додаток як є | Уже є |
| **Reaction Shorts** | Пресет 9:16 + круглий PiP + glow frame + Quick Title (+ optional logo) | Compositor + Layout overlay |
| **Dashcam Travel** | Телеметрія-штамп (час, швидкість, локація, optional G-force) | Compositor + LocationManager + MotionManager |

Photo у Dashcam/Reaction лишається корисним (прев’ю кадру зі штампом / title).

---

## Концепція A — Reaction & Shorts Maker

### Кандидати в беклог

- [ ] Preset **Reels/TikTok**: force 9:16, circle PiP (кут), тонка рамка + glow (compose + preview)
- [ ] **Blurred background fill** коли джерело не 9:16 (CIGaussianBlur / downsample + blur у compositor)
- [ ] **Quick Title**: текст до запису, bake у top/bottom safe band
- [ ] **Watermark / logo**: текст або PNG з Photos, позиція/opacity; bake у `DualFrameCompositor` (+ still path у `DualImageCompositor`)
- [ ] Live preview parity: те, що bake — видно на viewfinder (SwiftUI overlay **і** або той самий compose path)

### Paywall-кандидати (пізніше)

- Custom logo / no app watermark
- Pro presets (glow, branded frames)
- Export без брендового watermark
- Auto Captions / субтитри (див. Концепція C)

### Ризики

- Preview ≠ file, якщо overlay лише в SwiftUI
- Glow / blur на dual 1080p — CPU/GPU cost і heat на старих A12
- Текст: локалізація, шрифти, safe area vs bake area

---

## Концепція B — Dashcam & Travel Log

### Кандидати в беклог

- [ ] `LocationManager` (CoreLocation): coords, placemark (місто), speed km/h|mph
- [ ] Privacy: `NSLocationWhenInUseUsageDescription` (+ пояснення в UI чому потрібна локація)
- [ ] Stamp overlay у compositor: REC • speed • location • date/time
- [ ] Розширити `MotionManager`: optional G-force / heading на штампі
- [ ] Одиниці швидкості (metric/imperial) у Settings
- [ ] Поведінка без permission: режим працює без локації, штамп показує «Location off»

### Paywall-кандидати (пізніше)

- Full telemetry stamp
- G-force / compass on stamp
- Continuous long-recording helpers (окремо оцінювати battery / thermal)

### Ризики

- Background recording / dashcam «як реєстратор» — окремий клас складності (background modes, App Review)
- GPS accuracy / speed = 0 пішки — UX copy
- Privacy review: чіткий use-case в описі App Store

**Важливо:** v1 = **foreground travel/vlog stamp**, не full car DVR з background.

---

## Концепція C — Auto Captions (субтитри)

**Не плутати з Quick Title:** Title = один рядок руками; Captions = текст з голосу по таймінгу.

### Кандидати в беклог

- [ ] On-device speech → text (Speech framework / аналог) під час або після запису
- [ ] Сегменти субтитрів з таймінгом (start/end)
- [ ] Bake субтитрів у `DualFrameCompositor` (стиль: розмір, позиція, фон)
- [ ] Live preview або post-pass перед експортом у Photos
- [ ] Мова / локаль розпізнавання; UX коли мікрофон недоступний
- [ ] Spec: `product/auto_captions.md` перед кодом

### Paywall

- Кандидат у **Pro**: auto captions + стилі

### Ризики

- Складніше за stamp/title (accuracy, latency, dual-аудіо front/back)
- On-device vs cloud: для нас пріоритет **on-device / $0**
- Після P1 (burn-in overlays) і бажано після Reaction v1

---

## Концепція D — Teleprompter Mode

**Позиція:** Dual Camera як головна диференціація; суфлер — додатковий signature mode поверх dual.

Use-case: контент-мейкер/блогер читає скрипт, фронталка знімає обличчя, задня — фон/студію, все в одному dual-composite кадрі.

### Кандидати в беклог

- [ ] Текстовий редактор (SwiftUI TextEditor) для введення/вставки скрипту
- [ ] Live scroll overlay поверх viewfinder (SwiftUI, не bake під час запису)
- [ ] Контроль швидкості скролінгу (повзунок або авто)
- [ ] Mirror режим тексту (відзеркалення для читання через скло/рефлектор)
- [ ] Опціонально: bake тексту суфлера в фінальний файл (через DualFrameCompositor)

### Paywall-кандидати (пізніше)

- Custom fonts / стилі тексту
- Bake субтитрів суфлера у файл
- Remote control (Apple Watch / другий девайс)

### Рішення щодо single-cam

- Solo-режим (одна камера) — **відкладаємо**. Dual залишається обов'язковим для диференціації.
- Технічно single-cam реалізовується (~4–8 год, середня складність), але не є пріоритетом v1.
- AVCaptureMultiCamSession нормально стартує з одним input'ом — блокувань немає, але DualVideoRecorder і DualFrameCompositor потребують змін (isSingleCam прапорець, optional secondary buffer).
- Повернемось до solo-режиму після MVP суфлера якщо буде попит.

### Ризики

- UX: екран зайнятий текстом + dual preview — потрібен баланс розміру тексту і viewfinder
- Mirror режим: не плутати з flip камери
- Конкуренти (Teleprompter+) можуть додати dual — наша перевага у вже готовому dual composite

---

## StoreKit 2 / монетизація (окремий етап)

- [ ] Free: Custom Dual core (поточний dual capture)
- [ ] Pro (StoreKit 2): Dashcam stamp, custom logo, pro presets, remove brand watermark, auto captions
- [ ] Нативний paywall (без RevenueCat на старті — $0)
- [ ] Restore purchases, loading/error states

Не блокувати ядро камери підпискою — інакше гірший review і конверсія.

---

## Що з поради беремо / міняємо / відкидаємо

| Порада | Рішення |
|--------|---------|
| Замінити Photo\|Video на 3 режими | **Адаптувати** → Capture + Product Mode |
| Overlays у DualFrameCompositor | **Беремо** (ядро диференціації) |
| Reaction presets + Quick Title | **Беремо** (після стабілізації dualWide / Fit bugs) |
| Dashcam telemetry stamp | **Беремо** як v1 foreground |
| Background dashcam DVR | **Відкладаємо** |
| MotionManager → G-force on stamp | **Беремо** як optional Pro |
| StoreKit 2 paywall | **Беремо** після 1 working signature mode |
| Auto Captions / субтитри (з іншої поради) | **Беремо в backlog** як Pro-фічу після overlays (P5); не v1 |
| «4.3 вирішено цими фічами» | **Не обіцяємо**; плюс потрібні: унікальний бренд, ASO copy, скріни use-case, не template metadata |
| Оцінки 1–2 дні на етап | **Перерахувати** після першого compositor spike |

---

## Запропонований порядок робіт (наш roadmap)

Статуси: `idea` | `next` | `blocked` | `done`

### P0 — не продуктові, але блокують якість

| ID | Пункт | Status |
|----|-------|--------|
| P0.1 | Закрити / стабілізувати virtual smooth zoom (`dualWide`) | in progress |
| P0.2 | Fit WYSIWYG (viewfinder aspect-fill, export = preview, PiP aligned) | done |
| P0.3 | Settings floating → black screen / freeze (перевірити mitigation) | idea |
| P0.4 | Оновити застарілий `dualcam_clone.md` під реальний композит | idea |

### P1 — фундамент диференціації (compositor overlays)

| ID | Пункт | Status |
|----|-------|--------|
| P1.1 | Модель `BurnInOverlay` / stamp layers у `DualFrameCompositor` + `DualImageCompositor` | idea |
| P1.2 | Live preview mirrors burn-in (або shared render path) | idea |
| P1.3 | Product Mode enum + UI перемикач (Custom / Reaction / Dashcam) | idea |
| P1.4 | Spec: `product/product_modes.md` перед кодом | idea |

### P2 — Reaction Shorts v1

| ID | Пункт | Status |
|----|-------|--------|
| P2.1 | Preset Reels: 9:16 + circle PiP + frame | idea |
| P2.2 | Quick Title bake | idea |
| P2.3 | Optional text watermark | idea |
| P2.4 | Blurred 9:16 letterbox (якщо потрібно після P2.1) | idea |

### P3 — Dashcam Travel v1

| ID | Пункт | Status |
|----|-------|--------|
| P3.1 | `LocationManager` + permissions UX | idea |
| P3.2 | Timestamp + speed + placemark stamp | idea |
| P3.3 | Optional G-force from `MotionManager` | idea |
| P3.4 | Units + stamp style Settings | idea |

### P-Tel — Teleprompter Mode v1

| ID | Пункт | Status |
|----|-------|--------|
| PTel.1 | Spec: `product/teleprompter_mode.md` перед кодом | idea |
| PTel.2 | SwiftUI TextEditor для скрипту + persistence | idea |
| PTel.3 | Live scroll overlay поверх viewfinder (SwiftUI) | idea |
| PTel.4 | Контроль швидкості + mirror режим | idea |
| PTel.5 | UX: позиція тексту відносно dual preview | idea |

### P4 — Monetization

| ID | Пункт | Status |
|----|-------|--------|
| P4.1 | StoreKit 2 subscriptions / non-consumable Pro | idea |
| P4.2 | Paywall UI + feature gates (вкл. captions як Pro) | idea |
| P4.3 | App Store metadata під 2 use-cases (ASO / 4.3 hygiene) | idea |

### P5 — Auto Captions (субтитри)

| ID | Пункт | Status |
|----|-------|--------|
| P5.1 | Speech → timed caption segments (on-device) | idea |
| P5.2 | Bake captions у dual composite + стиль | idea |
| P5.3 | UI: увімкнути captions / мова / прев’ю | idea |
| P5.4 | Spec `product/auto_captions.md` | idea |

### Пізніше / out of scope v1

- Background dashcam recording
- Cloud sync / accounts
- Окремі dual files (9:16 + 16:9) замість composite
- 4K / 60fps dual
- In-app gallery browser
- Layout Timeline (зміна layout mid-take з bake) — окрема велика фіча з попередньої brainstorm-сесії
- Cloud transcription (платні API) — не пріоритет, якщо on-device вистачає

---

## Критерії «готово до App Store як унікальний продукт» (чернетка)

1. Хоча б **один** signature mode (Reaction або Dashcam) реально bake в файл і видно в preview.
2. App Store screenshots / description показують **конкретний use-case**, не «yet another dual cam».
3. Core dual Custom режим лишається стабільним (не регресії multi-cam / export).
4. Privacy strings і permission flows чесні.
5. Pro-фічі (якщо є) чітко gated через StoreKit 2 без блокування базової dual зйомки.

---

## Як користуватись цим файлом

1. Обговорюємо → оновлюємо статуси в таблицях вище.
2. Коли пункт іде в роботу → створюємо spec у `.cursor/specs/...` і лінкуємо сюди.
3. Не реалізуємо етапи «наосліп» з зовнішньої поради без окремого рішення в чаті.

## Рішення з обговорення (журнал)

| Дата | Рішення |
|------|---------|
| 2026-08-21 | Документ створено. Реалізацію режимів **ще не затверджено**. Порада прийнята як стратегічний backlog з адаптацією Capture≠Product Mode. |
| 2026-08-21 | Додано **Auto Captions (субтитри)** як Концепція C / етап **P5** (Pro-кандидат; після burn-in overlays, не v1). |
| 2026-09-03 | Fit переозначено як WYSIWYG: aspect-fill без letterbox, export = пропорція viewfinder; PiP позиція збігається з екраном. |
| 2026-09-03 | Додано Концепція D — Teleprompter Mode як новий signature mode поверх dual composite. Dual camera залишається обов'язковою диференціацією; solo single-cam режим відкладено. |
| 2026-09-03 | Технічний аналіз single-cam: складність середня (~4–8 год), AVCaptureMultiCamSession нормально стартує з одним input'ом, але DualVideoRecorder блокує запис без secondary буфера. Відкладено після MVP суфлера. |

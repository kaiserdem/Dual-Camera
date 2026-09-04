# DuoPrompter — App Store listing v1

Статус: **чернетка для App Store Connect**  
Оновлено: 2026-09-04

## Девайси для скрінів

| Пріоритет | Розмір | Пристрій | Розмір файлу | Обовʼязково? |
|-----------|--------|----------|--------------|--------------|
| 1 | **6.9"** | iPhone 16/17 Pro Max (Simulator) | **1320×2868** | Так |
| 2 | 6.5" | лише якщо немає 6.9" | 1284×2778 | Ні |

**Мінімум для v1:** 6–8 скрінів на iPhone 6.9".  
У проєкті `TARGETED_DEVICE_FAMILY = 1` (iPhone only) — iPad скріни не потрібні.

---

## Послідовність скрінів (7 кадрів)

| # | Екран | Що показати | Caption EN |
|---|--------|-------------|------------|
| 1 | Viewfinder dual | PiP або split, обидві камери live | Two cameras. One frame. |
| 2 | Teleprompter ON | Скрипт поверх viewfinder під час запису | Read your script while you record |
| 3 | Layout picker | PiP / vertical / horizontal split | Choose your layout |
| 4 | PiP drag | Круглий або прямокутний PiP, рамка | Drag, resize & style PiP |
| 5 | Recording | REC + таймер + dual preview | Record photo or video |
| 6 | Teleprompter editor | Редагування тексту скрипту | Write scripts in the editor |
| 7 | Settings | Export quality + legal links | Export settings & privacy |

**Не знімати:** DEBUG overlay, порожні permission dialogs, black screen bugs.

---

## Метадані App Store Connect

### Name (≤30)
`DuoPrompter`

### Subtitle (≤30)
`Dual camera & teleprompter`

### Promotional text (≤170)
Record with front and back cameras at once — and read your script on screen. PiP, split layouts, and export straight to Photos.

### Description (EN)

DuoPrompter is a dual-camera app built for creators who need two angles and a script at the same time.

**Dual camera**
• Simultaneous front & back preview on supported iPhones
• Picture-in-picture, vertical split, and horizontal split
• Drag, resize, and style the PiP window
• Photo and video capture with composite export to Photos

**Built-in teleprompter**
• Scroll your script over the camera viewfinder
• Adjust speed and text size
• Edit scripts in a dedicated editor
• Works while recording video

**Pro controls**
• Aspect ratios: 9:16, 16:9, 1:1, 4:5
• Grid, leveler, timer
• Video export quality settings

No account required. Your recordings stay on your device.

Questions? nikolovalena1616@gmail.com

### Keywords (≤100 chars, comma-separated)
dual camera,teleprompter,prompter,front back camera,PiP,split screen,vlog,shorts,script reader

### Support URL
`mailto:nikolovalena1616@gmail.com` або окрема support-сторінка (опційно)

### Privacy Policy URL
`https://hoksv.github.io/dual-camera-legal/privacy.html`

### Terms of Use URL (опційно в ASC, обовʼязково в додатку)
`https://hoksv.github.io/dual-camera-legal/terms.html`

### Category
Primary: **Photo & Video**  
Secondary: **Productivity** (teleprompter)

### Age Rating
4+ (no restricted content in app itself; user-generated video)

---

## Чеклист перед Submit

- [ ] `INFOPLIST_KEY_CFBundleDisplayName` = DuoPrompter
- [ ] Privacy / Terms URLs відкриваються в Safari
- [ ] `DualCameraLegal.appStoreID` заповнений після створення запису в ASC → Rate в Settings
- [ ] Іконка 1024×1024 (без прозорості, без rounded corners у файлі)
- [ ] 6–8 скрінів 6.9"
- [ ] TestFlight: запис відео + teleprompter + збереження в Photos
- [ ] Перевірка на iPhone з MultiCam (не симулятор для QA запису)
- [ ] App Privacy questionnaire: Camera, Microphone, Photo Library Add — no tracking

---

## Що можна робити паралельно (не блокує код)

| Потік | Хто | Час |
|-------|-----|-----|
| Скріни App Store | ти / дизайн | 2–4 год |
| App Store Connect запис + metadata | ти | 1–2 год |
| Іконка DuoPrompter | ти / AI | 1–3 год |
| TestFlight internal testers | ти | 30 хв |
| Privacy questionnaire в ASC | ти | 30 хв |
| P0.3 black screen після Settings | dev | 1–2 дні |
| QA на реальному девайсі | ти | 1 день |

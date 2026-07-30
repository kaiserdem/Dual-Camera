# DualCam Clone

## Description

iOS-додаток для одночасної зйомки з передньої та задньої камер (DualCam Clone). Live preview у режимі PiP (задня — повний екран, передня — перетягуване вікно), перемикання layout, aspect ratio, сітка, рівень, спалах, зум, фото/відео. Цільова платформа: iOS 17+, пристрої з підтримкою `AVCaptureMultiCamSession` (A12+).

## Requirements

### Конфігурація проєкту
- [x] Deployment target iOS 17.0
- [x] Privacy keys: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryAddUsageDescription`

### Архітектура
- [x] `CameraManager` — лише AVFoundation (сесія, inputs/outputs, запис)
- [x] `CameraViewModel` (`@Observable`) — міст UI ↔ камера
- [x] Views — лише відображення та жести
- [x] Перевірка `AVCaptureMultiCamSession.isMultiCamSupported` з graceful fallback

### UI — головний екран
- [x] Top bar: Settings, Ratio, Layout, More (SF Symbols)
- [x] Viewfinder: back full screen + front PiP
- [x] Overlays: Ratio (Crop/1:1/4:3/16:9), Layout (PiP/VSplit/HSplit + PiP Shape + Border), More (Flash/Grid/Leveler)
- [x] Bottom bar: Zoom 0.5/1x/2, gallery, shutter, camera swap, Photo/Video mode
- [x] Settings: grouped list з Rate/Share/Contact + Privacy/Terms/Version (placeholder посилання)

### PiP взаємодії
- [x] Draggable PiP з обмеженням у межах viewfinder
- [x] Tap-to-swap front/back ролей
- [x] Border (колір/ширина) та shape (square/rounded/circle)

### Камера
- [x] `AVCaptureMultiCamSession` з back + front inputs
- [x] Live dual preview через `AVCaptureVideoPreviewLayer`
- [x] Photo capture з збереженням у Photos
- [x] Video recording з мікрофоном і станами shutter
- [x] Zoom (0.5 / 1x / 2) з fallback якщо ultra-wide недоступний
- [x] Flash/torch toggle

### Додаткові фічі
- [x] Grid overlay (правило третин)
- [x] Leveler через CoreMotion
- [ ] Vertical / Horizontal split layouts (базовий UI; повний композит — пізніше)
- [ ] Композитний експорт фото/відео з урахуванням PiP позиції, shape, border, ratio

## Acceptance Criteria

1. Додаток збирається під iOS 17+ без помилок.
2. На пристрої A12+ показує live dual preview (back + front PiP).
3. На пристроях без multi-cam показує зрозуміле повідомлення.
4. PiP можна перетягувати; тап міняє камери місцями.
5. Photo зберігається в Photos; Video записується з індикацією стану.
6. Settings відкривається з NavigationStack; посилання — placeholders.
7. Grid, Leveler, Flash, Zoom працюють з UI-стану ViewModel.

## Notes

- Симулятор не підтримує multi-cam — тестувати на реальному iPhone.
- Композитинг двох потоків у один файл (як у AVMultiCamPiP) — окрема фаза після live preview.
- Zoom 0.5x потребує `.builtInUltraWideCamera`; інакше fallback на 1x.

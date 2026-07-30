# Video Export Settings

## Description

Мінімальний набір опцій експорту відео в Settings: codec (HEVC / H.264), container (MP4 / MOV), resolution (720p / 1080p). Значення персистяться в `AppSettings` і застосовуються в `DualVideoRecorder` / `DualVideoEngine` на старті запису.

## Requirements

- [x] Enum’и `VideoCodecOption`, `VideoContainerOption`, `VideoResolutionOption`
- [x] Persistence у `AppSettings` (UserDefaults)
- [x] Settings UI: секція Video з Picker’ами
- [x] `DualVideoEngine`/`DualVideoRecorder` використовують codec, container, maxLongEdge
- [x] Fallback HEVC → H.264, якщо writer не приймає HEVC
- [x] Defaults: HEVC, MOV, 1080p

## Acceptance Criteria

1. Зміна опцій у Settings зберігається між запусками.
2. Запис створює `.mp4` або `.mov` відповідно до container.
3. 720p / 1080p змінюють long edge кадру (1280 / 1920).
4. HEVC і H.264 записуються; при відсутності HEVC encode — fallback на H.264.
5. Під час recording Settings недоступні (існуючий Recording top bar).

## Notes

- 4K / 60fps навмисно не включені (multi-cam hardwareCost).
- Aspect ratio лишається окремим контролом у camera UI.

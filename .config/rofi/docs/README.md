# Rofi Modular Architecture — Чеклист

> Полный план: [implementation-plan.md](./implementation-plan.md)

## Фазы

### Фаза 1: Фундамент
> [Детали](./tasks/phase-1-foundation.md)

- [ ] 1.1 Переписать `colors.rasi` (Flexoki, удалить старые переменные)
- [ ] 1.2 Создать `shared/settings.rasi` (переменные: шрифт, отступы, border)
- [ ] 1.3 Создать `shared/appearance.rasi` (селекторы, импорт colors + settings)
- [ ] 1.4 Адаптировать `shared/confirm.rasi` (Flexoki)

### Фаза 2: Launchers
> [Детали](./tasks/phase-2-launchers.md)

- [ ] 2.1 Создать `launchers/app-launcher.rasi` (app grid, blue)
- [ ] 2.2 Создать `launchers/emoji.rasi` (список, yellow)
- [ ] 2.3 Создать `launchers/calc.rasi` (компактный, cyan)
- [ ] 2.4 Обновить `config.rasi` (только configuration + @theme)

### Фаза 3: Menus
> [Детали](./tasks/phase-3-menus.md)

- [ ] 3.1 Создать `menus/powermenu.rasi` (fullscreen, red)
- [ ] 3.2 Создать `menus/clipboard.rasi` (список, green)
- [ ] 3.3 Создать `menus/wallpaper.rasi` (сетка, purple)
- [ ] 3.4 Перенести `menus/search.rasi` (список, orange, свой config)

### Фаза 4: Скрипты и интеграция
> [Детали](./tasks/phase-4-scripts.md)

- [ ] 4.1 Обновить `scripts/powermenu.sh` (hibernate, niri logout, пути)
- [ ] 4.2 Обновить `scripts/wallpapermenu.sh` (путь к теме)
- [ ] 4.3 Создать `scripts/clipboard.sh` (новый)
- [ ] 4.4 Обновить `scripts/search.sh` (путь к конфигу)
- [ ] 4.5 Обновить niri `config.kdl` binds

### Фаза 5: Очистка
> [Детали](./tasks/phase-5-cleanup.md)

- [ ] 5.1 Удалить старые файлы (wallpaper-switcher.rasi, powermenu.rasi, calc.rasi, search.rasi)
- [ ] 5.2 Верификация всех меню
- [ ] 5.3 Удалить docs/

---

## Сводка акцентных цветов

| Меню         | Акцент | Hex       | Файл                         |
|--------------|--------|-----------|------------------------------|
| App launcher | blue   | `#4385be` | `launchers/app-launcher.rasi`|
| Emoji        | yellow | `#d0a215` | `launchers/emoji.rasi`       |
| Calculator   | cyan   | `#3aa99f` | `launchers/calc.rasi`        |
| Clipboard    | green  | `#879a39` | `menus/clipboard.rasi`       |
| Wallpaper    | purple | `#8b7ec8` | `menus/wallpaper.rasi`       |
| Search       | orange | `#da702c` | `menus/search.rasi`          |
| Powermenu    | red    | `#d14d41` | `menus/powermenu.rasi`       |
| Bluetooth    | —      | дефолт    | пока без своей темы          |

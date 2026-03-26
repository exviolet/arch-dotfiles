# Фаза 5: Очистка

Удаление старых файлов и финальная верификация.

## Задачи

### 5.1 Удалить старые файлы

- `wallpaper-switcher.rasi` — заменён на `menus/wallpaper.rasi`
- `powermenu.rasi` (корень) — заменён на `menus/powermenu.rasi`
- `calc.rasi` (корень) — заменён на `launchers/calc.rasi`
- `search.rasi` (корень) — заменён на `menus/search.rasi`

**Не удалять**: `colors.rasi`, `config.rasi`, `quicklinks.tsv`, `search_groups.tsv`

### 5.2 Верификация

- [ ] `rofi -show drun` — app grid с blue border
- [ ] `rofi -show emoji -theme launchers/emoji.rasi` — yellow border
- [ ] `rofi -show calc -theme launchers/calc.rasi` — cyan border
- [ ] `scripts/powermenu.sh` — fullscreen, red accent
- [ ] `scripts/clipboard.sh` — список, green border
- [ ] `scripts/wallpapermenu.sh` — сетка с превью, purple border
- [ ] `scripts/search.sh` — список, orange border
- [ ] Confirm dialog визуально соответствует Flexoki
- [ ] Нет ссылок на удалённые файлы (grep по .rasi и .sh)
- [ ] Полупрозрачность работает (compositor)

### 5.3 Удалить docs/

- После завершения всех фаз удалить `docs/` — план выполнен

## Зависимости

- Фаза 4 завершена

## Критерии завершения

- Нет осиротевших файлов в корне rofi-директории
- Все меню работают через niri бинды
- `grep -r` не находит ссылок на старые пути/переменные

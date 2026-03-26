# Фаза 4: Скрипты и интеграция

Обновление shell-скриптов и niri binds для работы с новой структурой.

## Задачи

### 4.1 Обновить `scripts/powermenu.sh`

- Путь к теме: `menus/powermenu.rasi`
- Путь к confirm: `shared/confirm.rasi`
- Добавить ветку `$hibernate` в `case` — заглушка с `notify-send "Hibernate: not configured"`
- Исправить logout:
  - Заменить проверку `$DESKTOP_SESSION` на `$XDG_CURRENT_DESKTOP`
  - Добавить ветку `niri`: `niri msg action quit`
  - Убрать мёртвые ветки (openbox, bspwm, plasma) или оставить для совместимости
- Добавить ветку `$lock` с вызовом `hyprlock` (сейчас `run_cmd` без аргумента — confirm лишний для lock)

**Файлы**: `scripts/powermenu.sh`

### 4.2 Обновить `scripts/wallpapermenu.sh`

- Путь к теме: `~/.config/rofi/menus/wallpaper.rasi`
- Вызов через `-theme` вместо позиционного аргумента
- `awww` уже обновлён — оставить как есть

**Файлы**: `scripts/wallpapermenu.sh`

### 4.3 Создать `scripts/clipboard.sh`

- Вынести из инлайнового niri bind
- Содержимое:
  ```bash
  #!/usr/bin/env bash
  cliphist list | rofi -dmenu -theme ~/.config/rofi/menus/clipboard.rasi -p "Clipboard" | cliphist decode | wl-copy
  ```

**Файлы**: `scripts/clipboard.sh` (новый)

### 4.4 Обновить `scripts/search.sh`

- Изменить путь CONFIG: `$HOME/.config/rofi/menus/search.rasi`
- Все остальные вызовы rofi внутри скрипта тоже обновить на новый путь

**Файлы**: `scripts/search.sh`

### 4.5 Обновить niri `config.kdl` binds

```
Mod+Shift+E → rofi -show emoji -theme ~/.config/rofi/launchers/emoji.rasi
Mod+Shift+C → rofi -show calc -theme ~/.config/rofi/launchers/calc.rasi
Mod+Shift+D → bash -c "$HOME/.config/rofi/scripts/clipboard.sh"
```

`Mod+D` (drun) — без изменений, берёт тему из `config.rasi`.

**Файлы**: `~/.config/niri/config.kdl`

## Зависимости

- Фазы 2 и 3 завершены (лейауты существуют)

## Критерии завершения

- Все бинды в niri работают и открывают правильные меню с правильными темами
- `powermenu.sh`: hibernate показывает уведомление, logout закрывает niri
- `clipboard.sh`: работает как отдельный скрипт
- Нет сломанных путей к `.rasi` файлам

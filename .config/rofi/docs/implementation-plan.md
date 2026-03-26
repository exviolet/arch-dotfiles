# Rofi Modular Architecture — Implementation Plan

## Цель

Перевести rofi-конфигурацию с монолитной (один `config.rasi` на все меню) на модульную архитектуру с разделением по принципу **Цвета -> Глобальные стили -> Специфичный лейаут**. Одновременно перейти на палитру Flexoki и исправить накопленные баги.

---

## Архитектура

### Принцип импортов

```
colors.rasi          (палитра Flexoki + accent-color дефолт)
       ^
settings.rasi        (переменные: шрифт, отступы, border, radius)
       ^
appearance.rasi      (селекторы: window, element, inputbar — использует переменные)
       ^
layout/*.rasi        (override: геометрия + accent-color)
```

Каждый лейаут импортирует **только** `appearance.rasi` (который сам импортирует `colors` и `settings`), а затем переопределяет нужные свойства.

### Целевая структура файлов

```
~/.config/rofi/
├── config.rasi                  # configuration {} + @theme "launchers/app-launcher"
├── colors.rasi                  # Flexoki палитра + accent-color (дефолт blue)
├── shared/
│   ├── settings.rasi            # Переменные: шрифт, отступы, border, radius
│   ├── appearance.rasi          # Селекторы: window, element, inputbar, etc.
│   └── confirm.rasi             # Диалог подтверждения (адаптирован под Flexoki)
├── launchers/
│   ├── app-launcher.rasi        # Сетка с иконками, accent: blue #4385be
│   ├── emoji.rasi               # accent: yellow #d0a215
│   └── calc.rasi                # accent: cyan #3aa99f
├── menus/
│   ├── powermenu.rasi           # Fullscreen, horizontal, 6 кнопок, accent: red #d14d41
│   ├── clipboard.rasi           # Список, accent: green #879a39
│   ├── wallpaper.rasi           # Сетка с превью, accent: purple #8b7ec8
│   └── search.rasi              # Список, accent: orange #da702c (свой configuration {})
└── scripts/
    ├── powermenu.sh             # Фикс: hibernate заглушка, logout через niri
    ├── wallpapermenu.sh         # Обновлён путь к теме
    ├── bluetoothctlmenu.sh      # Пока без изменений (дефолтная тема)
    ├── clipboard.sh             # НОВЫЙ: вынесен из niri bind
    └── search.sh                # Обновлён путь к конфигу
```

---

## Ключевые решения

### Цветовая схема

- **Палитра**: Flexoki (Steph Ango)
- **Базовые цвета**: `#100F0F` (bg), `#FFFCF0` (fg), `#282726` (bg-alt)
- **Акценты по меню**:

| Меню            | Цвет   | Hex       |
|-----------------|--------|-----------|
| App launcher    | blue   | `#4385be` |
| Emoji           | yellow | `#d0a215` |
| Calculator      | cyan   | `#3aa99f` |
| Clipboard       | green  | `#879a39` |
| Wallpaper       | purple | `#8b7ec8` |
| Bluetooth       | blue   | `#4385be` |
| Search          | orange | `#da702c` |
| Powermenu       | red    | `#d14d41` |

- **Механизм**: дефолтный `accent-color` в `colors.rasi`, override одной строкой в лейауте

### Шрифт

- **Основной**: IBM Plex Sans
- **Размеры**: варьируются по меню (12 для списков, 20 для powermenu иконок и т.д.)

### Прозрачность

- **Лаунчеры/меню**: лёгкая дымка `#100F0FCC` (~80% opacity)
- **Powermenu**: `fullscreen: true` с полупрозрачным фоном

### Search — особый случай

- Использует `-config` вместо `-theme` (кастомные keybindings: `Control+j/k`, `Control+Shift+K`)
- Файл темы переезжает в `menus/search.rasi`, но вызывается через `-config`

### Bluetooth

- Пока без своей темы, использует дефолтную из `config.rasi`

---

## Баги для исправления

1. **powermenu.sh**: отсутствует ветка `$hibernate` в `case` — добавить заглушку с `notify-send`
2. **powermenu.sh**: logout не работает на niri — использовать `$XDG_CURRENT_DESKTOP` вместо `$DESKTOP_SESSION`, добавить `niri msg action quit`
3. **shared/confirm.rasi**: использует старые цвета (`@background`, `@selected`) — адаптировать под Flexoki
4. **wallpapermenu.sh**: путь к теме не обновлён
5. **colors.rasi**: мешанина старых и новых переменных — удалить старые полностью

---

## Файлы для удаления

- `wallpaper-switcher.rasi` (заменяется на `menus/wallpaper.rasi`)
- `powermenu.rasi` (заменяется на `menus/powermenu.rasi`)
- `calc.rasi` (заменяется на `launchers/calc.rasi`)
- `search.rasi` (заменяется на `menus/search.rasi`)

---

## Обновления в niri config.kdl

```
Mod+D       → rofi -show drun                                    # берёт тему из config.rasi
Mod+Shift+E → rofi -show emoji -theme launchers/emoji.rasi
Mod+Shift+C → rofi -show calc -theme launchers/calc.rasi
Mod+Shift+D → bash -c "$HOME/.config/rofi/scripts/clipboard.sh"  # новый скрипт
```

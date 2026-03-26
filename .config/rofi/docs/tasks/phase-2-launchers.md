# Фаза 2: Launchers (встроенные rofi modi)

Создание лейаутов для встроенных modi: drun, emoji, calc.

## Задачи

### 2.1 Создать `launchers/app-launcher.rasi`

- Импорт `../shared/appearance.rasi`
- Accent: blue `#4385be` (дефолт, не нужен override)
- Layout: сетка с иконками (app grid)
  - `columns: 5`, `lines: 2`
  - `element { orientation: vertical; }`
  - `element-icon { size: 48px; horizontal-align: 0.5; }`
  - `element-text { horizontal-align: 0.5; }`
  - Подобрать ширину/высоту окна под сетку
- Прозрачность: лёгкая дымка

**Файлы**: `launchers/app-launcher.rasi` (новый)

### 2.2 Создать `launchers/emoji.rasi`

- Импорт `../shared/appearance.rasi`
- Accent: yellow `#d0a215`
- Layout: список или сетка (emoji не имеют иконок)
  - `columns: 1`, `lines: 10`
  - Ширина ~550px
  - `show-icons: false` (задаётся через niri bind или в лейауте)
- Прозрачность: лёгкая дымка

**Файлы**: `launchers/emoji.rasi` (новый)

### 2.3 Создать `launchers/calc.rasi`

- Импорт `../shared/appearance.rasi`
- Accent: cyan `#3aa99f`
- Layout: компактный список
  - `columns: 1`, `lines: 5`
  - Ширина ~550px
  - `mainbox { children: ["message", "inputbar", "listview"]; }` — message сверху для подсказок
  - Placeholder: "Calculate..."
- Прозрачность: лёгкая дымка

**Файлы**: `launchers/calc.rasi` (новый)

### 2.4 Обновить `config.rasi`

- Оставить только `configuration {}` блок (modi, show-icons, display-*, drun-display-format, window-format, calc settings)
- Добавить `@theme "launchers/app-launcher"` в конце
- Удалить все стили (window, element, listview и т.д.) — они теперь в appearance + лейаутах

**Файлы**: `config.rasi`

## Зависимости

- Фаза 1 полностью завершена

## Критерии завершения

- `rofi -show drun` открывает app-grid с Flexoki-стилем
- `rofi -show emoji -theme launchers/emoji.rasi` работает
- `rofi -show calc -theme launchers/calc.rasi` работает
- Все три меню визуально единообразны (одна база), но с разными акцентами и layout

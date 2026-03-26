# Фаза 3: Menus (кастомные dmenu-скрипты)

Создание лейаутов для кастомных меню, вызываемых через `-dmenu`.

## Задачи

### 3.1 Создать `menus/powermenu.rasi`

- Импорт `../shared/appearance.rasi`
- Accent: red `#d14d41`
- Layout: **fullscreen**
  - `window { fullscreen: true; background-color: #100F0F99; }` (~60% opacity — стекло)
  - Горизонтальный ряд из 6 кнопок (lock, suspend, logout, reboot, shutdown, hibernate)
  - `listview { columns: 6; lines: 1; layout: horizontal; }`
  - Крупные иконки: `element-text { font: "IosevkaTermNerdFont 28"; }`
  - `element { border-radius: 8px; padding: 40px 30px; }`
  - `inputbar { enabled: false; }` — не нужен ввод
  - `mainbox { children: ["message", "listview"]; }` — message для uptime

**Файлы**: `menus/powermenu.rasi` (новый)

### 3.2 Создать `menus/clipboard.rasi`

- Импорт `../shared/appearance.rasi`
- Accent: green `#879a39`
- Layout: вертикальный список
  - `columns: 1`, `lines: 12`
  - Ширина ~600px
  - Без иконок
- Прозрачность: лёгкая дымка

**Файлы**: `menus/clipboard.rasi` (новый)

### 3.3 Создать `menus/wallpaper.rasi`

- Импорт `../shared/appearance.rasi`
- Accent: purple `#8b7ec8`
- Layout: сетка с превью
  - `columns: 3`, `lines: 5-7`
  - Крупные иконки-превью: `element-icon { size: 128px; }`
  - `element { orientation: vertical; }`
  - Ширина ~700px

**Файлы**: `menus/wallpaper.rasi` (новый)

### 3.4 Перенести `menus/search.rasi`

- Импорт `../shared/appearance.rasi`
- Accent: orange `#da702c`
- Сохранить `configuration {}` блок с кастомными keybindings
- Layout: вертикальный список
  - `columns: 1`, `lines: 10`
  - Ширина ~550px
  - Без иконок

**Файлы**: `menus/search.rasi` (новый, заменяет `search.rasi`)

## Зависимости

- Фаза 1 полностью завершена

## Критерии завершения

- Все 4 меню открываются и визуально соответствуют Flexoki-стилю
- Powermenu отображается fullscreen с полупрозрачным фоном
- Каждое меню имеет свой акцентный цвет в border

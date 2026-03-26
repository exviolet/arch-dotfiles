# Фаза 1: Фундамент (colors + settings + appearance)

Создание базового слоя модульной архитектуры. После этой фазы все последующие лейауты смогут импортировать единую базу.

## Задачи

### 1.1 Переписать `colors.rasi`

- Удалить все старые переменные (`background`, `background-alt`, `foreground`, `selected`, `active`, `urgent`, `b-color`)
- Оставить только Flexoki палитру:
  - Базовые: `bg`, `bg-alt`, `fg`, `fg-muted`
  - Highlight: `hl-bg`, `hl-fg`
  - Дефолтный акцент: `accent-color: #4385be`
  - Все 7 акцентных цветов как переменные (для удобства переиспользования)
- Убедиться, что альфа-канал для `bg` — `CC` (полупрозрачность)

**Файлы**: `colors.rasi`

### 1.2 Создать `shared/settings.rasi`

- Вынести все именованные переменные:
  - `font-base`: "IBM Plex Sans 12"
  - `font-icon`: размер для иконочных шрифтов
  - `b-radius`, `g-spacing`, `g-margin`, `g-padding`
  - `w-border`, `w-padding`
  - `icon-size`: размер иконок по умолчанию

**Файлы**: `shared/settings.rasi` (новый)

### 1.3 Создать `shared/appearance.rasi`

- Импортирует `../colors.rasi` и `settings.rasi`
- Содержит все селекторы:
  - `window {}` — использует `@bg`, `@accent-color`, прозрачность
  - `mainbox {}`, `inputbar {}`, `prompt {}`, `entry {}`
  - `listview {}` — дефолтные значения
  - `element {}`, `element normal.normal`, `element alternate.normal`, `element selected.normal`, `element selected.active`
  - `element-icon {}`, `element-text {}`
  - `message {}`, `textbox {}`

**Файлы**: `shared/appearance.rasi` (новый)

### 1.4 Адаптировать `shared/confirm.rasi`

- Переписать с использованием импорта `appearance.rasi`
- Заменить все старые цвета на Flexoki
- Сохранить layout: 2 колонки (yes/no), без inputbar

**Файлы**: `shared/confirm.rasi`

## Критерии завершения

- `rofi -show drun` работает с новой базой (через временный тестовый лейаут)
- Нет ссылок на старые переменные цветов
- `shared/appearance.rasi` корректно импортирует `colors` и `settings`

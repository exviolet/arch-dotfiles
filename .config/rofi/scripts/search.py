#!/usr/bin/env python3
import subprocess
import json
import os
import sys
import re
from urllib.parse import quote

# Конфигурация
CONFIG_PATH = os.path.expanduser("~/.config/rofi/search.rasi")
HISTORY_FILE = os.path.expanduser("~/.config/rofi/scripts/history.json")
MAX_HISTORY = 15

ENGINES = {
    "y!": "https://www.youtube.com/results?search_query=",
    "g!": "https://www.google.com/search?q=",
    "gh!": "https://www.github.com/search?q=",
    "p!": "https://www.perplexity.ai/search?q=",
    "def": "https://www.perplexity.ai/search?q="
}

def load_history():
    try:
        with open(HISTORY_FILE, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def save_history(query, history):
    # Убираем дубликаты и ставим свежий запрос в начало
    if query in history:
        history.remove(query)
    history.insert(0, query)
    history = history[:MAX_HISTORY]
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f)

def main():
    history = load_history()
    
    # Форматируем историю для Rofi: "1. запрос"
    # Добавляем пустую строку в начало, чтобы фокус был на поле ввода, а не на первом элементе истории
    formatted_history = [f"{i+1}. {item}" for i, item in enumerate(history)]
    rofi_input = "\n".join(formatted_history)

    try:
        proc = subprocess.run(
            ["rofi", "-dmenu", "-config", CONFIG_PATH, "-p", " ", "-i"],
            input=rofi_input,
            capture_output=True,
            text=True,
            check=True
        )
        user_input = proc.stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit(0)

    if not user_input:
        sys.exit(0)

    # Очистка: если пользователь выбрал пункт из истории (например "1. y! запрос")
    # Мы убираем "1. " с помощью регулярного выражения
    final_query = re.sub(r"^\d+\.\s+", "", user_input)

    # Определение движка
    target_url = ENGINES["def"]
    search_term = final_query

    for prefix, url in ENGINES.items():
        if final_query.startswith(prefix):
            target_url = url
            search_term = final_query[len(prefix):].strip()
            break

    # Сохраняем именно то, что ввел/выбрал пользователь (без индекса)
    save_history(final_query, history)
    
    full_url = f"{target_url}{quote(search_term)}"
    subprocess.run(["xdg-open", full_url])

if __name__ == "__main__":
    main()

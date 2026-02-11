#!/usr/bin/env bash

CONFIG="$HOME/.config/rofi/search.rasi"

LINKS=(
    "🌐 Perplexity|https://www.perplexity.ai"
    "🌏 Яндекс Перевод|https://translate.yandex.com"
    "🐧 Arch Wiki|https://wiki.archlinux.org"
    "🐙 GitHub|https://github.com"
    "📁 TasKanLine Client|$HOME/Projects//Personal/Web/TasKanLine/client" 
    "📁 TasKanLine Server|$HOME/Projects//Personal/Web/TasKanLine/taskanline-server"
)

LIST=$(for i in "${LINKS[@]}"; do echo "${i%|*}"; done)

CHOICE=$(echo -e "$LIST" | rofi -dmenu -config "$CONFIG" -p " " -theme-str 'entry { placeholder: "Search or select Quicklink..."; }')

[[ -z "$CHOICE" ]] && exit 0

ACTION=""
for i in "${LINKS[@]}"; do
    if [[ "${i%|*}" == "$CHOICE" ]]; then
        ACTION="${i#*|}"
        break
    fi
done

if [[ -n "$ACTION" ]]; then
    if [[ "$ACTION" == http* ]]; then
        xdg-open "$ACTION"
    else
        zeditor "$ACTION"
    fi
else
    QUERY="$CHOICE"
    
    case "$QUERY" in
        "y! "*)  URL="https://www.youtube.com/results?search_query=${QUERY#y! }" ;;
        "g! "*)  URL="https://www.google.com/search?q=${QUERY#g! }" ;;
        "aw! "*) URL="https://wiki.archlinux.org/index.php?search=${QUERY#aw! }" ;;
        "au! "*) URL="https://aur.archlinux.org/packages?O=0&K=${QUERY#au! }" ;;
        "gh! "*) URL="https://www.github.com/search?q=${QUERY#gh! }" ;;
        "yt! "*) URL="https://translate.yandex.com/?source_lang=en&target_lang=ru&text=${QUERY#yt! }" ;;
        *)       URL="https://www.perplexity.ai/search?q=$QUERY" ;;
    esac

    URL_ENCODED=$(echo "$URL" | sed 's/ /+/g')
    xdg-open "$URL_ENCODED"
fi

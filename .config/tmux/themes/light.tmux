# Flexoki light tmux theme
set -g status-style "bg=#E6E4D9,fg=#100F0F"
set -g status-left-length 150
set -g status-left "#[fg=#205EA6,bg=#E6E4D9,bold] #(whoami)  #[fg=#6F6E69] #[fg=#100F0F] #I:#P "
set -g window-status-format "#[fg=#6F6E69,bg=#E6E4D9] #I:#W "
set -g window-status-current-format "#[fg=#E6E4D9,bg=#205EA6]#[fg=#FFFCF0,bg=#205EA6,bold] #I:#W* #[fg=#205EA6,bg=#E6E4D9]"
set -g window-status-separator ""
set -g status-right-length 150
set -g status-right "#[fg=#100F0F,bg=#E6E4D9] %H:%M #[fg=#205EA6] #[fg=#100F0F] %Y-%m-%d #[fg=#205EA6] #[fg=#100F0F,bg=#E6E4D9]#S "
set -g pane-active-border-style "fg=#205EA6"
set -g pane-border-style "fg=#DAD8CE"
set -g message-style "bg=#F2F0E5,fg=#100F0F"
set -g mode-style "bg=#205EA6,fg=#FFFCF0"
set -g clock-mode-colour "#205EA6"

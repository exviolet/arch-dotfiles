# Flexoki dark tmux theme
set -g status-style "bg=#100F0F,fg=#FFFCF0"
set -g status-left-length 150
set -g status-left "#[fg=#D14D41,bg=#100F0F,bold] #(whoami)  #[fg=#878580] #[fg=#FFFCF0] #I:#P "
set -g window-status-format "#[fg=#878580,bg=#100F0F] #I:#W "
set -g window-status-current-format "#[fg=#100F0F,bg=#D14D41]#[fg=#FFFCF0,bg=#D14D41,bold] #I:#W* #[fg=#D14D41,bg=#100F0F]"
set -g window-status-separator ""
set -g status-right-length 150
set -g status-right "#[fg=#FFFCF0,bg=#100F0F] %H:%M #[fg=#D14D41] #[fg=#FFFCF0] %Y-%m-%d #[fg=#D14D41] #[fg=#FFFCF0,bg=#100F0F]#S "
set -g pane-active-border-style "fg=#D14D41"
set -g pane-border-style "fg=#343331"
set -g message-style "bg=#1C1B1A,fg=#FFFCF0"
set -g mode-style "bg=#D14D41,fg=#100F0F"
set -g clock-mode-colour "#D14D41"

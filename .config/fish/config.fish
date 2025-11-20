if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source

# =========================================================
# =            Custom Greeting Function                   =
# =========================================================
function fish_greeting
    # --- 1. 收集信息 ---

    # 获取日期和时间
    set current_date (date "+%Y-%m-%d %A")
    set current_time (date "+%T")

    # 检查是否在图形化环境中 (X11 或 Wayland)
    if test -n "$DISPLAY"
        set session_info $XDG_SESSION_TYPE
        set session_color green
    else
        set session_info "Text Mode (TTY)"
        set session_color yellow
    end

    # 获取 IP 地址和网关 (使用 iproute2 工具，适用于大多数现代 Linux)
    # string match -r 使用正则表达式提取信息，比 grep/awk 更高效
    set local_ip (ip -4 addr show | string match -r 'inet ([\d.]+)')[3]
    set gateway_ip (ip route | string match -r '^default via ([\d.]+)' | head -n 1)
    set uptime (uptime -p | sed 's/up //') # 使用 sed 去掉 "up " 前缀
    # --- 2. 设置颜色并打印信息 ---

    set label_color blue # 标签使用亮黄色
    set value_color normal # 值使用默认颜色
    set line_color brblack # 分割线使用亮黑色

    if command -v lolcat >/dev/null
        # 如果存在，就用 lolcat 显示彩虹文本
        printf "We thirst for the seven wailings. We bear the koan of Jericho.\n我们聆听七声悲号的召唤，我们背负沉陷之城的叩问." | lolcat
    else
        # 如果不存在，就用单一颜色显示，避免报错
        printf "%bWe thirst for the seven wailings. We bear the koan of Jericho\n我们聆听七声悲号的召唤，我们背负沉陷之城的叩问.%b\n" (set_color magenta) (set_color normal)
    end
    # 为了对齐，我们使用 printf
    printf '\n' # 打印一个空行，增加间距
    printf '%b   Date:%b\t%s\n' (set_color $label_color) (set_color $value_color) $current_date
    printf '%b   Time:%b\t%s\n' (set_color $label_color) (set_color $value_color) $current_time
    printf '%b Uptime:%b\t%s\n' (set_color $label_color) (set_color $value_color) "$uptime"
    printf '%bSession:%b\t%s\n' (set_color $label_color) (set_color $session_color) $session_info
    printf '%b%s%b\n' (set_color $line_color) ---------------------------------------- (set_color normal)

    if test -n "$local_ip"
        printf '%b     IP:%b\t%s\n' (set_color $label_color) (set_color $value_color) $local_ip
    else
        printf '%b     IP:%b\t%s\n' (set_color $label_color) (set_color red) 'Not Found'
    end

    if test -n "$gateway_ip"
        printf '%bGateway:%b\t%s\n' (set_color $label_color) (set_color $value_color) $gateway_ip
    else
        printf '%bGateway:%b\t%s\n' (set_color $label_color) (set_color red) 'Not Found'
    end

    printf '\n' # 结尾再加一个空行
    set_color normal # 确保光标颜色恢复正常
end

alias cls=clear
alias vim=nvim
alias sic=systemctl

alias ff='fzf --preview '\''bat --style=numbers --color=always {}'\'''
alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'

alias mpjunko='mpvpaper eDP-1 -o "no-audio loop input-ipc-server=/tmp/mpv-socket" /home/lia/Videos/wallpaper-video/junko_newYear.mp4'
alias mpsuzumi='mpvpaper eDP-1 -o "no-audio loop input-ipc-server=/tmp/mpv-socket" /home/lia/Videos/wallpaper-video/suzumi.webm'
alias paperpause='echo "cycle pause" | socat - /tmp/mpv-socket'

alias catclock='arttime --nolearn -a kissingcats -b kissingcats2 -t "Since we found love within, we don\'t bother rats - Wise cats" --ac 3'

toilet -f pagga VERITAS | lolcat

# zoxide: Add this to the end of your config file (usually ~/.config/fish/config.fish)
zoxide init fish | source

function tdlm --description 'Create multiple tdl windows per subdirectory'
    if test -z "$argv[1]"
        echo "Usage: tdlm <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end

    if test -z "$TMUX"
        echo "You must start tmux to use tdlm."
        return 1
    end

    set -l ai $argv[1]
    set -l ai2 $argv[2]
    set -l base_dir $PWD
    set -l first true

    # Rename the session
    tmux rename-session (basename "$base_dir" | tr '.:' '--')

    for dir in */
        set -l dirpath (string trim -c '/' $dir)

        if test "$first" = true
            # Reuse the current window for the first project
            tmux send-keys -t "$TMUX_PANE" "cd '$dirpath'; tdl $ai $ai2" C-m
            set first false
        else
            set -l pane_id (tmux new-window -c "$PWD/$dirpath" -P -F '#{pane_id}')
            # 延迟一小会儿确保窗口创建完成
            tmux send-keys -t "$pane_id" "tdl $ai $ai2" C-m
        end
    end
end

function antig --wraps=antigravity --description 'alias antig=antigravity'
    set -l UNIT_NAME "antigravity-"(date +%s)
    set -l APP_BIN "/usr/bin/antigravity --verbose"
    set -l TRIGGER "Lifecycle#onWillShutdown - end 'antigravityAnalytics'"
    set -l ARGV $argv

    begin
        systemd-run --user --scope --unit="$UNIT_NAME" --property=KillMode=control-group \
            /bin/bash -c "exec prlimit --core=0 $APP_BIN $argv 2>&1 | systemd-cat --identifier=$UNIT_NAME" & disown

        fish -c "
            journalctl --user --identifier=$UNIT_NAME --follow | \
            grep --line-buffered --max-count=1 $TRIGGER >/dev/null 2>&1; and \
                systemctl --user kill --signal=SIGKILL $UNIT_NAME.scope
        " & disown
    end >/dev/null 2>&1
end

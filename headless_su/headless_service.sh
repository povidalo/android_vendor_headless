#!/system/bin/sh
# headless_service - keep a server program running as a supervised service.
#
#   headless_service start NAME [-u termux|root] [-o OOM_SCORE_ADJ] -- COMMAND [ARG...]
#   headless_service stop NAME
#   headless_service restart NAME
#   headless_service status [NAME]
#   headless_service log NAME [LINES]
#
# Meant for server programs (llama-server, databases, ...), started from a
# /data/local/boot.d script rather than Termux:Boot: what an app starts
# (Termux:Boot, the Termux UI) runs inside the app's process tree and is
# killed with it when Android's low-memory killer reclaims the app. A service
# started here runs outside any app; Android's memory management leaves it
# alone, and only the kernel's OOM killer can take it (oom_score_adj 0 by
# default, -o to change).
#
# The supervisor restarts the program whenever it exits: after 2 s, doubling
# up to 60 s while it keeps dying within 30 s of starting. Program output and
# supervisor messages go to /data/local/services/NAME.log (rotated at 2 MB,
# one .old kept). -u termux (the default) runs the program as the Termux user
# with Termux's environment (PREFIX, PATH, HOME, TMPDIR, LD_PRELOAD for
# termux-exec); -u root as root. A single COMMAND argument is a shell command
# line (run by sh, so ~ is the Termux home with -u termux); several are run
# as they are. 'start' does nothing when NAME is already running, so boot.d
# scripts can call it on every boot. Must run as root (boot.d, or su -c).
#
# Example /data/local/boot.d/50-llama (chmod 700):
#   #!/system/bin/sh
#   headless_service start llama -- 'llama-server -m ~/aimodel/model.gguf --host 0.0.0.0 --port 8080 -t 8'

DIR=${HEADLESS_SERVICE_DIR:-/data/local/services}
T=/data/data/com.termux
P=$T/files/usr
H=$T/files/home
ROTATE_KB=2048

die() { echo "headless_service: $*" >&2; exit 1; }
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; } # single-quote for sh
alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
pid_of() { cat "$DIR/$1.$2" 2>/dev/null; } # NAME, pid|child
# The program writes its own pid, as its user: root to $DIR, the Termux user
# to Termux's tmp (it cannot write $DIR).
prog_file() { [ "$(cat "$DIR/$1.user" 2>/dev/null)" = root ] && echo "$DIR/$1.prog" || echo "$P/tmp/headless_service-$1.pid"; }
prog_pid() { cat "$(prog_file "$1")" 2>/dev/null; }
valid_name() { case $1 in "" | *[!A-Za-z0-9_.-]*) return 1 ;; esac; }
now() { date '+%F %T'; }

usage() { sed -n '2,8s/^# \{0,1\}//p' "$0" >&2; exit 2; }

need_root() { [ "$(id -u)" = 0 ] || die "must run as root (from a boot.d script, or: su -c 'headless_service ...')"; }

# ---------------------------------------------------------------- supervisor
run() { # NAME: the supervisor loop, started by 'start' with setsid
    name=$1
    log=$DIR/$name.log
    user=$(cat "$DIR/$name.user")
    oom=$(cat "$DIR/$name.oom")
    cmd=$(cat "$DIR/$name.cmd")
    echo $$ >"$DIR/$name.pid"
    echo "$oom" >/proc/self/oom_score_adj 2>/dev/null
    say() { echo "$(now) headless_service[$name]: $*" >>"$log"; }
    trap 'say "supervisor got SIGTERM, stopping"; touch "$DIR/$name.stop"; [ -n "$child" ] && kill -TERM "$child" 2>/dev/null' TERM
    say "supervisor started (user $user, oom_score_adj $oom): $cmd"
    delay=2 restarts=0
    while [ ! -f "$DIR/$name.stop" ]; do
        if [ -f "$log" ] && [ "$(du -k "$log" | cut -f1)" -ge $ROTATE_KB ]; then
            mv -f "$log" "$log.old"
        fi
        started=$(cut -d. -f1 /proc/uptime)
        # The program writes its own pid (after exec it keeps it): stop and
        # status work on the real program, also when it runs under su.
        inner="echo \$\$ >$(q "$(prog_file "$name")"); echo $oom >/proc/self/oom_score_adj 2>/dev/null; exec $cmd"
        if [ "$user" = root ]; then
            sh -c "cd $(q "$H") 2>/dev/null; $inner" </dev/null >>"$log" 2>&1 &
        else
            tu=$(stat -c %u "$T" 2>/dev/null)
            [ -n "$tu" ] && [ "$tu" != 0 ] || { say "Termux is not installed; retrying in 60 s"; sleep 60; continue; }
            pre=
            for l in libtermux-exec-ld-preload.so libtermux-exec.so; do
                if [ -f "$P/lib/$l" ]; then pre=$P/lib/$l; break; fi
            done
            su "$tu" -c "export PREFIX=$P HOME=$H TMPDIR=$P/tmp LANG=en_US.UTF-8 PATH=$P/bin:/system/bin${pre:+ LD_PRELOAD=$pre}; cd $H; $inner" </dev/null >>"$log" 2>&1 &
        fi
        child=$!
        echo "$child" >"$DIR/$name.child"
        say "started (pid $(sleep 1; prog_pid "$name"), restarts so far $restarts)"
        wait "$child"
        rc=$?
        rm -f "$DIR/$name.child" "$(prog_file "$name")"
        child=
        [ -f "$DIR/$name.stop" ] && { say "stopped (exit $rc)"; break; }
        ran=$(( $(cut -d. -f1 /proc/uptime) - started ))
        if [ -f "$DIR/$name.restart" ]; then
            rm -f "$DIR/$name.restart"
            delay=0
            say "restarting on request (exit $rc after ${ran}s)"
        else
            if [ $ran -ge 30 ]; then delay=2; fi
            say "exited $rc after ${ran}s; restarting in ${delay}s"
        fi
        restarts=$((restarts + 1))
        echo "$restarts" >"$DIR/$name.restarts"
        sleep $delay
        [ $delay -eq 0 ] && delay=2 || { delay=$((delay * 2)); [ $delay -gt 60 ] && delay=60; }
    done
    rm -f "$DIR/$name.pid" "$DIR/$name.stop"
}

# ------------------------------------------------------------------ commands
start() {
    need_root
    name=$1; shift
    valid_name "$name" || die "bad service name '$name' (letters, digits, . _ -)"
    user=termux oom=0
    while [ $# -gt 0 ]; do
        case $1 in
        -u) user=$2; shift 2 ;;
        -o) oom=$2; shift 2 ;;
        --) shift; break ;;
        *) die "unknown option '$1' (the command goes after --)" ;;
        esac
    done
    case $user in termux | root) ;; *) die "-u must be termux or root" ;; esac
    case $oom in -[0-9]* | [0-9]*) ;; *) die "-o needs a number (-1000..1000)" ;; esac
    [ $# -gt 0 ] || die "no command (after --)"
    if alive "$(pid_of "$name" pid)"; then
        echo "$name is already running (supervisor pid $(pid_of "$name" pid))"
        return 0
    fi
    if [ $# -eq 1 ]; then cmd="sh -c $(q "$1")"
    else cmd=; for a in "$@"; do cmd="$cmd $(q "$a")"; done; cmd=${cmd# }; fi
    mkdir -p "$DIR" && chmod 0711 "$DIR"
    rm -f "$DIR/$name.stop" "$DIR/$name.restart" "$DIR/$name.restarts"
    printf '%s\n' "$user" >"$DIR/$name.user"
    printf '%s\n' "$oom" >"$DIR/$name.oom"
    printf '%s\n' "$cmd" >"$DIR/$name.cmd"
    setsid sh "$0" _run "$name" </dev/null >/dev/null 2>&1 &
    sleep 2
    alive "$(pid_of "$name" pid)" || die "$name: the supervisor did not start (see $DIR/$name.log)"
    echo "$name started (supervisor pid $(pid_of "$name" pid), log $DIR/$name.log)"
}

stop() {
    need_root
    name=$1
    sp=$(pid_of "$name" pid)
    alive "$sp" || { echo "$name is not running"; rm -f "$DIR/$name.pid"; return 0; }
    touch "$DIR/$name.stop"
    c=$(pid_of "$name" child); p=$(prog_pid "$name")
    [ -n "$c" ] && kill -TERM "$c" 2>/dev/null   # su forwards it to the program
    [ -n "$p" ] && kill -TERM "$p" 2>/dev/null
    i=0
    while alive "$sp" && [ $i -lt 10 ]; do sleep 1; i=$((i + 1)); done
    if alive "$sp"; then
        [ -n "$p" ] && kill -KILL "$p" 2>/dev/null
        [ -n "$c" ] && kill -KILL "$c" 2>/dev/null
        sleep 1
        alive "$sp" && kill -KILL "$sp" 2>/dev/null
        rm -f "$DIR/$name.pid" "$DIR/$name.stop" "$DIR/$name.child" "$(prog_file "$name")"
    fi
    echo "$name stopped"
}

restart() {
    need_root
    name=$1
    alive "$(pid_of "$name" pid)" || die "$name is not running (use start)"
    touch "$DIR/$name.restart"
    c=$(pid_of "$name" child); p=$(prog_pid "$name")
    [ -n "$c" ] && kill -TERM "$c" 2>/dev/null
    [ -n "$p" ] && kill -TERM "$p" 2>/dev/null
    echo "$name restarting"
}

status() {
    if [ -n "$1" ]; then names=$1
    else names=$(ls "$DIR" 2>/dev/null | sed -n 's/\.cmd$//p'); fi
    [ -n "$names" ] || { echo "no services"; return 0; }
    for name in $names; do
        sp=$(pid_of "$name" pid); p=$(prog_pid "$name")
        if alive "$sp"; then
            if alive "$p"; then
                # toybox ps prints a blank header line even for etime=
                st="running, pid $p, up $(ps -o etime= -p "$p" 2>/dev/null | tail -n 1 | tr -d ' ')"
            else st="restarting"; fi
        else st="stopped"; fi
        printf '%-16s %s, user %s, restarts %s: %s\n' "$name" "$st" "$(cat "$DIR/$name.user" 2>/dev/null)" \
            "$(cat "$DIR/$name.restarts" 2>/dev/null || echo 0)" "$(cat "$DIR/$name.cmd" 2>/dev/null)"
    done
}

case ${1:-} in
start) shift; [ $# -ge 1 ] || usage; start "$@" ;;
stop | restart) [ $# -eq 2 ] && valid_name "$2" || usage; "$1" "$2" ;;
status) status "${2:-}" ;;
log) valid_name "${2:-}" || usage; tail -n "${3:-50}" "$DIR/$2.log" ;;
_run) run "$2" ;;
*) usage ;;
esac

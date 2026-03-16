#!/usr/bin/env bash
# =============================================================================
#
#   DOJOMASTER  --  Master the Linux terminal. One zone at a time.
#   https://github.com/bixson/dojomaster
#
#   A fully interactive terminal game covering the core Linux skill set:
#   navigation, files, text search, pipes, permissions, processes, and SSH.
#
#   Works on: macOS, Linux, Git Bash (Windows)
#   Requires: bash 4.0+
#
#   Usage:
#     bash dojomaster.sh               # full game
#     bash dojomaster.sh --zone 5      # jump to a specific zone
#     bash dojomaster.sh --list        # show all zones
#     bash dojomaster.sh --help        # show this help
#
#   License: MIT
#   Author:  bixson
#
# =============================================================================

VERSION="1.0.0"
GAME_NAME="dojomaster"
GAMEDIR="$HOME/.dojomaster"
LOGFILE="$GAMEDIR/session.log"

# -- Colours ------------------------------------------------------------------
R=$'\033[0;31m'   RED=$'\033[1;31m'
G=$'\033[0;32m'   GRN=$'\033[1;32m'
Y=$'\033[0;33m'   YLW=$'\033[1;33m'
B=$'\033[0;34m'   BLU=$'\033[1;34m'
M=$'\033[0;35m'   MAG=$'\033[1;35m'
C=$'\033[0;36m'   CYN=$'\033[1;36m'
W=$'\033[1;37m'   DIM=$'\033[2m'
RST=$'\033[0m'    BOLD=$'\033[1m'
BG_RED=$'\033[41m'  BG_GRN=$'\033[42m'  BG_YLW=$'\033[43m'

# -- Game state ---------------------------------------------------------------
SCORE=0
MAX_SCORE=0
CORRECT=0
WRONG=0
RETRIED=0
ZONE=0
START_ZONE=1
PLAYER_NAME=""

# -- Question history (for skip/back functionality) ---------------------------
declare -a QUESTION_HISTORY=()  # stores question snapshots
declare -a QUESTION_POINTS=()   # points for each question
CURRENT_Q_INDEX=0               # current question number

# =============================================================================
#  CLI FLAGS
# =============================================================================
show_help() {
  cat << 'HELP'

  dojomaster -- Master the Linux terminal. One zone at a time.

  USAGE
    bash dojomaster.sh               Run the full game
    bash dojomaster.sh --zone N      Start at zone N (1-7)
    bash dojomaster.sh --list        List all zones
    bash dojomaster.sh --help        Show this help
    bash dojomaster.sh --version     Show version

  ZONES
    1  Navigation      cd, ls, pwd, mkdir
    2  File Ops        touch, cp, mv, echo, >, >>
    3  Text Search     cat, head, tail, grep
    4  Pipes           |, >, >>, <, wc
    5  Permissions     chmod, chown, ls -l
    6  Processes       ps, kill, top, htop
    7  SSH             ssh, scp, authorized_keys, key auth

  SCORING
    90%+ = 12    75% = 10    55% = 7    35% = 4    <35% = 02

  HOW WRONG ANSWERS WORK
    Multiple choice  ->  Explains why YOUR specific pick was wrong
    Typed answers    ->  One retry for half points after a hint
    Practical tasks  ->  Exact command revealed + one retry for half points
    Teaching moment  ->  Key rule shown on every miss
    Memory tip       ->  Quick mnemonic to lock it in

HELP
  exit 0
}

show_list() {
  echo
  echo "  ${BOLD}${CYN}dojomaster v${VERSION} -- Zones${RST}"
  echo
  echo "  ${YLW}1${RST}  Navigation      cd, ls, pwd, mkdir"
  echo "  ${YLW}2${RST}  File Ops        touch, cp, mv, echo, >, >>"
  echo "  ${YLW}3${RST}  Text Search     cat, head, tail, grep"
  echo "  ${YLW}4${RST}  Pipes           |, >, >>, <, wc"
  echo "  ${YLW}5${RST}  Permissions     chmod, chown, ls -l"
  echo "  ${YLW}6${RST}  Processes       ps, kill, top, htop"
  echo "  ${YLW}7${RST}  SSH             ssh, scp, authorized_keys"
  echo
  echo "  Run: bash dojomaster.sh --zone N  to start at zone N"
  echo
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)    show_help ;;
      --list|-l)    show_list ;;
      --version|-v) echo "dojomaster v${VERSION}"; exit 0 ;;
      --zone|-z)
        if [[ -z "$2" || ! "$2" =~ ^[1-7]$ ]]; then
          echo "  Error: --zone requires a number 1-7"; exit 1
        fi
        START_ZONE="$2"; shift ;;
      *) echo "  Unknown option: $1. Try --help"; exit 1 ;;
    esac
    shift
  done
}

# =============================================================================
#  VISUAL HELPERS
# =============================================================================
sep()    { printf "\n  ${DIM}${C}%s${RST}\n" "-----------------------------------------------------------"; }
bigcap() { printf "  ${BOLD}${C}%s${RST}\n"  "==========================================================="; }
pause()  { echo; printf "  ${DIM}[ Press ENTER to continue ]${RST}"; read -r; }
blank()  { echo; }

# Animated typewriter: type "text" delay_ms
typeit() {
  local text="$1" delay="${2:-30}"
  local i char
  for (( i=0; i<${#text}; i++ )); do
    char="${text:$i:1}"
    printf "%s" "$char"
    sleep "0.0${delay}" 2>/dev/null || true
  done
  echo
}

# Progress bar: pbar current max width
pbar() {
  local cur="$1" max="$2" width="${3:-40}"
  local filled=$(( (cur * width) / max ))
  local bar="" i
  for ((i=0; i<filled; i++));         do bar+="#"; done
  for ((i=filled; i<width; i++));     do bar+="-"; done
  local pct=$(( (cur * 100) / max ))
  printf "  [%s] %d%%\n" "$bar" "$pct"
}

# Zone header
zone_header() {
  local num="$1" name="$2" sub="$3"
  clear; ZONE="$num"
  bigcap
  printf "  ${BOLD}${CYN}ZONE %s // %s${RST}\n" "$num" "$name"
  printf "  ${DIM}%s${RST}\n" "$sub"
  bigcap; blank
}

# =============================================================================
#  SKIP / BACK FUNCTIONALITY
# =============================================================================

# Save current state before answering
save_question_state() {
  local pts="$1"
  local score_before="$SCORE"
  local max_before="$MAX_SCORE"
  local correct_before="$CORRECT"
  local wrong_before="$WRONG"
  local retried_before="$RETRIED"

  # Store state as a string (json-like)
  local state="${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}"
  QUESTION_HISTORY+=("$state")
  ((CURRENT_Q_INDEX++))
}

# Restore state to before the last question
restore_question_state() {
  if [[ ${#QUESTION_HISTORY[@]} -eq 0 ]] || [[ $CURRENT_Q_INDEX -eq 0 ]]; then
    return 1
  fi

  ((CURRENT_Q_INDEX--))
  local state="${QUESTION_HISTORY[$CURRENT_Q_INDEX]}"

  # Parse state
  IFS='|' read -r score max correct wrong retried pts <<< "$state"
  SCORE="$score"
  MAX_SCORE="$max"
  CORRECT="$correct"
  WRONG="$wrong"
  RETRIED="$retried"

  # Remove from history
  unset 'QUESTION_HISTORY[$CURRENT_Q_INDEX]'
  QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")

  echo
  printf "  ${YLW}Went back one question. State restored.${RST}\n"
  echo
  return 0
}

# Handle user input - detect Ctrl+Right or Ctrl+Left
handle_input() {
  local input="$1"

  # Check for Ctrl+Right arrow
  if [[ "$input" == $'\x1b[1;5C' ]] || [[ "$input" == $'\x1b\[1;5C' ]]; then
    return 1  # Signal to skip
  fi

  # Check for Ctrl+Left arrow
  if [[ "$input" == $'\x1b[1;5D' ]] || [[ "$input" == $'\x1b\[1;5D' ]]; then
    return 2  # Signal to go back
  fi

  return 0  # Normal input
}

# -- Feedback boxes -----------------------------------------------------------
teach() {
  blank
  printf "  ${BOLD}${BLU}+--[ TEACHING MOMENT ]%s+${RST}\n" "--------------------------------------"
  for line in "$@"; do
    printf "  ${BLU}|${RST}  %-56s  ${BLU}|${RST}\n" "$line"
  done
  printf "  ${BOLD}${BLU}+%s+${RST}\n" "-------------------------------------------------------------"
}

tip()          { echo "  ${BOLD}${YLW}[TIP]${RST}${YLW} ${1}${RST}"; }
correct_box()  { echo "  ${BOLD}${BG_GRN}  CORRECT  ${RST}${GRN}  ${1:-}${RST}"; }
wrong_box()    { echo "  ${BOLD}${BG_RED}  WRONG    ${RST}${R}  ${1}${RST}"; }
answer_reveal(){ echo "  ${BOLD}${CYN}  -> Correct answer:${RST}${W} ${1}${RST}"; }

# -- Score helpers ------------------------------------------------------------
_award() {
  local p="$1"
  SCORE=$((SCORE + p)); MAX_SCORE=$((MAX_SCORE + p)); CORRECT=$((CORRECT + 1))
  printf "  ${GRN}${BOLD}+%d pts${RST}\n" "$p"
}

_miss() {
  local p="$1"
  MAX_SCORE=$((MAX_SCORE + p)); WRONG=$((WRONG + 1))
  printf "  ${RED}${BOLD}+0 pts${RST}\n"
}

_half() {
  local p="$1" half
  half=$(( p / 2 )); [[ $half -lt 1 ]] && half=1
  SCORE=$((SCORE + half)); MAX_SCORE=$((MAX_SCORE + p)); RETRIED=$((RETRIED + 1))
  printf "  ${YLW}${BOLD}+%d pts${RST}${YLW} (half credit -- got it on retry)${RST}\n" "$half"
}

# =============================================================================
#  ask_mc -- Multiple choice with per-wrong-option explanations
#
#  ask_mc  "Question"
#          "A text" "B text" "C text" "D text"
#          correct_letter  pts
#          "why_A_wrong" "why_B_wrong" "why_C_wrong" "why_D_wrong"
#          "teaching moment -- use | to separate lines"
#          "memory tip"
# =============================================================================
ask_mc() {
  local q="$1"
  local oa="$2" ob="$3" oc="$4" od="$5"
  local correct="${6^^}" pts="$7"
  local wa="$8" wb="$9" wc="${10}" wd="${11}"
  local teaching="${12}" memtip="${13}"

  # Save state before question
  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank
  echo "  ${W}${q}${RST}"
  blank
  echo "  ${YLW}A)${RST} $oa"
  echo "  ${YLW}B)${RST} $ob"
  echo "  ${YLW}C)${RST} $oc"
  echo "  ${YLW}D)${RST} $od"
  blank

  local ans
  while true; do
    printf "  ${CYN}Your answer [A/B/C/D]: ${RST}"
    read -rsn1 ans

    # Check for Ctrl+N (skip with correct) or Ctrl+B (undo)
    if [[ "$ans" == $'\x0e' ]]; then  # Ctrl+N
      echo
      printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
      correct_box; _award "$pts"
      return 0
    elif [[ "$ans" == $'\x02' ]]; then  # Ctrl+B
      echo
      printf "  ${YLW}[UNDO - Question reset]${RST}\n"
      SCORE="$score_before"
      MAX_SCORE="$max_before"
      CORRECT="$correct_before"
      WRONG="$wrong_before"
      RETRIED="$retried_before"
      # Remove from history
      unset 'QUESTION_HISTORY[-1]'
      QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
      return 0
    fi

    ans="${ans^^}"
    case "$ans" in A|B|C|D) break ;; esac
    echo
    echo "  ${R}  Please type A, B, C or D${RST}"
  done

  if [[ "$ans" == "$correct" ]]; then
    correct_box; _award "$pts"; return
  fi

  local why_theirs
  case "$ans" in
    A) why_theirs="$wa" ;; B) why_theirs="$wb" ;;
    C) why_theirs="$wc" ;; D) why_theirs="$wd" ;;
  esac
  wrong_box "${why_theirs:-That option is incorrect.}"

  local correct_text
  case "$correct" in
    A) correct_text="A) $oa" ;; B) correct_text="B) $ob" ;;
    C) correct_text="C) $oc" ;; D) correct_text="D) $od" ;;
  esac
  answer_reveal "$correct_text"
  _miss "$pts"

  if [[ -n "$teaching" ]]; then
    IFS='|' read -ra tlines <<< "$teaching"
    teach "${tlines[@]}"
  fi
  [[ -n "$memtip" ]] && tip "$memtip"
}

# =============================================================================
#  ask_typed -- Free-text with ONE retry at half points
# =============================================================================
ask_typed() {
  local q="$1" expected="$2" pts="$3"
  local retry_hint="${4:-}" teaching="${5:-}" memtip="${6:-}" mode="${7:-exact}"

  # Save state before question
  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank; echo "  ${W}${q}${RST}"
  printf "  ${CYN}> ${RST}"; local ans ans2

  # Check for Ctrl+N (skip) or Ctrl+B (back) at first input
  read -rsn1 ans_first
  if [[ "$ans_first" == $'\x0e' ]]; then  # Ctrl+N
    echo
    printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
    correct_box; _award "$pts"
    return 0
  elif [[ "$ans_first" == $'\x02' ]]; then  # Ctrl+B
    echo
    printf "  ${YLW}[UNDO - Question reset]${RST}\n"
    SCORE="$score_before"
    MAX_SCORE="$max_before"
    CORRECT="$correct_before"
    WRONG="$wrong_before"
    RETRIED="$retried_before"
    unset 'QUESTION_HISTORY[-1]'
    QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
    return 0
  fi

  # Echo the first character (suppressed by -s) so the user can see what they typed
  printf "%s" "$ans_first"

  # Regular input - continue reading the rest of the line
  read -r ans_rest
  ans="${ans_first}${ans_rest}"

  ans="$(echo "$ans" | xargs 2>/dev/null || echo "$ans")"
  ans="${ans//$'\r'/}"

  _typed_match() {
    local a="${1,,}" e="${2,,}"
    if [[ "$mode" == "contains" ]]; then echo "$a" | grep -qiF "$e"
    else [[ "$a" == "$e" ]]; fi
  }

  if _typed_match "$ans" "$expected"; then
    correct_box; _award "$pts"; return
  fi

  echo "  ${R}  Not quite.${RST}  ${DIM}${retry_hint}${RST}"
  blank
  printf "  ${YLW}  [RETRY] One more try for half points > ${RST}"; read -r ans2
  ans2="$(echo "$ans2" | xargs 2>/dev/null || echo "$ans2")"
  ans2="${ans2//$'\r'/}"

  if _typed_match "$ans2" "$expected"; then
    correct_box "Got it on retry!"; _half "$pts"; return
  fi

  wrong_box "Still not right. Moving on."
  answer_reveal "$expected"; _miss "$pts"
  if [[ -n "$teaching" ]]; then
    IFS='|' read -ra tlines <<< "$teaching"; teach "${tlines[@]}"
  fi
  [[ -n "$memtip" ]] && tip "$memtip"
}

# =============================================================================
#  do_task -- Practical shell task with retry + exact command reveal
# =============================================================================
do_task() {
  local instr="$1" check="$2" pts="$3"
  local exact_cmd="${4:-}" explanation="${5:-}"

  # Save state before question
  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank
  echo "  ${W}${BOLD}[ TASK ]${RST}${W} ${instr}${RST}"
  echo "  ${DIM}-> Run the command in your other terminal, then press ENTER here${RST}"
  echo "  ${DIM}   (Or press Ctrl+N to skip with credit, Ctrl+B to undo)${RST}"

  local input
  read -rsn1 input
  if [[ "$input" == $'\x0e' ]]; then  # Ctrl+N
    echo
    printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
    correct_box "Task verified!"; _award "$pts"
    return 0
  elif [[ "$input" == $'\x02' ]]; then  # Ctrl+B
    echo
    printf "  ${YLW}[UNDO - Question reset]${RST}\n"
    SCORE="$score_before"
    MAX_SCORE="$max_before"
    CORRECT="$correct_before"
    WRONG="$wrong_before"
    RETRIED="$retried_before"
    unset 'QUESTION_HISTORY[-1]'
    QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
    return 0
  fi

  if (cd "$GAMEDIR" && eval "$check" &>/dev/null); then
    correct_box "Task verified!"; _award "$pts"; return
  fi

  blank
  echo "  ${RED}  [X] Check failed. Here is the command:${RST}"
  blank
  [[ -n "$exact_cmd" ]]  && echo "  ${BOLD}${W}  Command:${RST}  ${BOLD}${CYN}${exact_cmd}${RST}"
  [[ -n "$explanation" ]] && echo "  ${DIM}  Why: ${explanation}${RST}"
  blank
  echo "  ${YLW}  Run that now, then press ENTER for half points:${RST}"
  read -r

  if (cd "$GAMEDIR" && eval "$check" &>/dev/null); then
    correct_box "Task done after hint!"; _half "$pts"; return
  fi

  wrong_box "Task still not completed. Moving on."; _miss "$pts"
}

# =============================================================================
#  SETUP
# =============================================================================
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOGFILE" 2>/dev/null; }

setup_game() {
  rm -rf "$GAMEDIR"
  mkdir -p "$GAMEDIR"/{mission,logs,secure,scripts,data,reports}
  log "Game started v${VERSION}"

  echo "dojomaster Mission Log" > "$GAMEDIR/mission/briefing.txt"
  echo "Date: $(date)" >> "$GAMEDIR/mission/briefing.txt"
  echo "Status: ACTIVE" >> "$GAMEDIR/mission/briefing.txt"

  cat > "$GAMEDIR/logs/server.log" <<'EOF'
2025-01-14 08:01:02 INFO  Server started
2025-01-14 08:01:05 INFO  Database connected
2025-01-14 08:03:12 ERROR NullPointerException in UserService.java:42
2025-01-14 08:03:13 ERROR Failed to process request /api/users
2025-01-14 08:15:00 INFO  Health check OK
2025-01-14 09:00:01 WARN  High memory usage: 87%
2025-01-14 09:00:02 ERROR OutOfMemoryError in ReportService.java:99
2025-01-14 09:00:03 ERROR Server response time: 12000ms
2025-01-14 09:30:00 INFO  Backup completed
2025-01-14 10:00:00 ERROR Database connection lost
2025-01-14 10:00:01 ERROR Retry attempt 1 of 3
2025-01-14 10:00:05 ERROR Retry attempt 2 of 3
2025-01-14 10:00:10 ERROR Retry attempt 3 of 3 - FAILED
2025-01-14 10:01:00 INFO  Failover to backup database
2025-01-14 10:05:00 INFO  Service restored
EOF

  cat > "$GAMEDIR/data/users.csv" <<'EOF'
id,username,role,active
1,alice,admin,true
2,bob,developer,true
3,charlie,developer,false
4,diana,admin,true
5,evan,viewer,true
6,frank,developer,false
7,grace,admin,true
EOF

  echo "CLASSIFIED. Access restricted to authorized personnel only." \
    > "$GAMEDIR/secure/README.txt"

  cat > "$GAMEDIR/scripts/deploy.sh" <<'EOF'
#!/bin/bash
echo "Deploying application..."
docker compose up -d
EOF

  cat > "$GAMEDIR/data/config.properties" <<'EOF'
server.port=8080
server.host=localhost
database.url=jdbc:mysql://localhost:3306/myapp
database.username=admin
database.password=CHANGEME_BEFORE_DEPLOY
debug.mode=false
log.level=INFO
cache.enabled=true
max.connections=100
session.timeout=3600
EOF
}

# =============================================================================
#  DETECT ENVIRONMENT
# =============================================================================
detect_env() {
  local os shell_name bash_ver
  case "$(uname -s 2>/dev/null)" in
    Darwin)  os="macOS" ;;
    Linux)   os="Linux" ;;
    MINGW*|MSYS*|CYGWIN*) os="Windows (Git Bash)" ;;
    *)       os="Unknown" ;;
  esac
  shell_name="$(basename "${SHELL:-bash}")"
  bash_ver="${BASH_VERSION%%(*}"
  bash_ver="${bash_ver%%-*}"
  printf "  ${DIM}System: %s  |  Shell: %s %s${RST}\n" "$os" "$shell_name" "$bash_ver"
}

# =============================================================================
#  INTRO
# =============================================================================
intro() {
  clear

  # -- Banner ------------------------------------------------------------------
  printf "${BOLD}${CYN}"
  cat <<'BANNER'
                                              ,-=;?uc;`????=n,
                                             ;cr=?{?{?{?c;3b;;"c
                                           .} b$$$b4-';;L3e;?;?r
                                         4"u $$$$$$$u^/;uh`$u);lr
                                          :c 3c=$$P""$e.x.;?cu;;.     ,nMMMMMMMP=
                                             h ,$$.,,3$$b u4;/    xMMTTCMMM=-
                                               $$???$$$$$$$->" . .nx4MMETMMMM=
                                                 ?,  d$$P" ,c$$$$$c. 4MMCCCMnn,
                                                   `"??",d$$$$$$$$$$$$ MMTTC3M"`
                                                       ,$$$$$$$$$$$$$$$$$.""""??
                                                 .c$$$$$$$$$$$$$$$$$$$$$$$u
                                             .,$$$$$$$$$$$$$$PF ,ze,<$$$$$$
                                    z$$$$$$$$$$$$$PF' c$$d d$$$$$$$$$$$
                                      '?$$$$F            4$;'d$$$$$$$$$$$$$;
                                                            `''d$$$$$$$$$$$$$$$h
                                                            c$$$$$$$$$$$$$$$$$$b.
                                                       <$$$$$$$$$$$$$$$$$$$$$$c
                                                        $"$$$$$$$$$$$$$$$$$$$$$$.
                                                       $$$$$$$$$$$$$"?$$$$$$$$$$.
                                                        ?$$$$$$$P",c$$$$$$$$$$$$
                                                         ?$$$$F c$$$$$$$$$$$$$$$
                                                       u$$c.`" $$$$$$$$$$$$$$$$"
                                                      $$$$$$$ $$$$$$$$$$$$$$$F
                                                     $$$$$$$ $$$$$$$$$$$$$P"
                                                    $$$$$$$$ $$$$$$$$$$P"
                                                   d$$$$$$$b $$$$$$$$$$$$c
                                                   J$$$$$$$$c ?$$$$$$$$$$$$u$$c
                                                   $$$$$$???"   =c$$$$$$$$P$$$P
                                                   $$$$$$$$F          "  z$$$$
                                                  <$$$$$$$c             c$$$$$
                                                   $$$$$$$%              "  "
                                                   `$$$$$"
                                              _,ue$$$$$$c
 _______   ______          __    ______      .___  ___.      ___           _______.___________. _______ .______
|       \ /  __  \        |  |  /  __  \     |   \/   |     /   \         /       |           ||   ____||   _  \
|  .--.  |  |  |  |       |  | |  |  |  |    |  \  /  |    /  ^  \       |   (----`---|  |----`|  |__   |  |_)  |
|  |  |  |  |  |  | .--.  |  | |  |  |  |    |  |\/|  |   /  /_\  \       \   \       |  |     |   __|  |      /
|  '--'  |  `--'  | |  `--'  | |  `--'  |    |  |  |  |  /  _____  \  .----)   |      |  |     |  |____ |  |\  \----.
|_______/ \______/   \______/   \______/     |__|  |__| /__/     \__\ |_______/       |__|     |_______|| _| `._____|

BANNER
  printf "${RST}"

  printf "  ${W}Master the Linux terminal. One zone at a time.${RST}\n"
  printf "  ${DIM}v%s  --  https://github.com/bixson/dojomaster${RST}\n" "$VERSION"
  blank
  detect_env
  blank
  bigcap
  blank

  # -- Zone map ----------------------------------------------------------------
  echo "  ${BOLD}${W}WHAT YOU WILL TRAIN${RST}"
  blank
  echo "  ${CYN}[1]${RST} Navigation    ${DIM}cd, ls, pwd, mkdir${RST}"
  echo "  ${CYN}[2]${RST} File Ops      ${DIM}touch, cp, mv, echo, >, >>${RST}"
  echo "  ${CYN}[3]${RST} Text Search   ${DIM}cat, head, tail, grep${RST}"
  echo "  ${CYN}[4]${RST} Pipes         ${DIM}|, >, >>, <, wc${RST}"
  echo "  ${CYN}[5]${RST} Permissions   ${DIM}chmod, chown, ls -l${RST}"
  echo "  ${CYN}[6]${RST} Processes     ${DIM}ps, kill, top, htop${RST}"
  echo "  ${CYN}[7]${RST} SSH           ${DIM}ssh, scp, authorized_keys${RST}"
  blank
  bigcap
  blank

  # -- How it works ------------------------------------------------------------
  echo "  ${BOLD}${W}HOW WRONG ANSWERS WORK${RST}"
  blank
  echo "  ${RED}[X] Multiple choice${RST}  -- Explains why YOUR specific pick was wrong"
  echo "  ${YLW}[>] Typed answers${RST}    -- One retry for half points after a directional hint"
  echo "  ${YLW}[>] Practical tasks${RST}  -- Exact command revealed, then one retry for half points"
  echo "  ${BLU}[?] Teaching moment${RST}  -- Core rule shown on every miss"
  echo "  ${YLW}[!] Memory tip${RST}       -- Quick mnemonic to lock it in"
  blank

  # -- Grading -----------------------------------------------------------------
  printf "  ${BOLD}${W}GRADING${RST}  "
  printf "${GRN}90%%+ = 12${RST}  "
  printf "${GRN}75%% = 10${RST}  "
  printf "${YLW}55%% = 7${RST}  "
  printf "${Y}35%% = 4${RST}  "
  printf "${R}below = 02${RST}\n"
  blank
  sep
  blank

  # -- Name prompt -------------------------------------------------------------
  printf "  ${CYN}What should I call you? ${RST}"
  read -r PLAYER_NAME
  PLAYER_NAME="${PLAYER_NAME:-stranger}"
  blank

  # -- Start zone select -------------------------------------------------------
  if [[ $START_ZONE -gt 1 ]]; then
    echo "  ${YLW}Jumping to zone ${START_ZONE} as requested.${RST}"
    blank
  else
    echo "  ${DIM}Tip: run  bash dojomaster.sh --zone N  to jump straight to a zone.${RST}"
    blank
    echo "  ${W}Want to start from a specific zone? Enter a number 1-7, or ENTER for zone 1:${RST}"
    printf "  ${CYN}Start zone [1]: ${RST}"
    local zone_pick
    read -r zone_pick
    if [[ "$zone_pick" =~ ^[2-7]$ ]]; then
      START_ZONE="$zone_pick"
      echo "  ${YLW}Starting at zone ${START_ZONE}.${RST}"
    fi
  fi

  blank
  printf "  ${GRN}Let's go, ${BOLD}%s${RST}${GRN}.${RST}\n" "$PLAYER_NAME"
  echo "  ${DIM}Keep a second terminal open at:  cd ${GAMEDIR}${RST}"
  pause
}

# =============================================================================
#  ZONE 1 -- NAVIGATION
# =============================================================================
zone_navigation() {
  zone_header 1 "NAVIGATION" "cd, ls, pwd, mkdir -- know where you are"

  ask_mc "What is the difference between a terminal, a shell, and a command?" \
    "They are all the same thing -- different names for the same app" \
    "Terminal = the window/app  |  Shell = the interpreter e.g. bash  |  Command = what you run e.g. ls" \
    "Shell = the window, Terminal = the interpreter, Command = bash" \
    "Terminal = bash, Shell = the GUI, Command = the cursor" \
    "B" 10 \
    "They are NOT the same. Each is a separate layer on top of the other." \
    "" \
    "Close -- but Terminal and Shell are swapped here. Shell runs INSIDE the terminal." \
    "Completely reversed -- bash IS the shell, not the terminal." \
    "Terminal = the window app (e.g. iTerm2, GNOME Terminal).|Shell = program inside it that reads your input (e.g. bash, zsh).|Command = a specific program you call (e.g. ls, grep, chmod).|They NEST: Terminal -> Shell -> Command." \
    "They nest: Terminal contains Shell, Shell runs Commands."

  ask_mc "You are in /home/alice. What does 'cd ..' do?" \
    "Navigates to the literal path /home/alice/.." \
    "Stays in the same directory -- same as cd ." \
    "Goes up one level to /home" \
    "Goes all the way to the root directory /" \
    "C" 8 \
    "/home/alice/.. is just how the OS represents the parent -- the result IS /home." \
    "Two dots (..) always moves you UP. One dot (.) means stay. They are different." \
    "" \
    "/ is the filesystem root. cd .. goes ONE level up, not all the way to root." \
    "Dots in navigation:|. = current directory (stay put)|.. = parent directory (up one level)|/ = root of the entire filesystem|From /home/alice: cd .. lands you in /home, not /." \
    "One dot = here. Two dots = up one level."

  ask_typed "What command prints your CURRENT working directory?" \
    "pwd" 8 \
    "3-letter command. Think: Print Working Directory." \
    "pwd = Print Working Directory.|Tells you exactly where in the filesystem you are right now.|Example output: /home/alice/projects/myapp" \
    "pwd = Print Working Directory."

  ask_typed "Write the command to list ALL files including hidden ones with detailed info:" \
    "ls -la" 10 \
    "You need two flags. One for hidden files, one for detailed long format." \
    "ls flags:|ls -l  = long format: permissions, owner, size, date|ls -a  = all files: includes hidden files starting with .|ls -la = both combined" \
    "ls -l = Long. ls -a = All. Combined: ls -la"

  ask_mc "You want to create /app/config/prod in ONE command. Parents may not exist. Which flag?" \
    "mkdir /app/config/prod  (works fine without flags)" \
    "mkdir --create-parents /app/config/prod" \
    "mkdir -p /app/config/prod" \
    "mkdir -r /app/config/prod" \
    "C" 10 \
    "Without -p, mkdir fails if the parent /app/config does not exist yet." \
    "--create-parents is not a real mkdir flag." \
    "" \
    "-r does not exist for mkdir. You are thinking of cp -r or chmod -R." \
    "mkdir -p creates ALL missing parent directories in one shot.|Without -p: ERROR if any parent is missing.|With -p: creates /app, /app/config, /app/config/prod all at once." \
    "-p = make Parents too."

  sep; echo "  ${DIM}PRACTICAL -- cd into ${GAMEDIR} in your second terminal first${RST}"; sep

  do_task "Create a directory called 'reports' inside ${GAMEDIR}" \
    "[[ -d reports ]]" 12 \
    "mkdir reports" \
    "mkdir creates a new directory. No flags needed when the parent already exists."

  do_task "Create nested path archive/2025/january in ONE command" \
    "[[ -d archive/2025/january ]]" 12 \
    "mkdir -p archive/2025/january" \
    "-p creates all parent directories that do not yet exist."

  blank; echo "  ${GRN}${BOLD}Zone 1 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 2 -- FILE OPERATIONS
# =============================================================================
zone_files() {
  zone_header 2 "FILE OPERATIONS" "touch, cp, mv, rm, echo, >, >> -- create and move files"

  ask_mc "What does 'touch myfile.txt' do if myfile.txt does NOT yet exist?" \
    "Throws a file-not-found error" \
    "Creates an empty file called myfile.txt" \
    "Creates a directory called myfile.txt" \
    "Deletes the file if it exists, does nothing if it does not" \
    "B" 8 \
    "touch never errors on a missing file -- creating empty files is exactly its purpose." \
    "" \
    "touch creates FILES, not directories. Use mkdir for directories." \
    "That describes rm -f. touch does the opposite: updates the timestamp if the file exists." \
    "touch has two jobs:|1. File does not exist -> creates an empty file|2. File exists -> updates its last-modified timestamp to now|It never throws an error for missing files." \
    "touch = create if missing, update timestamp if existing."

  ask_mc "Which command MOVES a file from /tmp/data.txt to /var/data.txt?" \
    "cp /tmp/data.txt /var/data.txt" \
    "mv /tmp/data.txt /var/data.txt" \
    "rm /tmp/data.txt && cp data.txt /var/" \
    "move /tmp/data.txt /var/data.txt" \
    "B" 8 \
    "cp COPIES -- the original stays at /tmp/data.txt. You would need rm to remove it." \
    "" \
    "This works but is two commands. mv does it atomically in one." \
    "move is a Windows command. On Linux it is always mv." \
    "mv = move (and rename).|cp = copy (original stays).|rm = remove." \
    "mv = Move. cp = Copy. mv removes the source automatically."

  ask_mc "How do you copy an entire directory including all its contents?" \
    "cp /src /dst" \
    "cp -a /src /dst" \
    "cp -r /src /dst" \
    "copy /src /dst" \
    "C" 8 \
    "Without -r, cp refuses to copy a directory: 'omitting directory'." \
    "-a (archive) is valid but -r is the standard expected answer here." \
    "" \
    "copy is a Windows command. On Linux it is always cp." \
    "cp -r = recursive: copies the directory AND everything inside it.|The -r flag is required for any directory copy." \
    "-r = Recursive. Any time you copy a whole directory tree, you need -r."

  ask_typed "Write the command to write 'DEPLOYED' into a file called status.txt without an editor:" \
    "echo DEPLOYED > status.txt" 10 \
    "Use echo to produce the text, then redirect it into the file with >." \
    "echo 'text' prints to screen.|echo 'text' > file redirects into a file (overwrites).|echo 'text' >> file appends to file." \
    "echo text > file. The > sends stdout into the file."

  ask_mc "You want to ADD a second line to status.txt WITHOUT deleting the first. Which operator?" \
    "echo 'line2' > status.txt" \
    "echo 'line2' | status.txt" \
    "echo 'line2' >> status.txt" \
    "append 'line2' to status.txt" \
    "C" 12 \
    "TRAP: > OVERWRITES. The whole first line would be permanently gone." \
    "You cannot pipe directly into a file. Pipe connects to another PROGRAM." \
    "" \
    "append is not a shell command." \
    "> = OVERWRITE (destroys existing content).|>> = APPEND (adds to the end, keeps existing content).|If you see 'without overwriting', the answer is >>." \
    "One arrow > = overwrites. Two arrows >> = appends."

  sep; echo "  ${DIM}PRACTICAL -- work in ${GAMEDIR}${RST}"; sep

  do_task "Create an empty file called 'status.txt'" \
    "[[ -f status.txt ]]" 10 \
    "touch status.txt" "touch creates an empty file."

  do_task "Write 'DEPLOYED' into status.txt" \
    "grep -q 'DEPLOYED' status.txt" 12 \
    "echo 'DEPLOYED' > status.txt" "> redirects echo output into the file."

  do_task "Copy logs/server.log to reports/server.log.backup" \
    "[[ -f reports/server.log.backup ]]" 12 \
    "cp logs/server.log reports/server.log.backup" \
    "cp source destination -- source stays, destination is created."

  blank; echo "  ${GRN}${BOLD}Zone 2 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 3 -- TEXT SEARCH
# =============================================================================
zone_search() {
  zone_header 3 "TEXT SEARCH" "cat, head, tail, grep -- extract signal from noise"

  ask_mc "What does 'head server.log' show by default?" \
    "The file metadata: size, owner, creation date" \
    "The first 10 lines of the file" \
    "The last 10 lines of the file" \
    "A digest or summary of the file content" \
    "B" 8 \
    "head has nothing to do with metadata. Use ls -l or stat for that." \
    "" \
    "That is tail, not head. Head = top. Tail = bottom." \
    "head does not summarise -- it literally prints the first N lines." \
    "head = first N lines (default 10).|tail = last N lines (default 10).|head -n 20 = first 20 lines." \
    "head = top of file. tail = bottom."

  ask_mc "You are monitoring a growing log file live. Which command shows new lines as they appear?" \
    "cat -live server.log" \
    "less -f server.log" \
    "tail -f server.log" \
    "watch server.log" \
    "C" 10 \
    "cat -live is not a real flag. cat dumps the file once and exits." \
    "less is interactive but does not auto-follow new content." \
    "" \
    "watch repeats a command every 2 seconds but does not stream log output." \
    "tail -f = follow mode.|Blocks and prints new lines as they are written.|Press Ctrl+C to exit.|Standard live log monitoring tool." \
    "tail -f = follow the tail. Classic live log monitoring."

  ask_typed "Write the grep command to find all lines containing 'ERROR' in logs/server.log:" \
    "grep ERROR logs/server.log" 10 \
    "grep syntax: grep PATTERN FILE. Pattern first, then the file path." \
    "grep PATTERN FILE = search for PATTERN in FILE.|Quotes around pattern are optional for simple words." \
    "grep pattern file. Pattern first, then file."

  ask_mc "What does 'grep -i' do compared to plain grep?" \
    "Searches files recursively through subdirectories" \
    "Makes the search case-insensitive: ERROR matches error, Error, eRrOr" \
    "Shows only the filename, not the matching lines" \
    "Inverts the match: shows lines that do NOT match" \
    "B" 8 \
    "-i is not recursive. That is -r. Think: -r = Recursive, -i = case-Insensitive." \
    "" \
    "-l shows only filenames. -i changes case sensitivity." \
    "-v inverts the match. -i controls case." \
    "Key grep flags:|grep -i = case Insensitive|grep -r = Recursive|grep -v = inVert|grep -l = List filenames|grep -n = line Numbers" \
    "Flags: -i=Insensitive, -r=Recursive, -v=inVert, -l=List, -n=Numbers."

  ask_typed "Write the grep command to search RECURSIVELY for 'password' in the 'data' directory:" \
    "grep -r password data" 10 \
    "You need a flag that makes grep search inside all subdirectories too." \
    "grep -r searches recursively through a directory and all subdirectories." \
    "grep -r = search Recursively through a whole directory tree."

  sep; echo "  ${DIM}PRACTICAL -- work in ${GAMEDIR}${RST}"; sep

  do_task "Extract all ERROR lines from logs/server.log and save to reports/errors.txt" \
    "[[ -f reports/errors.txt ]] && grep -q 'ERROR' reports/errors.txt" 15 \
    "grep ERROR logs/server.log > reports/errors.txt" \
    "grep filters matching lines, > saves them to a new file."

  do_task "Count how many ERROR lines are in server.log (grep + wc -l)" \
    "grep ERROR logs/server.log | wc -l | grep -qE '^[0-9]+$'" 12 \
    "grep ERROR logs/server.log | wc -l" \
    "Pipe grep output into wc -l to count the matching lines."

  blank; echo "  ${GRN}${BOLD}Zone 3 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 4 -- PIPES & REDIRECTION
# =============================================================================
zone_pipes() {
  zone_header 4 "PIPES & REDIRECTION" "| > >> < -- the plumbing of the shell"

  ask_mc "What does the pipe operator '|' do?" \
    "Writes the output of a command into a file" \
    "Sends the OUTPUT of the left command as the INPUT of the right command" \
    "Runs both commands simultaneously in parallel on all CPU cores" \
    "Separates two independent commands on the same line like a semicolon" \
    "B" 10 \
    "Writing to a file uses >. Pipe | connects two PROGRAMS, not files." \
    "" \
    "Commands in a pipe run sequentially connected by the data stream, not truly in parallel." \
    "Semicolon (;) runs commands independently. Pipe connects them with a data stream." \
    "Pipe | is plumbing:|command1 | command2|Output of command1 flows into command2 as its input.|Data flows left to right." \
    "Pipe = plumbing. Output of left becomes input of right."

  ask_mc "What is the critical difference between '>' and '>>'?" \
    "They do exactly the same thing -- >> is just an older style" \
    "'>' appends to a file, '>>' overwrites the file" \
    "'>' overwrites the file (destroys existing content), '>>' appends to the end" \
    "'>' writes to the screen, '>>' writes to a file" \
    "C" 12 \
    "They are NOT the same. Using > when you meant >> causes silent data loss." \
    "You have them backwards. > overwrites. >> appends." \
    "" \
    "Both operators write to files. Neither writes to the screen by default." \
    "> = OVERWRITE: file is replaced entirely.|>> = APPEND: new content added to the end.|Using > when you meant >> is one of the most common Linux mistakes." \
    "One arrow = overwrites. Two arrows = appends."

  ask_typed "Write a command to count the total number of non-hidden files in the current directory:" \
    "ls | wc -l" 10 \
    "You need two commands connected with a pipe. One lists, one counts lines." \
    "ls prints one filename per line.|wc -l counts lines from stdin.|Do NOT use ls -a -- that adds . and .. making the count 2 too high." \
    "ls outputs lines, pipe sends them to wc -l which counts them."

  ask_mc "You run 'ls hello.* | wc -l' and get 5. But you only created 3 hello.* files. Why?" \
    "wc -l always adds 2 as overhead to its count" \
    "The wildcard hello.* also matches hidden files" \
    "You accidentally used ls -a which always adds . and .. to the listing" \
    "This cannot happen -- the count would always match exactly" \
    "C" 10 \
    "wc -l has no overhead -- it counts exactly what it receives." \
    "hello.* only matches names starting with 'hello.' -- not general hidden files." \
    "" \
    "It absolutely can happen. This is a documented gotcha." \
    "ls -a includes two special entries:|. = the current directory itself|.. = the parent directory|So ls -a | wc -l always reports 2 MORE than actual file count." \
    "ls -a gotcha: always 2 extra entries: . and .."

  ask_typed "Write the full pipe chain to find all ERROR lines in logs/server.log AND count them:" \
    "grep ERROR logs/server.log | wc -l" 12 \
    "Three parts: grep command, pipe, then the counting command." \
    "grep ERROR logs/server.log | wc -l|Stage 1: grep filters to ERROR lines.|Stage 2: wc -l counts the resulting lines." \
    "grep to filter lines, pipe, wc -l to count them."

  ask_mc "What does '<' do in: 'wc -l < server.log'?" \
    "Compares the output of wc -l against the file server.log" \
    "Feeds the contents of server.log as standard input to wc -l" \
    "It is shorthand for cat server.log | wc -l but runs faster" \
    "This is a syntax error" \
    "B" 10 \
    "< is input redirection, not comparison." \
    "" \
    "It produces the same result but is NOT shorthand syntax -- < is input redirection." \
    "< is valid bash syntax. It redirects file content into a program's stdin." \
    "Redirection summary:|> = output to file (overwrite)|>> = output to file (append)|< = file to program input" \
    "Arrow direction = data flow direction. < feeds in. > sends out."

  sep; echo "  ${DIM}PRACTICAL -- work in ${GAMEDIR}${RST}"; sep

  do_task "Count inactive users in data/users.csv (lines with 'false') using grep and wc" \
    "[[ \$(grep false data/users.csv | wc -l | xargs) -eq 2 ]]" 15 \
    "grep false data/users.csv | wc -l" \
    "grep filters matching lines, pipe sends them to wc -l to count."

  do_task "Save only active users (lines with 'true') to reports/active_users.txt" \
    "[[ -f reports/active_users.txt ]] && grep -q 'true' reports/active_users.txt" 15 \
    "grep true data/users.csv > reports/active_users.txt" \
    "grep filters, > saves the results to a new file."

  do_task "APPEND '-- END OF LOG --' to reports/errors.txt without overwriting it" \
    "grep -q 'END OF LOG' reports/errors.txt" 12 \
    "echo '-- END OF LOG --' >> reports/errors.txt" \
    ">> appends. If you used >, the entire file would be replaced."

  blank; echo "  ${GRN}${BOLD}Zone 4 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 5 -- PERMISSIONS
# =============================================================================
zone_permissions() {
  zone_header 5 "PERMISSIONS" "chmod, chown, ls -l -- who can do what to which file"

  ask_mc "What do the 10 characters in '-rwxr-xr--' represent?" \
    "File type, then read/write/execute permissions for user, group, and others" \
    "All 10 characters show the current user's permissions in different contexts" \
    "The first 4 are for the owner, the next 3 for group, the last 3 for others" \
    "They show allowed commands without a type prefix character" \
    "A" 10 \
    "" \
    "There are three separate groups shown here. The first char is the file type." \
    "Owner gets 3 characters (positions 2-4), not 4. Count: -|rwx|r-x|r--" \
    "The first character IS the file type (- or d). It is part of the format." \
    "10 characters total:|[0]   = file type: '-' = file, 'd' = directory|[1-3] = user/owner: rwx|[4-6] = group:       r-x|[7-9] = others:      r--|Example: -rwxr-xr--" \
    "Position 0=type, 1-3=user, 4-6=group, 7-9=others."

  ask_mc "What is the octal value of 'rwx'?" \
    "6" "5" "3" "7" \
    "D" 10 \
    "6 = rw- (4+2). You are missing execute (x=1)." \
    "5 = r-x (4+1). You are missing write (w=2)." \
    "3 = -wx (2+1). You are missing read (r=4)." \
    "" \
    "r = 4, w = 2, x = 1.|rwx = 4+2+1 = 7|rw- = 4+2+0 = 6|r-x = 4+0+1 = 5|r-- = 4+0+0 = 4|--- = 0" \
    "r=4, w=2, x=1. rwx = 4+2+1 = 7. Max is always 7."

  ask_typed "chmod 755 deploy.sh -- describe owner permissions:" \
    "rwx" 12 \
    "What does the 7 mean? Use r=4, w=2, x=1." \
    "7 = rwx: read(4) + write(2) + execute(1) = 7|rwx = full permissions for owner" \
    "7 = rwx. That's full permissions."

  ask_mc "What octal value represents the permissions '-rw-r--r--'?" \
    "755" "644" "600" "666" \
    "B" 10 \
    "755 = rwxr-xr-x. There are execute bits in 755 but none in -rw-r--r--." \
    "" \
    "600 = rw-------. Only the owner can access. Nobody else can even read it." \
    "666 = rw-rw-rw-. Everyone can read and write -- too permissive." \
    "Reading -rw-r--r--:|user: rw- = 6, group: r-- = 4, others: r-- = 4|Result: 644|Classic config file permission." \
    "644 = config files. 755 = executables. 600 = private. 700 = private dirs."

  ask_typed "Write the chmod command to give owner rwx, group r-x, others nothing:" \
    "chmod 750" 10 \
    "Calculate: owner=rwx=7, group=r-x=5, others=---=0. Full command?" \
    "chmod 750:|7 = rwx (owner -- full control)|5 = r-x (group -- read and run)|0 = --- (others -- locked out)" \
    "0 = no permissions at all. 750 = owner full, group r+x, others nothing."

  ask_mc "What does 'chown alice:developers file.txt' do?" \
    "Changes file.txt permissions to 755 for alice in the developers group" \
    "Sets the owner to 'alice' AND the group to 'developers' in one command" \
    "Only changes the group to 'developers' -- owner left unchanged" \
    "Copies file.txt to alice's home inside a folder called developers" \
    "B" 10 \
    "chown sets ownership, not permissions. Use chmod for permissions." \
    "" \
    "user:group syntax changes BOTH owner and group at once." \
    "chown does not copy files. cp does that." \
    "chown syntax:|chown user file         -> owner only|chown user:group file   -> owner AND group|chown -R user:group dir -> recursive" \
    "chown user:group. Colon separates user from group."

  ask_mc "Correct permissions for ~/.ssh/authorized_keys (SSH security requirement):" \
    "chmod 755 authorized_keys" \
    "chmod 644 authorized_keys" \
    "chmod 600 authorized_keys" \
    "chmod 777 authorized_keys" \
    "C" 12 \
    "755 lets group and others execute -- SSH refuses keys with open permissions." \
    "644 lets everyone READ your authorized_keys -- SSH rejects this." \
    "" \
    "777 = world access. SSH immediately rejects this." \
    "SSH strict permission requirements:|~/.ssh directory     -> chmod 700|~/.ssh/authorized_keys -> chmod 600|~/.ssh/id_rsa         -> chmod 600|Too open = SSH silently refuses to use the keys." \
    "SSH key files = 600. SSH directory = 700."

  sep; echo "  ${DIM}PRACTICAL -- work in ${GAMEDIR}${RST}"; sep

  do_task "Make scripts/deploy.sh executable by the owner" \
    "[[ -x scripts/deploy.sh ]]" 15 \
    "chmod +x scripts/deploy.sh" \
    "+x adds execute permission for the owner."

  do_task "Lock down secure/ so ONLY the owner has any access (700 = rwx------)" \
    "[[ \"\$(stat -c '%a' secure 2>/dev/null || stat -f '%A' secure 2>/dev/null)\" == '700' ]]" 15 \
    "chmod 700 secure" \
    "700 = rwx------. Owner gets everything, group and others get nothing."

  do_task "Set data/config.properties to owner read+write only (600 = rw-------)" \
    "[[ \"\$(stat -c '%a' data/config.properties 2>/dev/null || stat -f '%A' data/config.properties 2>/dev/null)\" == '600' ]]" 12 \
    "chmod 600 data/config.properties" \
    "600 = rw-------. Only the owner can read or write. No one else can even read it."

  blank; echo "  ${GRN}${BOLD}Zone 5 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 6 -- PROCESSES
# =============================================================================
zone_processes() {
  zone_header 6 "PROCESSES" "ps, top, htop, kill -- see and control what is running"

  ask_mc "What does plain 'ps' (no flags) show?" \
    "All processes from all users including background daemons" \
    "The top 10 processes sorted by CPU usage" \
    "Only your own interactive processes in the current terminal session" \
    "All processes sorted by memory with PID and owner columns" \
    "C" 10 \
    "Plain ps is intentionally very limited. Use ps ax or ps aux to see everything." \
    "That is top or htop. ps gives a one-time snapshot." \
    "" \
    "ps alone only shows your current terminal's processes and does not sort." \
    "ps variants:|ps    = your interactive processes only|ps x  = your processes including background|ps ax = ALL processes from ALL users|ps aux = all + user and resource columns|ps faux = all as a process tree" \
    "Bare ps = almost useless. Always use ps ax in practice."

  ask_typed "Write the ps command to show ALL processes from ALL users including background daemons:" \
    "ps ax" 10 \
    "Two single-letter flags: one for all users, one for background processes." \
    "ps ax:|a = all users|x = background/daemon processes too|Together = the complete picture." \
    "ps ax = all users (a) + all background (x)."

  ask_typed "Write the command chain to check if nginx is running:" \
    "ps ax | grep nginx" 10 \
    "List all processes, then filter them. What command filters lines of text?" \
    "ps ax | grep nginx:|ps ax = list all processes|grep nginx = show only lines containing 'nginx'" \
    "ps ax to list, pipe to grep to filter. Classic check."

  ask_mc "What is the PID?" \
    "Priority Interface Daemon -- the process scheduler priority number" \
    "Parent ID -- the process that created this process" \
    "Process ID -- a unique number the OS assigns to each running process" \
    "Program Identifier -- the filename of the running executable" \
    "C" 8 \
    "Process priority in Linux is the 'nice' value (NI), not PID." \
    "That is the PPID (Parent Process ID). Different thing." \
    "" \
    "The executable name is in the CMD column. PID is the unique process number." \
    "PID = Process ID.|Unique number assigned by the OS to each running process.|You need the PID to send signals / kill a process.|First column in ps ax output." \
    "PID = Process ID. First column in ps output."

  ask_mc "A process is stuck and normal 'kill PID' did nothing. What do you try?" \
    "kill --hard PID" "kill -9 PID" "kill -force PID" "stop PID" \
    "B" 10 \
    "--hard is not a real signal name." \
    "" \
    "-force is not a valid kill flag. The correct syntax is kill -9." \
    "stop is not a standard process-killing command." \
    "kill signals:|kill PID    = SIGTERM (15): polite, process can ignore it|kill -9 PID = SIGKILL: OS forcibly terminates, cannot be ignored|Use -9 when the process is frozen and does not respond." \
    "kill = polite. kill -9 = forceful. -9 cannot be ignored."

  ask_mc "You run 'ps ax | grep nginx' and see exactly TWO result lines. How many nginx processes are running?" \
    "2" "1" "0 -- both are the grep process itself" "Cannot be determined" \
    "B" 10 \
    "One of those lines IS the grep process showing itself. Subtract 1." \
    "" \
    "grep shows itself, but the other line is the actual nginx process." \
    "You have enough info: 2 results - 1 (grep itself) = 1 actual nginx." \
    "grep always shows itself in ps output.|Fix: ps ax | grep [n]ginx  (bracket trick)|Or: pgrep nginx" \
    "grep trap: always subtract 1 for grep itself."

  blank; echo "  ${GRN}${BOLD}Zone 6 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 7 -- SSH
# =============================================================================
zone_ssh() {
  zone_header 7 "SSH & REMOTE ACCESS" "ssh, scp, authorized_keys, public key auth -- last zone"

  ask_mc "What is SSH?" \
    "Simple Shell -- a lightweight version of bash for servers" \
    "Secure Shell -- an encrypted protocol for remote terminal access" \
    "Server Side Hosting -- a platform for deploying web applications" \
    "System Shell Handler -- manages multiple shell sessions" \
    "B" 10 \
    "SSH has nothing to do with bash. It is a network protocol." \
    "" \
    "SSH is a network protocol for remote access, not a hosting platform." \
    "SSH is for encrypted remote terminal access, not session management." \
    "SSH = Secure Shell.|Cryptographic network protocol.|Encrypted remote terminal access.|Port 22 by default.|Replaced old unencrypted tools like telnet." \
    "SSH = Secure Shell. Encrypted remote terminal. Port 22."

  ask_mc "How does SSH public key authentication work at a high level?" \
    "Your password is hashed locally and compared to a hash on the server" \
    "The server generates a one-time password and sends it to you" \
    "You have a private+public key pair. Public key is on the server. You prove ownership of the private key via cryptographic challenge. No password crosses the network." \
    "Both machines share a pre-agreed symmetric secret configured during setup" \
    "C" 12 \
    "Password hashing describes password-based auth. SSH key auth uses no passwords at all." \
    "SSH key auth does not involve OTPs or email." \
    "" \
    "It uses asymmetric cryptography, not a pre-shared symmetric secret." \
    "SSH public key auth flow:|1. Your public key is in ~/.ssh/authorized_keys on the server|2. Server sends a cryptographic challenge|3. Your client signs it with your private key|4. Server verifies the signature with your public key|5. Match = access granted. No password ever sent." \
    "Private key = never leaves your machine. Public key = safe anywhere."

  ask_typed "Write the SSH command to connect to 188.1.2.3 as user 'ubuntu':" \
    "ssh ubuntu@188.1.2.3" 10 \
    "Syntax: ssh user@host. Use @ to separate username from IP." \
    "ssh user@hostname|ssh user@IP_address|The @ separates username from address -- same as email format." \
    "ssh user@host. The @ separates username from host."

  ask_typed "Write the SSH command to connect using a private key file called 'mykey.pem':" \
    "ssh -i mykey.pem ubuntu@188.1.2.3" 10 \
    "There is a flag for specifying the key file. Think: i for identity. The flag goes BEFORE the username." \
    "ssh -i /path/to/private_key user@host|-i = identity file: the path to your private key|Common with cloud VMs on AWS, DigitalOcean, Azure." \
    "ssh -i = identity file (path to your private key). Flag before username."

  ask_mc "Where on the SERVER are authorised public keys stored for a given user?" \
    "/etc/ssh/authorized_keys for all users centrally" \
    "/root/ssh/public_keys regardless of which user" \
    "~/.ssh/authorized_keys in the HOME directory of the user you log in as" \
    "/etc/ssh/sshd_config alongside the server config" \
    "C" 10 \
    "There is no /etc/ssh/authorized_keys for individual users." \
    "The path is ~/.ssh/ (with a dot, hidden dir) and the file is authorized_keys." \
    "" \
    "sshd_config is the SSH server config file -- not where individual keys live." \
    "SSH key locations:|CLIENT: ~/.ssh/id_rsa (private), ~/.ssh/id_rsa.pub (public)|SERVER: ~/.ssh/authorized_keys (one public key per line)|SSH checks this file to allow login." \
    "authorized_keys is in the user's home directory: ~/.ssh/authorized_keys"

  ask_typed "Write the SCP command to copy local file 'compose.yaml' to the home dir on 188.1.2.3 as ubuntu:" \
    "scp compose.yaml ubuntu@188.1.2.3:~/" 12 \
    "SCP is like cp but one side is remote. Format: scp source user@host:path. Home directory is ~/" \
    "scp = secure copy (uses SSH).|Upload: scp local_file user@host:~/remote/|Download: scp user@host:/remote/file ./local/|The colon ':' separates hostname from remote path. Use ~/ for home." \
    "scp local remote. Remote = user@host:path. Home = ~/"

  ask_typed "Write the SCP command to DOWNLOAD /var/log/app.log from the server to your current directory:" \
    "scp ubuntu@188.1.2.3:/var/log/app.log ." 12 \
    "Now the remote path is the SOURCE. Local current directory (.) is the destination." \
    "scp download:|scp user@host:/remote/path ./local/|'.' = your current local directory." \
    "Download = remote source first, local destination second. Dot = here."

  ask_mc "Which file must NEVER be shared with anyone?" \
    "~/.ssh/id_rsa.pub -- it contains your full identity" \
    "~/.ssh/id_rsa -- the private key must stay on your machine only" \
    "~/.ssh/known_hosts -- it maps server hostnames to fingerprints" \
    "~/.ssh/authorized_keys -- it is too sensitive" \
    "B" 12 \
    "id_rsa.pub IS the public key -- designed to be shared. Put it in authorized_keys on servers." \
    "" \
    "known_hosts is maintained automatically by SSH. Not sensitive." \
    "authorized_keys contains public keys -- not the secret half." \
    "SSH key pair:|id_rsa     = PRIVATE. Never share. Never upload.|id_rsa.pub = PUBLIC. Safe to share. Goes into authorized_keys.|Rule: .pub = public = safe. No .pub = private = never share." \
    ".pub = public = safe. No extension = private = NEVER share."

  ask_mc "What permissions must ~/.ssh have for SSH to work?" \
    "chmod 755 ~/.ssh" "chmod 644 ~/.ssh" "chmod 777 ~/.ssh" "chmod 700 ~/.ssh" \
    "D" 12 \
    "755 lets group and others enter the directory -- SSH rejects this." \
    "644 lets others read the directory contents -- SSH rejects this." \
    "777 = world access. SSH immediately refuses to use any keys." \
    "" \
    "SSH strict permission requirements:|~/.ssh dir          -> chmod 700|authorized_keys     -> chmod 600|id_rsa              -> chmod 600|Too open = SSH silently ignores your keys." \
    ".ssh = 700. authorized_keys = 600. id_rsa = 600."

  blank; echo "  ${GRN}${BOLD}Zone 7 complete! -- ALL ZONES CLEARED!${RST}"; pause
}

# =============================================================================
#  RESULTS
# =============================================================================
results() {
  clear
  bigcap
  printf "  ${BOLD}${CYN}MISSION COMPLETE -- RESULTS FOR ${W}%s${RST}\n" "$PLAYER_NAME"
  bigcap; blank

  local pct=0
  [[ $MAX_SCORE -gt 0 ]] && pct=$(( (SCORE * 100) / MAX_SCORE ))

  local grade grade_col grade_msg
  if   [[ $pct -ge 90 ]]; then grade=12; grade_col="${GRN}"; grade_msg="Outstanding. You own the terminal."
  elif [[ $pct -ge 75 ]]; then grade=10; grade_col="${GRN}"; grade_msg="Excellent. Solid performance."
  elif [[ $pct -ge 55 ]]; then grade=7;  grade_col="${YLW}"; grade_msg="Good pass. Review your weak zones."
  elif [[ $pct -ge 35 ]]; then grade=4;  grade_col="${Y}";   grade_msg="Barely passing. More drilling needed."
  else                          grade=02; grade_col="${RED}"; grade_msg="Run it again from zone 1."
  fi

  printf "  ${W}SCORE:${RST}   ${BOLD}${grade_col}%d${RST} / %d pts\n" "$SCORE" "$MAX_SCORE"
  pbar "$SCORE" "$MAX_SCORE" 50
  blank
  printf "  ${W}GRADE:${RST}   ${grade_col}${BOLD} %s ${RST}\n" "$grade"
  printf "  ${W}VERDICT:${RST} ${DIM}%s${RST}\n" "$grade_msg"
  blank
  sep; blank
  echo "  ${W}BREAKDOWN${RST}"
  printf "  ${GRN}First-try correct:${RST}  %d\n" "$CORRECT"
  printf "  ${YLW}Correct on retry:${RST}   %d\n" "$RETRIED"
  printf "  ${RED}Missed entirely:${RST}    %d\n" "$WRONG"
  printf "  ${CYN}Total questions:${RST}    %d\n" "$((CORRECT + RETRIED + WRONG))"
  blank
  sep; blank
  echo "  ${W}KEY FACTS TO LOCK IN BEFORE ANY LINUX EXAM${RST}"
  blank
  printf "  ${YLW}Terminal / Shell / Command${RST}\n"
  printf "  ${DIM}  Terminal = window | Shell = bash | Command = ls, grep, etc.${RST}\n"
  blank
  printf "  ${YLW}Redirection (most tested)${RST}\n"
  printf "  ${DIM}  > overwrites | >> appends | < feeds file as input | | connects programs${RST}\n"
  blank
  printf "  ${YLW}chmod numbers${RST}\n"
  printf "  ${DIM}  r=4 w=2 x=1 | 755=rwxr-xr-x | 644=rw-r--r-- | 600=rw------- | 700=rwx------${RST}\n"
  blank
  printf "  ${YLW}SSH rules${RST}\n"
  printf "  ${DIM}  Private key NEVER leaves your machine|Public key -> authorized_keys${RST}\n"
  printf "  ${DIM}  .ssh dir = chmod 700 | authorized_keys = chmod 600${RST}\n"
  printf "  ${DIM}  scp file user@host:~/  = upload | scp user@host:/path .  = download${RST}\n"
  blank
  printf "  ${YLW}Process hunting${RST}\n"
  printf "  ${DIM}  ps ax | grep name | subtract 1 for grep itself | kill -9 = force kill${RST}\n"
  blank
  printf "  ${YLW}ls -a gotcha${RST}\n"
  printf "  ${DIM}  ls -a | wc -l is always 2 too high: . and .. are not real files${RST}\n"
  blank
  sep; blank
  bigcap
  printf "  ${GRN}Thanks for playing dojomaster, ${BOLD}%s${RST}${GRN}!${RST}\n" "$PLAYER_NAME"
  printf "  ${DIM}Star the repo: https://github.com/bixson/dojomaster${RST}\n"
  printf "  ${DIM}ASCII art generated with TAAG (patorjk.com)${RST}\n"
  blank
  log "Game ended. Score: ${SCORE}/${MAX_SCORE} (${pct}%) Grade: ${grade}"
}

# =============================================================================
#  TRAP + MAIN
# =============================================================================
on_exit() {
  echo; blank
  printf "  ${YLW}Interrupted. Score so far: %d/%d${RST}\n" "$SCORE" "$MAX_SCORE"
  log "Interrupted at zone ${ZONE}. Score: ${SCORE}/${MAX_SCORE}"
  exit 0
}
trap on_exit INT TERM

main() {
  parse_args "$@"
  setup_game
  intro

  [[ $START_ZONE -le 1 ]] && zone_navigation
  [[ $START_ZONE -le 2 ]] && zone_files
  [[ $START_ZONE -le 3 ]] && zone_search
  [[ $START_ZONE -le 4 ]] && zone_pipes
  [[ $START_ZONE -le 5 ]] && zone_permissions
  [[ $START_ZONE -le 6 ]] && zone_processes
  [[ $START_ZONE -le 7 ]] && zone_ssh

  results
}

main "$@"

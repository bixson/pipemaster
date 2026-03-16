#!/usr/bin/env bash
# =============================================================================
#
#   NETMASTER  --  Master TCP/IP + DNS + HTTP for a networking exam.
#   One zone at a time.
#
#   Covers: OSI/TCP-IP Model, IP & MAC addresses, Router vs Switch,
#           Ports, TCP fields (SRC/DST/ACK/TTL), DNS record types,
#           TTL in DNS, Authoritative vs Caching nameservers,
#           Recursive resolution, dig lab (root -> TLD -> authoritative),
#           HTTP methods, status codes, headers, cookies & sessions
#
#   Works on: macOS, Linux, Git Bash (Windows)
#   Requires: bash 4.0+   (dig recommended for Zone 7 lab)
#
#   Usage:
#     bash netmaster.sh               # full journey, all zones
#     bash netmaster.sh --zone 5      # jump to a zone
#     bash netmaster.sh --list        # show all zones
#     bash netmaster.sh --reset       # wipe saved progress
#     bash netmaster.sh --help        # this help
#
# =============================================================================

VERSION="2.0.0"
GAME_NAME="netmaster"
GAMEDIR="$HOME/.netmaster"
LOGFILE="$GAMEDIR/session.log"

# -- Colours (matching dojomaster/dockermaster) --------------------------------
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
declare -a QUESTION_HISTORY=()
PREV_Q_ARGS=()
PREV_Q_FUNC=""
BACK_TO_INTRO=false

# =============================================================================
#  CLI FLAGS
# =============================================================================
show_help() {
  cat << 'HELP'

  netmaster v2.0.0 -- Master TCP/IP + DNS + HTTP. One zone at a time.

  USAGE
    bash netmaster.sh               Run the full game
    bash netmaster.sh --zone N      Start at zone N (1-8)
    bash netmaster.sh --list        List all zones
    bash netmaster.sh --reset       Wipe saved progress
    bash netmaster.sh --help        Show this help
    bash netmaster.sh --version     Show version

  ZONES
    1  OSI & TCP/IP Model      layers, encapsulation
    2  IP & MAC Addresses      private vs public, ifconfig
    3  Router, Switch & Ports  DHCP, common ports
    4  TCP Packet Fields       SRC/DST/ACK/TTL, traceroute
    5  DNS Basics & Records    A, AAAA, CNAME, MX, NS, TXT, PTR
    6  TTL in DNS & Nameservers  authoritative vs recursive resolver
    7  dig Lab                 root -> TLD -> authoritative (live)  [+ lab]
    8  HTTP                    methods, status codes, headers, sessions

  SCORING
    90%+ = 12    75%+ = 10    55%+ = 7    35%+ = 4    <35% = 02

  HOW WRONG ANSWERS WORK
    Multiple choice  ->  Explains why YOUR specific pick was wrong
    Typed answers    ->  One retry for half points after a hint
    Teaching moment  ->  Key rule shown on every miss
    Memory tip       ->  Quick mnemonic to lock it in

  CONTROLS
    Ctrl+N  -- skip question and mark as correct
    Ctrl+B  -- undo last question

HELP
  exit 0
}

show_list() {
  echo
  echo "  ${BOLD}${CYN}netmaster v${VERSION} -- Zones${RST}"
  echo
  echo "  ${YLW}1${RST}  OSI & TCP/IP Model      layers, encapsulation"
  echo "  ${YLW}2${RST}  IP & MAC Addresses      private vs public, ifconfig"
  echo "  ${YLW}3${RST}  Router, Switch & Ports  DHCP, common ports"
  echo "  ${YLW}4${RST}  TCP Packet Fields       SRC/DST/ACK/TTL, traceroute"
  echo "  ${YLW}5${RST}  DNS Basics & Records    A, AAAA, CNAME, MX, NS, TXT, PTR"
  echo "  ${YLW}6${RST}  TTL in DNS & Nameservers  authoritative vs recursive"
  echo "  ${YLW}7${RST}  dig Lab  root -> TLD -> authoritative  ${DIM}[+ lab]${RST}"
  echo "  ${YLW}8${RST}  HTTP  methods, status codes, headers, sessions"
  echo
  echo "  Run: bash netmaster.sh --zone N  to start at zone N"
  echo
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)    show_help ;;
      --list|-l)    show_list ;;
      --version|-v) echo "netmaster v${VERSION}"; exit 0 ;;
      --reset)
        rm -f "$GAMEDIR"/*.done
        echo "  ${GRN}Progress reset.${RST}"; exit 0 ;;
      --zone|-z)
        if [[ -z "${2:-}" || ! "${2:-}" =~ ^[1-8]$ ]]; then
          echo "  Error: --zone requires a number 1-8"; exit 1
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
pause()  { echo; printf "  ${DIM}[ Press ENTER to continue ]${RST}"; read -r; clear; }
blank()  { echo; }

pbar() {
  local cur="$1" max="$2" width="${3:-40}"
  local filled=$(( (cur * width) / max ))
  local bar="" i
  for ((i=0; i<filled; i++));     do bar+="#"; done
  for ((i=filled; i<width; i++)); do bar+="-"; done
  local pct=$(( (cur * 100) / max ))
  printf "  [%s] %d%%\n" "$bar" "$pct"
}

zone_header() {
  local num="$1" name="$2" sub="$3"
  clear; ZONE="$num"
  bigcap
  printf "  ${BOLD}${CYN}ZONE %s // %s${RST}\n" "$num" "$name"
  printf "  ${DIM}%s${RST}\n" "$sub"
  bigcap; blank
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

tip()           { echo "  ${BOLD}${YLW}[TIP]${RST}${YLW} ${1}${RST}"; }
correct_box()   { echo "  ${BOLD}${BG_GRN}  CORRECT  ${RST}${GRN}  ${1:-}${RST}"; }
wrong_box()     { echo "  ${BOLD}${BG_RED}  WRONG    ${RST}${R}  ${1}${RST}"; }
answer_reveal() { echo "  ${BOLD}${CYN}  -> Correct answer:${RST}${W} ${1}${RST}"; }

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
  printf "  ${YLW}${BOLD}+%d pts${RST}${YLW} (half credit -- correct on retry)${RST}\n" "$half"
}

# =============================================================================
#  ask_mc -- Multiple choice A/B/C/D with per-wrong-option explanations
#
#  ask_mc  "Question"
#          "A text" "B text" "C text" "D text"
#          correct_letter  pts
#          "why_A_wrong" "why_B_wrong" "why_C_wrong" "why_D_wrong"
#          "teaching moment -- pipe | to separate lines"
#          "memory tip"
# =============================================================================
ask_mc() {
  [[ "$BACK_TO_INTRO" == true ]] && return 0
  local q="$1"
  local oa="$2" ob="$3" oc="$4" od="$5"
  local correct="${6^^}" pts="$7"
  local wa="$8" wb="$9" wc="${10}" wd="${11}"
  local teaching="${12}" memtip="${13}"

  local saved_prev=("${PREV_Q_ARGS[@]}")
  local saved_prev_func="$PREV_Q_FUNC"

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  local correct_text
  case "$correct" in
    A) correct_text="A) $oa" ;; B) correct_text="B) $ob" ;;
    C) correct_text="C) $oc" ;; D) correct_text="D) $od" ;;
  esac

  while true; do
    blank
    echo "  ${W}${q}${RST}"
    blank
    echo "  ${YLW}A)${RST} $oa"
    echo "  ${YLW}B)${RST} $ob"
    echo "  ${YLW}C)${RST} $oc"
    echo "  ${YLW}D)${RST} $od"
    blank

    local ans got_ans=false
    while true; do
      printf "  ${CYN}Your answer [A/B/C/D]: ${RST}"
      read -rsn1 ans

      if [[ "$ans" == $'\x0e' ]]; then
        echo; printf "  ${YLW}[SKIPPED]${RST}\n"
        answer_reveal "$correct_text"
        correct_box; _award "$pts"
        PREV_Q_FUNC="ask_mc"; PREV_Q_ARGS=("$@")
        return 0
      elif [[ "$ans" == $'\x02' ]]; then
        if [[ -z "$saved_prev_func" ]]; then
          echo; printf "  ${YLW}[Going back to start...]${RST}\n"
          SCORE=0; MAX_SCORE=0; CORRECT=0; WRONG=0; RETRIED=0
          QUESTION_HISTORY=(); PREV_Q_ARGS=(); PREV_Q_FUNC=""
          BACK_TO_INTRO=true
          return 0
        fi
        echo
        unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
        local prev_snap; prev_snap="${QUESTION_HISTORY[-1]:-}"
        if [[ -n "$prev_snap" ]]; then
          local ps pm pc pw pr pp
          IFS='|' read -r ps pm pc pw pr pp <<< "$prev_snap"
          SCORE="$ps"; MAX_SCORE="$pm"; CORRECT="$pc"; WRONG="$pw"; RETRIED="$pr"
          unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
        else
          SCORE=0; MAX_SCORE=0; CORRECT=0; WRONG=0; RETRIED=0
        fi
        PREV_Q_ARGS=(); PREV_Q_FUNC=""
        clear
        "$saved_prev_func" "${saved_prev[@]}"
        score_before="$SCORE"; max_before="$MAX_SCORE"; correct_before="$CORRECT"
        wrong_before="$WRONG"; retried_before="$RETRIED"
        QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")
        saved_prev=("${PREV_Q_ARGS[@]}")
        saved_prev_func="$PREV_Q_FUNC"
        clear
        break
      fi

      ans="${ans^^}"
      case "$ans" in A|B|C|D) got_ans=true; break ;; esac
      echo; echo "  ${R}  Please type A, B, C or D${RST}"
    done

    [[ "$got_ans" == false ]] && continue

    echo
    printf "  ${DIM}You chose: %s${RST}\n" "$ans"

    if [[ "$ans" == "$correct" ]]; then
      correct_box; _award "$pts"
      PREV_Q_FUNC="ask_mc"; PREV_Q_ARGS=("$@")
      return
    fi

    local why_theirs
    case "$ans" in
      A) why_theirs="$wa" ;; B) why_theirs="$wb" ;;
      C) why_theirs="$wc" ;; D) why_theirs="$wd" ;;
    esac
    wrong_box "${why_theirs:-That option is incorrect.}"

    local ans2
    while true; do
      printf "  ${YLW}  [RETRY] One more try for half points [A/B/C/D]: ${RST}"
      read -rsn1 ans2
      ans2="${ans2^^}"
      case "$ans2" in A|B|C|D) break ;; esac
      echo; echo "  ${R}  Please type A, B, C or D${RST}"
    done

    echo
    printf "  ${DIM}You chose: %s${RST}\n" "$ans2"

    if [[ "$ans2" == "$correct" ]]; then
      correct_box "Correct on retry!"; _half "$pts"
      PREV_Q_FUNC="ask_mc"; PREV_Q_ARGS=("$@")
      return
    fi

    wrong_box "Still not right. Moving on."
    answer_reveal "$correct_text"
    _miss "$pts"

    if [[ -n "$teaching" ]]; then
      IFS='|' read -ra tlines <<< "$teaching"
      teach "${tlines[@]}"
    fi
    [[ -n "$memtip" ]] && tip "$memtip"
    PREV_Q_FUNC="ask_mc"; PREV_Q_ARGS=("$@")
    return
  done
}

# =============================================================================
#  ask_typed -- Free-text with ONE retry at half points
# =============================================================================
ask_typed() {
  [[ "$BACK_TO_INTRO" == true ]] && return 0
  local q="$1" expected="$2" pts="$3"
  local retry_hint="${4:-}" teaching="${5:-}" memtip="${6:-}" mode="${7:-exact}"

  local saved_prev=("${PREV_Q_ARGS[@]}")
  local saved_prev_func="$PREV_Q_FUNC"

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  _typed_match() {
    local a="${1,,}" e="${2,,}"
    if [[ "$mode" == "contains" ]]; then echo "$a" | grep -qiF "$e"
    else [[ "$a" == "$e" ]]; fi
  }

  while true; do
    blank; echo "  ${W}${q}${RST}"
    printf "  ${CYN}> ${RST}"

    read -rsn1 ans_first
    if [[ "$ans_first" == $'\x0e' ]]; then
      echo; printf "  ${YLW}[SKIPPED]${RST}\n"
      answer_reveal "$expected"
      correct_box; _award "$pts"
      PREV_Q_FUNC="ask_typed"; PREV_Q_ARGS=("$@")
      return 0
    elif [[ "$ans_first" == $'\x02' ]]; then
      if [[ -z "$saved_prev_func" ]]; then
        echo; printf "  ${YLW}[Going back to start...]${RST}\n"
        SCORE=0; MAX_SCORE=0; CORRECT=0; WRONG=0; RETRIED=0
        QUESTION_HISTORY=(); PREV_Q_ARGS=(); PREV_Q_FUNC=""
        BACK_TO_INTRO=true
        return 0
      fi
      echo
      unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
      local prev_snap; prev_snap="${QUESTION_HISTORY[-1]:-}"
      if [[ -n "$prev_snap" ]]; then
        local ps pm pc pw pr pp
        IFS='|' read -r ps pm pc pw pr pp <<< "$prev_snap"
        SCORE="$ps"; MAX_SCORE="$pm"; CORRECT="$pc"; WRONG="$pw"; RETRIED="$pr"
        unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
      else
        SCORE=0; MAX_SCORE=0; CORRECT=0; WRONG=0; RETRIED=0
      fi
      PREV_Q_ARGS=(); PREV_Q_FUNC=""
      clear
      "$saved_prev_func" "${saved_prev[@]}"
      score_before="$SCORE"; max_before="$MAX_SCORE"; correct_before="$CORRECT"
      wrong_before="$WRONG"; retried_before="$RETRIED"
      QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")
      saved_prev=("${PREV_Q_ARGS[@]}")
      saved_prev_func="$PREV_Q_FUNC"
      clear
      continue
    fi

    printf "%s" "$ans_first"
    local ans ans2 ans_rest
    read -r ans_rest
    ans="${ans_first}${ans_rest}"
    ans="$(echo "$ans" | xargs 2>/dev/null || echo "$ans")"

    if _typed_match "$ans" "$expected"; then
      correct_box; _award "$pts"
      PREV_Q_FUNC="ask_typed"; PREV_Q_ARGS=("$@")
      return
    fi

    echo "  ${R}  Not quite.${RST}  ${DIM}${retry_hint}${RST}"
    blank
    printf "  ${YLW}  [RETRY] One more try for half points > ${RST}"; read -r ans2
    ans2="$(echo "$ans2" | xargs 2>/dev/null || echo "$ans2")"

    if _typed_match "$ans2" "$expected"; then
      correct_box "Got it on retry!"; _half "$pts"
      PREV_Q_FUNC="ask_typed"; PREV_Q_ARGS=("$@")
      return
    fi

    wrong_box "Still not right. Moving on."
    answer_reveal "$expected"; _miss "$pts"
    if [[ -n "$teaching" ]]; then
      IFS='|' read -ra tlines <<< "$teaching"; teach "${tlines[@]}"
    fi
    [[ -n "$memtip" ]] && tip "$memtip"
    PREV_Q_FUNC="ask_typed"; PREV_Q_ARGS=("$@")
    return
  done
}

# =============================================================================
#  SETUP + DETECT ENV
# =============================================================================
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOGFILE" 2>/dev/null; }

setup_game() {
  mkdir -p "$GAMEDIR"
  log "Session started v${VERSION}"
}

detect_env() {
  local os
  case "$(uname -s 2>/dev/null)" in
    Darwin)  os="macOS" ;;
    Linux)   os="Linux" ;;
    MINGW*|MSYS*|CYGWIN*) os="Windows (Git Bash)" ;;
    *)       os="Unknown" ;;
  esac
  printf "  ${DIM}System: %s  |  Shell: %s %s${RST}\n" \
    "$os" "$(basename "${SHELL:-bash}")" "${BASH_VERSION%%(*}"
}

# =============================================================================
#  INTRO
# =============================================================================
intro() {
  clear
  printf "${BOLD}${CYN}"
  echo "                     +--------------+ "
  echo "                     |.------------.| "
  echo "                     ||            || "
  echo "                     ||            || "
  echo "                     ||            || "
  echo "                     ||            || "
  echo "                     |+------------+| "
  echo "                     +-..--------..-+ "
  echo "                     .--------------. "
  echo "                    / /============\\ \\ "
  echo "                   / /==============\\ \\ "
  echo "                  /____________________\\ "
  echo "                  \\____________________/ "
  printf "${RST}"
  printf "${BOLD}${CYN}"
  echo
   printf "           ███╗   ██╗███████╗████████╗███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗
           ████╗  ██║██╔════╝╚══██╔══╝████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
           ██╔██╗ ██║█████╗     ██║   ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝
           ██║╚██╗██║██╔══╝     ██║   ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗
           ██║ ╚████║███████╗   ██║   ██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║
           ╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝"


  printf "${RST}\n"
  printf "  ${W}Master TCP/IP + DNS + HTTP for a networking exam.${RST}\n"
  printf "  ${DIM}v%s${RST}\n" "$VERSION"
  blank
  detect_env
  blank
  bigcap; blank

  echo "  ${BOLD}${W}WHAT YOU WILL TRAIN${RST}"
  blank
  echo "  ${CYN}[1]${RST} OSI & TCP/IP Model    ${DIM}layers, encapsulation${RST}"
  echo "  ${CYN}[2]${RST} IP & MAC Addresses     ${DIM}private vs public, ifconfig${RST}"
  echo "  ${CYN}[3]${RST} Router, Switch & Ports ${DIM}DHCP, common ports${RST}"
  echo "  ${CYN}[4]${RST} TCP Packet Fields      ${DIM}SRC/DST/ACK/TTL, traceroute${RST}"
  echo "  ${CYN}[5]${RST} DNS Basics & Records   ${DIM}A, AAAA, CNAME, MX, NS, TXT, PTR${RST}"
  echo "  ${CYN}[6]${RST} TTL & Nameservers      ${DIM}authoritative vs recursive resolver${RST}"
  echo "  ${CYN}[7]${RST} dig Lab                ${DIM}root -> TLD -> authoritative  [+ live lab]${RST}"
  echo "  ${CYN}[8]${RST} HTTP                   ${DIM}methods, status codes, headers, sessions${RST}"
  blank
  bigcap; blank

  echo "  ${BOLD}${W}HOW WRONG ANSWERS WORK${RST}"
  blank
  echo "  ${RED}[X] Multiple choice${RST}  -- Explains why YOUR specific pick was wrong"
  echo "  ${YLW}[>] Typed answers${RST}    -- One retry for half points after a directional hint"
  echo "  ${BLU}[?] Teaching moment${RST}  -- Core rule shown on every miss"
  echo "  ${YLW}[!] Memory tip${RST}       -- Quick mnemonic to lock it in"
  blank

  printf "  ${BOLD}${W}GRADING${RST}  "
  printf "${GRN}90%%+ = 12${RST}  "
  printf "${GRN}75%% = 10${RST}  "
  printf "${YLW}55%% = 7${RST}  "
  printf "${Y}35%% = 4${RST}  "
  printf "${R}below = 02${RST}\n"
  blank
  sep; blank

  printf "  ${CYN}What should I call you? ${RST}"
  read -r PLAYER_NAME
  PLAYER_NAME="${PLAYER_NAME:-Student}"
  blank

  if [[ $START_ZONE -gt 1 ]]; then
    echo "  ${YLW}Jumping to zone ${START_ZONE} as requested.${RST}"
    blank
  else
    echo "  ${DIM}Tip: bash netmaster.sh --zone N  to jump straight to a zone.${RST}"
    blank
    echo "  ${W}Want to start from a specific zone? Enter 1-8, or ENTER for zone 1:${RST}"
    printf "  ${CYN}Start zone [1]: ${RST}"
    local zone_pick
    read -r zone_pick
    if [[ "$zone_pick" =~ ^[2-8]$ ]]; then
      START_ZONE="$zone_pick"
      echo "  ${YLW}Starting at zone ${START_ZONE}.${RST}"
    fi
  fi

  blank
  printf "  ${GRN}Let's go, ${BOLD}%s${RST}${GRN}.${RST}\n" "$PLAYER_NAME"
  log "Session started. Player: ${PLAYER_NAME}"
  pause
}
# ─────────────────────────────────────────────────────────────────────────────
# ZONES

# -- Compatibility aliases for zone content blocks ---------------------------
CYAN=$CYN; YELLOW=$YLW; NC=$RST; BLUE=$BLU; WHITE=$W; MAGENTA=$MAG
press_enter() { pause; }
score_bar()   { local pct=0; [[ $MAX_SCORE -gt 0 ]] && pct=$(( (SCORE*100)/MAX_SCORE ))
                printf "  ${DIM}Score: %d/%d  (%d%%)${RST}\n" "$SCORE" "$MAX_SCORE" "$pct"; }
zone_complete() { mkdir -p "$GAMEDIR"; touch "$GAMEDIR/zone${1}.done"; }
zone_done()     { [[ -f "$GAMEDIR/zone${1}.done" ]]; }

# =============================================================================
#  ZONES
# =============================================================================

zone1_osi_model() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 1 — The TCP/IP & OSI Model             │"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  The OSI model has 7 layers. The TCP/IP model simplifies"
  echo -e "  to 4 layers — combining the bottom two and the top three."
  echo ""
  echo -e "  ${BOLD}OSI (7 layers)         TCP/IP (4 layers)${NC}"
  echo -e "  ${YELLOW}┌──────────────────┐   ┌──────────────────────┐${NC}"
  echo -e "  ${YELLOW}│ 7. Application   │   │                      │${NC}"
  echo -e "  ${YELLOW}│ 6. Presentation  │   │  4. Application      │${NC}"
  echo -e "  ${YELLOW}│ 5. Session       │   │     (HTTP, DNS, SSH) │${NC}"
  echo -e "  ${YELLOW}├──────────────────┤   ├──────────────────────┤${NC}"
  echo -e "  ${CYAN}│ 4. Transport     │   │  3. Transport        │${NC}"
  echo -e "  ${CYAN}│   (TCP, UDP)     │   │     (TCP, UDP, ports)│${NC}"
  echo -e "  ${CYAN}├──────────────────┤   ├──────────────────────┤${NC}"
  echo -e "  ${G}│ 3. Network       │   │  2. Internet         │${NC}"
  echo -e "  ${G}│   (IP addresses) │   │     (IP addresses)   │${NC}"
  echo -e "  ${G}├──────────────────┤   ├──────────────────────┤${NC}"
  echo -e "  ${BLUE}│ 2. Data Link     │   │                      │${NC}"
  echo -e "  ${BLUE}│   (MAC, frames)  │   │  1. Link/Network IF  │${NC}"
  echo -e "  ${BLUE}│ 1. Physical      │   │     (MAC, cables)    │${NC}"
  echo -e "  ${BLUE}└──────────────────┘   └──────────────────────┘${NC}"
  echo ""
  press_enter

  ask_mc "How many layers does the TCP/IP model have?" \
    "4" "5" "7" "3" \
    "A" 10 \
    "" \
    "5 is not a real model. TCP/IP has 4 layers." \
    "7 is OSI, not TCP/IP. TCP/IP merges OSI's 7 into 4." \
    "3 is too few. TCP/IP collapses OSI down to 4." \
    "TCP/IP layers (top to bottom): 4.Application 3.Transport 2.Internet 1.Link|OSI has 7: App+Presentation+Session → TCP/IP Application|Transport → Transport|Network → Internet|Data Link+Physical → Link" \
    "OSI=7. TCP/IP=4. TCP/IP squashes 7 into 4."

  ask_mc "Which TCP/IP layer handles IP addresses and routing?" \
    "Transport layer" \
    "Internet layer (Layer 2 in TCP/IP)" \
    "Link layer" \
    "Application layer" \
    "B" 10 \
    "Transport handles TCP/UDP and ports — not IP routing." \
    "" \
    "Link handles MAC addresses and frames, not IP." \
    "Application handles HTTP, DNS, SSH — the top layer, not routing." \
    "IP addresses live on the Internet layer (L2 TCP/IP = L3 OSI).|Routing decisions are made here based on destination IP." \
    "IP lives on Internet layer. Both start with I."

  ask_mc "Which TCP/IP layer does TCP and UDP belong to?" \
    "Internet layer" \
    "Transport layer" \
    "Application layer" \
    "Link layer" \
    "B" 10 \
    "Internet layer = IP routing, not TCP/UDP." \
    "" \
    "Application = HTTP, DNS, SSH — the top layer." \
    "Link = MAC addresses and physical frames." \
    "Transport layer handles TCP (reliable) and UDP (fast).|Both use port numbers to identify which app gets the data." \
    "Transport = TCP = both start with T."

  ask_mc "WireShark shows: Frame, Ethernet II, IPv4, TCP — which layer is 'Ethernet II'?" \
    "Internet layer (IP)" \
    "Transport layer (TCP)" \
    "Link/Network Interface layer (MAC, frames)" \
    "Application layer" \
    "C" 10 \
    "IP is Internet layer — shown separately as IPv4 in WireShark." \
    "TCP is Transport layer — shown as its own entry in WireShark." \
    "" \
    "Application is HTTP/TLS — the top layer, above TCP." \
    "WireShark layers bottom-up: Frame → Ethernet II (Link) → IPv4 (Internet) → TCP (Transport) → HTTP (Application)" \
    "Ethernet = physical hardware = Link layer."

  ask_mc "The OSI model has 7 layers. What is the key difference between OSI and TCP/IP?" \
    "TCP/IP only covers the top 4 layers" \
    "TCP/IP combines the bottom 2 OSI layers AND the top 3 OSI layers (= 4 total)" \
    "TCP/IP is the same as OSI but with different names" \
    "OSI has more protocols than TCP/IP" \
    "B" 10 \
    "TCP/IP covers ALL 7 OSI layers — just combined into 4." \
    "" \
    "They are different models — TCP/IP collapses OSI layers." \
    "Protocol count is not the defining difference between them." \
    "OSI (7) vs TCP/IP (4):|OSI 1+2 → TCP/IP Link  |  OSI 3 → TCP/IP Internet|OSI 4 → TCP/IP Transport  |  OSI 5+6+7 → TCP/IP Application" \
    "TCP/IP = 4 layers. (1+2) + 3 + 4 + (5+6+7)."

  blank; echo "  ${GRN}${BOLD}Zone 1 complete!${RST}"; score_bar; zone_complete 1; pause
}

# ─────────────────────────────────────────────────────────────────────────────

zone2_ip_mac() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 2 — IP Addresses & MAC Addresses       │"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${BOLD}IP Address${NC} = logical address. Assigned by network."
  echo -e "  Lives on the ${YELLOW}Internet layer${NC} (Layer 3 OSI / Layer 2 TCP/IP)."
  echo ""
  echo -e "  ${BOLD}MAC Address${NC} = physical hardware address. Burned into your NIC."
  echo -e "  Lives on the ${BLUE}Data Link layer${NC} (Layer 2 OSI / Layer 1 TCP/IP)."
  echo ""
  echo -e "  ${BOLD}Local (private) addresses:${NC}"
  echo -e "    10.x.x.x        (e.g. on a campus network)"
  echo -e "    192.168.x.x     (e.g. at home)"
  echo -e "    172.16.x.x      (e.g. mobile hotspot)"
  echo ""
  echo -e "  ${BOLD}Public address:${NC} unique globally, routable on the internet."
  echo -e "  Your router does NAT: many private IPs share one public IP."
  echo ""
  echo -e "  ${DIM}  Find your local IP:  ifconfig (Mac/Linux)  /  ipconfig (Windows)"
  echo -e "  Find your public IP: visit ipinfo.io or similar${NC}"
  echo ""
  press_enter

  ask_mc "What is the key difference between an IP address and a MAC address?" \
    "IP is 48 bits; MAC is 32 bits" \
    "IP is physical/hardware-burned-in; MAC is logical/network-assigned" \
    "IP is logical/network-assigned; MAC is physical/hardware-burned-in" \
    "They are the same thing with different names" \
    "C" 10 \
    "Sizes are swapped: IPv4 is 32 bits, MAC is 48 bits." \
    "Completely reversed. IP is logical, MAC is physical." \
    "" \
    "They serve entirely different purposes at different layers." \
    "IP = logical address. Assigned by network/DHCP. Changes when you move.|MAC = physical address. Burned into NIC at factory. Permanent.|IP lives on Internet layer. MAC lives on Link layer." \
    "MAC = burned-in hardware. IP = assigned by network."

  ask_mc "You see 192.168.1.45 in your ifconfig. What type of address is this?" \
    "Public IP address" \
    "MAC address" \
    "IPv6 address" \
    "Private (local) IP address — not routable on the public internet" \
    "D" 10 \
    "Public IPs are globally unique and routable. 192.168.x.x is not." \
    "MAC addresses are 6 hex groups like 08:bf:b8:0b:fd:a8." \
    "IPv6 looks like 2001:0db8:85a3::8a2e:0370:7334." \
    "" \
    "Private (non-routable) IP ranges:|10.x.x.x — campus  |  192.168.x.x — home/office|172.16.x.x — mobile hotspot|NAT: many private IPs share one public IP." \
    "192.168 = home. Always private."

  ask_mc "Why can you NOT see example.com's MAC address in WireShark?" \
    "example.com does not have a MAC address" \
    "WireShark does not support MAC address display" \
    "MAC addresses are encrypted by HTTPS" \
    "MAC addresses only work locally between two directly connected devices" \
    "D" 10 \
    "example.com's server has a MAC — but it is on a different network segment." \
    "WireShark DOES show MAC addresses — for local traffic." \
    "MAC has nothing to do with encryption." \
    "" \
    "MAC addresses are layer 2 — only used on the LOCAL network segment.|Each router hop replaces the source MAC with its own." \
    "MAC = local only. Routers replace it at every hop."

  ask_mc "Which command finds your local IP address on a Mac?" \
    "ipconfig" \
    "ifconfig" \
    "netstat" \
    "traceroute" \
    "B" 10 \
    "ipconfig is Windows. On Mac/Linux it is ifconfig." \
    "" \
    "netstat shows network connections and statistics, not your IP." \
    "traceroute shows the route to a destination, not your local IP." \
    "ifconfig (Mac/Linux) shows your local IP, MAC, and interface stats.|ipconfig (Windows) is the equivalent.|ip addr (modern Linux) is the newer alternative." \
    "ifconfig = interface config. Mac/Linux. ipconfig = Windows."

  blank; echo "  ${GRN}${BOLD}Zone 2 complete!${RST}"; score_bar; zone_complete 2; pause
}

# ─────────────────────────────────────────────────────────────────────────────

zone3_router_switch_ports() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 3 — Router, Switch & Ports             │"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${BOLD}Switch${NC} = operates at Layer 2 (MAC addresses)."
  echo -e "  Forwards frames to the correct device on the SAME network."
  echo -e "  Like a post room inside one building — knows every desk."
  echo ""
  echo -e "  ${BOLD}Router${NC} = operates at Layer 3 (IP addresses)."
  echo -e "  Routes packets BETWEEN different networks."
  echo -e "  Like a post office that knows how to reach other cities."
  echo ""
  echo -e "  ${BOLD}DHCP${NC} = Dynamic Host Configuration Protocol."
  echo -e "  Automatically assigns IP addresses to devices on a network."
  echo -e "  Your router runs a DHCP server — that's how your phone gets 192.168.x.x."
  echo ""
  echo -e "  ${BOLD}Ports:${NC} Transport layer numbers that identify which app gets the data."
  echo ""
  echo -e "  ${YELLOW}  Port  │ Protocol${NC}"
  echo -e "  ${YELLOW}  ──────┼─────────────────────────────────────${NC}"
  echo -e "    22   │ SSH"
  echo -e "    53   │ DNS (UDP)"
  echo -e "    80   │ HTTP"
  echo -e "    443  │ HTTPS (TLS)"
  echo -e "    3306 │ MySQL"
  echo -e "    5432 │ PostgreSQL"
  echo -e "    8080 │ Common dev/app port"
  echo ""
  press_enter

  ask_mc "What is the main difference between a router and a switch?" \
    "They do the same thing but at different speeds" \
    "Router routes by MAC (same network); Switch routes by IP (between networks)" \
    "Switch routes by MAC (same network); Router routes by IP (between networks)" \
    "Routers only in datacenters, switches for home use" \
    "C" 10 \
    "They do fundamentally different things at different OSI layers." \
    "Completely swapped. Switch=MAC(L2), Router=IP(L3)." \
    "" \
    "Both are used at every scale — home routers and switches exist." \
    "Switch = Layer 2 (MAC). Forwards frames within same network segment.|Router = Layer 3 (IP). Routes packets between different networks." \
    "Router = Routes between networks (IP). Switch = Switches within network (MAC)."

  ask_mc "What does DHCP do?" \
    "Encrypts network traffic" \
    "Translates domain names to IP addresses" \
    "Automatically assigns IP addresses to devices on a network" \
    "Manages firewall rules" \
    "C" 10 \
    "Encryption is TLS/HTTPS. DHCP assigns IPs." \
    "Translating domain names is DNS. DHCP assigns IPs." \
    "" \
    "Firewall rules are managed by firewall software. DHCP assigns IPs." \
    "DHCP = Dynamic Host Configuration Protocol.|Your device broadcasts I need an IP! when joining a network.|DHCP server replies with: IP, subnet mask, gateway, DNS server." \
    "DHCP = Dynamic = auto-assigns IPs. Like a hotel receptionist giving room keys."

  ask_mc "What standard port does HTTPS use?" \
    "80" \
    "8080" \
    "443" \
    "22" \
    "C" 10 \
    "80 is HTTP (unencrypted). 443 is HTTPS." \
    "8080 is a common dev port — not standard HTTPS." \
    "" \
    "22 is SSH." \
    "Key ports: 22=SSH  53=DNS  80=HTTP  443=HTTPS|3306=MySQL  5432=PostgreSQL  8080=dev/app" \
    "HTTPS=443. HTTP=80. SSH=22. DNS=53."

  ask_mc "What standard port does SSH use?" \
    "22" \
    "21" \
    "53" \
    "443" \
    "A" 10 \
    "" \
    "21 is FTP (file transfer). SSH is 22." \
    "53 is DNS. SSH is 22." \
    "443 is HTTPS. SSH is 22." \
    "SSH (port 22) = Secure Shell. Encrypted remote terminal access.|FTP=21  DNS=53  HTTP=80  HTTPS=443" \
    "SSH = 22. Two letters, two digits."

  ask_mc "What is a port, and why do we have ports?" \
    "A physical socket on the network card" \
    "A number that identifies which network the packet belongs to" \
    "A firewall rule for blocking traffic" \
    "A number that tells the OS which application should receive the incoming data" \
    "D" 10 \
    "Physical sockets are just connectors. Ports are logical numbers 0-65535." \
    "Networks are identified by IP addresses, not port numbers." \
    "Firewall rules CAN use ports, but a port itself is not a firewall rule." \
    "" \
    "Ports are Transport layer numbers (0-65535).|One IP address, many apps: port tells OS which app gets the data.|80 = web server. 443 = HTTPS. 22 = SSH." \
    "Port = door number. IP = building address."

  blank; echo "  ${GRN}${BOLD}Zone 3 complete!${RST}"; score_bar; zone_complete 3; pause
}

# ─────────────────────────────────────────────────────────────────────────────

zone4_tcp_packet() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 4 — TCP Packet Fields (SRC/DST/ACK/TTL)│"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  WireShark shows this for a TCP/IP packet:"
  echo ""
  echo -e "  ${DIM}  Frame 54243: 66 bytes"
  echo -e "  ${BLUE}  Ethernet II, Src: 08:bf:b8:0b:fd:a8, Dst: 60:3e:5f:57:59:58${NC}"
  echo -e "  ${G}  Internet Protocol v4, Src: 185.67.45.84, Dst: 192.168.50.38, TTL: 64${NC}"
  echo -e "  ${CYAN}  Transmission Control Protocol, Src Port: 443, Dst Port: 50060, Seq: 4331, Ack: 1408${NC}"
  echo ""
  echo -e "  ${BOLD}IP layer fields:${NC}"
  echo -e "    ${G}Src${NC} = source IP — who sent this packet"
  echo -e "    ${G}Dst${NC} = destination IP — where it is going"
  echo -e "    ${G}TTL (Time To Live)${NC} = max hops before packet is dropped"
  echo -e "    ${DIM}  Better name: 'hopcount'. Each router decrements by 1. Hits 0 = discarded.${NC}"
  echo -e "    ${DIM}  Use traceroute to visualise the hops!${NC}"
  echo ""
  echo -e "  ${BOLD}TCP layer fields:${NC}"
  echo -e "    ${CYAN}Src Port${NC} = which port on the sender"
  echo -e "    ${CYAN}Dst Port${NC} = which port on the receiver (e.g. 443 = HTTPS)"
  echo -e "    ${CYAN}Ack${NC}     = acknowledgement — TCP confirms each segment received"
  echo -e "    ${DIM}  Ack is what makes TCP reliable. UDP does not have Ack.${NC}"
  echo ""
  echo -e "  ${BOLD}⚠  TTL in DNS means something different!${NC}"
  echo -e "  ${DIM}  In DNS: TTL = seconds before a cached record expires${NC}"
  echo -e "  ${DIM}  In TCP: TTL = max hop count (should be called 'hopcount')${NC}"
  echo ""
  press_enter

  ask_mc "In a TCP packet: what does 'Src Port' tell you?" \
    "Which port the data is going TO on the destination" \
    "Which port on the SENDING device this data comes from" \
    "The IP address of the sender" \
    "The number of bytes in the packet" \
    "B" 10 \
    "That is Dst Port (destination). Src = source." \
    "" \
    "IP addresses are in the IP layer header, not described as ports." \
    "Byte count is in the frame/IP length fields, not Src Port." \
    "TCP header: Src Port = which port on the SENDER (e.g. 50060 ephemeral)|Dst Port = which port on the RECEIVER (e.g. 443 = HTTPS)" \
    "Src = Source = Sender. Dst = Destination = Receiver."

  ask_mc "What does ACK do in TCP — and which protocol does NOT have it?" \
    "ACK encrypts data; ICMP does not have ACK" \
    "ACK sets the TTL; IP does not have ACK" \
    "ACK confirms receipt; UDP does not have ACK (unreliable)" \
    "ACK fragments large packets; DNS does not have ACK" \
    "C" 10 \
    "ACK is about reliability, not encryption. HTTPS/TLS handles encryption." \
    "TTL is an IP field, not related to ACK." \
    "" \
    "Fragmentation is handled by the IP layer, not ACK." \
    "TCP ACK = acknowledgement. Confirms each segment was received.|UDP = no ACK = fire and forget = unreliable but fast.|Use TCP for: HTTP, SSH (need reliability). UDP for: DNS, video calls (need speed)." \
    "TCP = reliable = ACK. UDP = fast = no ACK."

  ask_mc "What does TTL mean in a TCP/IP packet — and what would be a better name?" \
    "Seconds until the packet expires in a cache" \
    "Max hops before packet is dropped — better name: hopcount" \
    "Size limit of the packet in bytes" \
    "Time to wait for an ACK before retrying" \
    "B" 10 \
    "Seconds-until-expire is what TTL means in DNS. In TCP/IP it is hop count." \
    "" \
    "Packet size is the MTU (Maximum Transmission Unit), not TTL." \
    "ACK retry timing is TCP retransmission timeout, not TTL." \
    "TCP/IP TTL = max router hops before packet discarded.|Each router decrements TTL by 1. Hits 0 = packet dropped, ICMP error sent.|traceroute exploits TTL: sends packets with TTL=1,2,3... to map the route." \
    "TTL in IP = hopcount (misleading name). TTL in DNS = cache seconds."

  ask_mc "What is traceroute used for?" \
    "Checking if a server is online (like ping)" \
    "Showing all open ports on a remote server" \
    "Visualising each router hop a packet takes to reach its destination" \
    "Measuring the speed of a network connection" \
    "C" 10 \
    "ping checks if a host is online. traceroute maps the path." \
    "Port scanning is nmap. traceroute maps router hops." \
    "" \
    "Speed testing is iperf or speedtest. traceroute maps hops." \
    "traceroute sends packets with increasing TTL (1,2,3...).|Each router that drops a TTL-expired packet sends back an ICMP reply.|Useful for diagnosing where in the network a connection fails." \
    "traceroute = trace the route. Shows every router hop."

  blank; echo "  ${GRN}${BOLD}Zone 4 complete!${RST}"; score_bar; zone_complete 4; pause
}

# ─────────────────────────────────────────────────────────────────────────────

zone5_dns_basics() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 5 — DNS Basics & Record Types          │"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${BOLD}DNS = Domain Name System${NC}"
  echo -e "  Translates human-readable domain names → IP addresses."
  echo -e "  It is decentralised and distributed — no single big database."
  echo ""
  echo -e "  ${BOLD}DNS Record Types:${NC}"
  echo ""
  echo -e "  ${YELLOW}  Type  │ Meaning                      │ Example${NC}"
  echo -e "  ${YELLOW}  ──────┼──────────────────────────────┼─────────────────────────────────${NC}"
  echo -e "    A     │ Domain → IPv4 address        │ example.com → 93.184.216.34"
  echo -e "    AAAA  │ Domain → IPv6 address        │ example.com → 2606:2800:220:1:248:1893:25c8:1946"
  echo -e "    CNAME │ Alias (domain → domain)      │ www.iana.org → iana.org"
  echo -e "    MX    │ Mail server for domain       │ gmail.com → alt1.aspmx.l.google.com"
  echo -e "    NS    │ Nameserver for domain        │ example.com → a.iana-servers.net"
  echo -e "    TXT   │ Free text / verification     │ SPF, domain ownership"
  echo -e "    PTR   │ Reverse: IP → domain         │ 'reverse DNS'"
  echo ""
  echo -e "  ${BOLD}Tools for DNS lookups:${NC}"
  echo -e "    nslookup   (Windows/Mac — basic)"
  echo -e "    host       (Mac/Linux — basic)"
  echo -e "    dig        (all — advanced, must install)"
  echo -e "    dnschecker.org  (browser — visual, all record types)"
  echo ""
  echo -e "  ${DIM}  Standard DNS port: UDP 53${NC}"
  echo ""
  press_enter

  ask_mc "What does a DNS A record do?" \
    "Maps a domain to another domain (alias)" \
    "Maps a domain name to an IPv4 address" \
    "Specifies the mail server for a domain" \
    "Specifies the nameserver for a domain" \
    "B" 10 \
    "Domain-to-domain alias is CNAME." \
    "" \
    "Mail server is MX record." \
    "Nameserver is NS record." \
    "DNS record types: A=domain->IPv4  |  AAAA=domain->IPv6|CNAME=alias  |  MX=mail server  |  NS=nameserver|TXT=free text  |  PTR=reverse (IP->domain)" \
    "A = Address. A record points to an IP address."

  ask_mc "What is the difference between an A record and a CNAME record?" \
    "A = domain to IPv6; CNAME = domain to IPv4" \
    "A = domain to domain (alias); CNAME = domain to IP" \
    "A = domain to IP; CNAME = domain to domain (alias)" \
    "They are identical, just different names" \
    "C" 10 \
    "A -> IPv4. AAAA -> IPv6. CNAME is an alias." \
    "Swapped. A=IP, CNAME=alias." \
    "" \
    "A and CNAME have completely different purposes." \
    "A record: example.com -> 93.184.216.34 (direct IP)|CNAME: www.example.com -> example.com (alias, resolved further)|CNAME adds one extra DNS lookup." \
    "A = Address (IP). CNAME = Canonical Name (alias to another domain)."

  ask_mc "Which record type tells you which server handles email for a domain?" \
    "A record" \
    "TXT record" \
    "MX (Mail Exchange)" \
    "NS record" \
    "C" 10 \
    "A record -> IP. Not email." \
    "TXT can contain SPF (email policy) but MX specifies the actual mail server." \
    "" \
    "NS = nameserver. Not email." \
    "MX record points to the mail server hostname.|Example: gmail.com MX -> alt1.aspmx.l.google.com|Priority number: lower = preferred." \
    "MX = Mail eXchange. M for Mail."

  ask_mc "Which tool can query ALL DNS record types at once, without specifying them?" \
    "nslookup" \
    "dig" \
    "host" \
    "dnschecker.org (DNS lookup tab)" \
    "D" 10 \
    "nslookup queries specific record types but not all at once easily." \
    "dig can query types individually. dig ANY is often blocked by servers." \
    "host is a basic tool with similar limitations." \
    "" \
    "dnschecker.org DNS lookup tab shows ALL record types in one view.|dig -- most powerful CLI tool, best for exam demos.|nslookup / host -- good for quick single-type lookups." \
    "Browser: dnschecker.org shows all. CLI: dig for specific queries."

  ask_mc "What port does DNS use by default?" \
    "TCP port 80" \
    "UDP port 443" \
    "TCP port 22" \
    "UDP port 53" \
    "D" 10 \
    "80 is HTTP. DNS uses UDP 53." \
    "443 is HTTPS. DNS uses UDP 53." \
    "22 is SSH. DNS uses UDP 53." \
    "" \
    "DNS uses UDP port 53 for most lookups (fast, small queries).|DNS uses TCP port 53 for large responses or zone transfers." \
    "DNS = 53. UDP for queries. TCP for zone transfers."

  blank; echo "  ${GRN}${BOLD}Zone 5 complete!${RST}"; score_bar; zone_complete 5; pause
}

# ─────────────────────────────────────────────────────────────────────────────

zone6_ttl_nameservers() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 6 — TTL in DNS & Nameserver Types      │"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${BOLD}TTL in DNS = Time To Live (seconds before cache expires)${NC}"
  echo -e "  ${DIM}  This is different from TTL in TCP! In TCP, TTL = hopcount.${NC}"
  echo ""
  echo -e "    3600  = 1 hour"
  echo -e "    86400 = 24 hours"
  echo -e "    172800= 48 hours"
  echo ""
  echo -e "  ${G}High TTL${NC} → fast (cached), but slow to update if you change the record"
  echo -e "  ${R}Low TTL${NC}  → updates propagate fast, but more DNS lookups happen"
  echo ""
  echo -e "  ${BOLD}Tip:${NC} Lower TTL BEFORE migrating a domain. Raise it back after."
  echo ""
  echo -e "  ─────────────────────────────────────────────────────────────────"
  echo ""
  echo -e "  ${BOLD}Two types of DNS nameservers:${NC}"
  echo ""
  echo -e "  ${G}Authoritative Nameserver${NC}"
  echo -e "    → Has the ACTUAL DNS records (source of truth)"
  echo -e "    → Owned by the domain owner / DNS provider"
  echo -e "    → Does NOT cache — gives direct, final answers"
  echo -e "    → Example: a.iana-servers.net for example.com"
  echo ""
  echo -e "  ${CYAN}Caching / Recursive Resolver${NC}"
  echo -e "    → Stores copies for TTL duration"
  echo -e "    → Asks authoritative servers if cache is expired"
  echo -e "    → Your ISP runs one. Google runs 8.8.8.8"
  echo -e "    → nslookup result says 'Non-authoritative answer' → resolver answered"
  echo ""
  press_enter

  ask_mc "You want to migrate example.com to a new server with minimal downtime. What do you do with TTL first?" \
    "Raise the TTL to 86400 to avoid disruption during migration" \
    "Delete the A record first, then set a new one" \
    "Lower the TTL to a few minutes BEFORE the migration so changes propagate fast" \
    "TTL does not affect migration speed" \
    "C" 10 \
    "Raising TTL = slower propagation. Wrong direction." \
    "Deleting first causes downtime. Lower TTL first, then swap." \
    "" \
    "TTL directly controls how long old IPs are cached. It absolutely matters." \
    "DNS migration best practice:|1. Lower TTL to 300 (5 min) well before migration|2. Make the IP change|3. Wait for old TTL to expire|4. Raise TTL back to 3600+ after propagation" \
    "Lower TTL BEFORE migration. Higher TTL = longer cache = slower updates."

  ask_mc "nslookup example.com returns 'Non-authoritative answer'. What does this mean?" \
    "The answer is wrong or unreliable" \
    "The domain has no authoritative server configured" \
    "A caching resolver (not the domain owner) answered — its copy may be cached" \
    "The query failed and fell back to a local file" \
    "C" 10 \
    "Non-authoritative does NOT mean wrong. Just means it came from a cache." \
    "All domains have authoritative servers. Non-authoritative means resolver answered." \
    "" \
    "Local fallback (/etc/hosts) does not produce this message." \
    "Non-authoritative = the answer came from a recursive resolver's cache.|Authoritative = came directly from the domain's own nameserver.|Use dig @a.iana-servers.net example.com for a truly authoritative answer." \
    "Non-authoritative = answered from cache by a resolver, not the domain owner."

  ask_mc "What is the key difference between an authoritative nameserver and a recursive resolver?" \
    "Authoritative only handles .dk; resolver handles all TLDs" \
    "Resolver holds the real records; authoritative caches and asks on your behalf" \
    "Authoritative holds the real records; resolver caches and asks on your behalf" \
    "They are the same thing — different names for the same role" \
    "C" 10 \
    "Authoritative servers handle whatever domain they are configured for." \
    "Completely reversed roles." \
    "" \
    "Completely different roles and architectures." \
    "Authoritative NS = source of truth for a domain.|  Holds actual DNS records. Does NOT cache.|Recursive resolver = asks on your behalf.|  Queries root -> TLD -> authoritative, caches results for TTL duration.|Google runs 8.8.8.8. Cloudflare runs 1.1.1.1." \
    "Authoritative = owns the records. Resolver = fetches and caches."

  ask_mc "Which of these correctly explains TTL in DNS vs TTL in TCP?" \
    "DNS TTL = max hops; TCP TTL = seconds to cache" \
    "Both mean seconds to cache, just in different layers" \
    "TTL only exists in DNS; TCP does not have a TTL field" \
    "DNS TTL = seconds to cache; TCP TTL = max hops (hopcount)" \
    "D" 10 \
    "Swapped. DNS TTL = cache seconds. TCP TTL = hop count." \
    "TCP TTL is hop count, not cache time." \
    "TCP/IP packets have a TTL field — hop count before they are dropped." \
    "" \
    "TTL is an overloaded term:|DNS TTL = seconds before cached record expires (e.g. 86400 = 24h)|TCP/IP TTL = max router hops before packet discarded (e.g. 64)" \
    "DNS TTL = time (cache). IP TTL = hops. Same word, different layers."

  blank; echo "  ${GRN}${BOLD}Zone 6 complete!${RST}"; score_bar; zone_complete 6; pause
}

# ─────────────────────────────────────────────────────────────────────────────

zone7_dig_lab() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 7 — Interactive dig Lab                │"
  echo -e "  │  Walk the DNS tree: root → TLD → authoritative│"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${BOLD}This is the exam demo they will ask you to do.${NC}"
  echo -e "  You are going to simulate being a recursive resolver."
  echo -e "  Start from a root nameserver and work your way down to the"
  echo -e "  authoritative answer for ${YELLOW}example.com${NC}."
  echo ""
  echo -e "  ${DIM}  If dig is not installed:"
  echo -e "    macOS:  brew install bind"
  echo -e "    Ubuntu: sudo apt install dnsutils"
  echo -e "    Windows: install from ISC or use WSL${NC}"
  echo ""

  # Check dig is available
  if ! command -v dig &>/dev/null; then
    echo -e "  ${R}⚠  'dig' is not installed on this system.${NC}"
    echo -e "  Install it and come back. Showing the theory walk-through instead."
    echo ""
    press_enter
    zone7_theory_only
    return
  fi

  echo -e "  ${G}  ✓ dig is available.${NC}"
  echo ""
  press_enter

  # ── STEP 1: Root nameserver ──────────────────────────────────────────────
  clear
  echo -e "${CYAN}${BOLD}  ZONE 7 — STEP 1: Ask a root nameserver${NC}"
  echo ""
  echo -e "  Root nameservers know which nameserver handles each TLD (.dk, .com etc.)"
  echo -e "  There are 13 root nameserver clusters: a.root-servers.net .. m.root-servers.net"
  echo ""
  echo -e "${BOLD}${YELLOW}  ▶  YOUR TASK:${NC}"
  echo -e "  Open a terminal and run:"
  echo ""
  echo -e "  ${CYAN}    dig @a.root-servers.net A example.com${NC}"
  echo ""
  echo -e "  Look at the ${BOLD}AUTHORITY SECTION${NC} of the output."
  echo -e "  It will list NS records — the TLD nameservers for .com"
  echo ""
  printf "  ${YELLOW}When done, press Enter...${NC}"; read -r
  echo ""

  ask_mc "After running 'dig @a.root-servers.net A example.com', what section gives the next step?" \
    "ANSWER SECTION — the final IP address" \
    "QUESTION SECTION — it confirms what you asked" \
    "AUTHORITY SECTION — NS records pointing to .com TLD nameservers" \
    "ADDITIONAL SECTION — IPv6 addresses of the root server" \
    "C" 10 \
    "ANSWER SECTION is empty at this step — root does not know the IP." \
    "QUESTION SECTION just echoes your query back at you." \
    "" \
    "ADDITIONAL has IPs of nameservers, but AUTHORITY has the next step." \
    "dig output sections:|QUESTION = what you asked|ANSWER = direct answer (empty if server does not know)|AUTHORITY = delegation to next nameserver|ADDITIONAL = extra info (IPs of AUTHORITY nameservers)" \
    "No ANSWER at root level -> look at AUTHORITY for next step."

  ask_mc "Root server answered with NS records, NOT an A record. Why?" \
    "Root servers are broken and cannot return A records" \
    "example.com does not have an A record" \
    "Root servers only know which nameserver handles each TLD — not the final IP" \
    "The root server needs you to ask again with a different record type" \
    "C" 10 \
    "Root servers work perfectly — they just delegate, not resolve." \
    "example.com definitely has an A record — just not at the root." \
    "" \
    "Record type is correct (A) — root simply does not hold leaf-level records." \
    "DNS hierarchy: root knows TLDs, TLDs know domain NS, domain NS knows IPs.|Root servers ONLY store NS records for TLDs (.com, .dk, .org etc.)." \
    "Root = knows TLDs. TLD = knows domain NS. Domain NS = knows IPs."

  # ── STEP 2: TLD nameserver ───────────────────────────────────────────────
  clear
  echo -e "${CYAN}${BOLD}  ZONE 7 — STEP 2: Ask the .com TLD nameserver${NC}"
  echo ""
  echo -e "  From Step 1, you saw NS records like:"
  echo -e "    ${DIM}com.   172800 IN NS a.gtld-servers.net.${NC}"
  echo ""
  echo -e "${BOLD}${YELLOW}  ▶  YOUR TASK:${NC}"
  echo -e "  Now ask the TLD nameserver for example.com:"
  echo ""
  echo -e "  ${CYAN}    dig @a.gtld-servers.net A example.com${NC}"
  echo ""
  echo -e "  Again, look at the ${BOLD}AUTHORITY SECTION${NC}."
  echo -e "  This time you will see NS records for example.com\'s own nameserver."
  echo ""
  printf "  ${YELLOW}When done, press Enter...${NC}"; read -r
  echo ""

  ask_mc "a.gtld-servers.net is the .com TLD nameserver. What did it return?" \
    "The final A record with example.com's IP address" \
    "An error — a.gtld-servers.net does not know about example.com" \
    "NS records pointing to example.com's authoritative nameserver (a.iana-servers.net)" \
    "A CNAME redirecting to www.example.com" \
    "C" 10 \
    "TLD servers do not have the final IP either — they delegate further." \
    "TLD servers know which NS handles each domain under .com." \
    "" \
    "CNAME is not part of the delegation chain." \
    "The .com TLD returns NS records (AUTHORITY section) pointing to the domain's own authoritative server." \
    ".com TLD delegates to domain's own NS. Still not the final IP."

  ask_mc "The NS records point to a.iana-servers.net. Why is example.com's DNS at IANA?" \
    "iana-servers.net is a root nameserver" \
    "iana-servers.net is the .com TLD registry" \
    "example.com is managed by IANA for documentation examples" \
    "a.iana-servers.net is Google's public DNS" \
    "C" 10 \
    "Root nameservers are a.root-servers.net through m.root-servers.net." \
    "The .com TLD registry is Verisign/a.gtld-servers.net." \
    "" \
    "Google's resolver is 8.8.8.8. IANA is a separate organisation." \
    "example.com and example.org are reserved by IANA for documentation and testing." \
    "example.com = IANA's test domain. Reserved for docs and demos."
  # ── STEP 3: Authoritative answer ───────────────────────────────────────────
  clear
  echo -e "${CYAN}${BOLD}  ZONE 7 — STEP 3: Get the authoritative answer${NC}"
  echo ""
  echo -e "  From Step 2 you saw: ${DIM}example.com. 86400 IN NS a.iana-servers.net.${NC}"
  echo ""
  echo -e "${BOLD}${YELLOW}  ▶  YOUR TASK:${NC}"
  echo -e "  Ask the authoritative nameserver directly:"
  echo ""
  echo -e "  ${CYAN}    dig @a.iana-servers.net A example.com${NC}"
  echo ""
  echo -e "  This time the ${BOLD}ANSWER SECTION${NC} should contain the actual IP address."
  echo ""
  printf "  ${YELLOW}When done, press Enter...${NC}"; read -r
  echo ""

  ask_mc "What does the ANSWER SECTION contain when you ask the authoritative server a.iana-servers.net?" \
    "More NS records — it redirects to another server" \
    "An empty response — authoritative servers do not answer A queries" \
    "A CNAME record pointing to www.example.com" \
    "example.com. 86400 IN A 93.184.216.34 — the real, authoritative IP address" \
    "D" 10 \
    "Authoritative server has the final answer — no more delegation." \
    "Authoritative servers return real records, not empty responses." \
    "There is no CNAME in example.com's DNS." \
    "" \
    "Final step of resolution:|Authoritative NS returns the real A record in the ANSWER section.|86400 = TTL (24h cache). 93.184.216.34 = example.com's actual IP." \
    "Authoritative = ANSWER section has the real IP. Resolution complete."

  ask_mc "Why is this answer authoritative — unlike the nslookup answer from earlier?" \
    "The IP address is different from what nslookup returned" \
    "It uses TCP instead of UDP so it is more reliable" \
    "It has a higher TTL so it is more authoritative" \
    "a.iana-servers.net holds the ACTUAL records for example.com — it is the source of truth" \
    "D" 10 \
    "The IP should be THE SAME — consistency is the point." \
    "Both typically use UDP 53. Protocol does not make it authoritative." \
    "TTL does not determine authority." \
    "" \
    "Authoritative = the nameserver that OWNS the records for this domain.|Unlike a recursive resolver which caches copies, the authoritative server gives original data." \
    "Authoritative = the owner. Resolver = the middleman with a copy."

  # ── STEP 4: Additional practice ─────────────────────────────────────────
  clear
  echo -e "${CYAN}${BOLD}  ZONE 7 — STEP 4: Bonus dig commands${NC}"
  echo ""
  echo -e "  ${BOLD}Try these in your terminal:${NC}"
  echo ""
  echo -e "  ${CYAN}    dig gmail.com MX${NC}         ${DIM}# Which mail server handles email for gmail.com?${NC}"
  echo -e "  ${CYAN}    dig example.com NS${NC}       ${DIM}# Which nameservers serve example.com?${NC}"
  echo -e "  ${CYAN}    dig +trace example.com${NC}   ${DIM}# Full recursive walk in one command${NC}"
  echo -e "  ${CYAN}    nslookup example.com${NC}     ${DIM}# Simple lookup — note 'Non-authoritative answer'${NC}"
  echo ""
  printf "  ${YELLOW}When done exploring, press Enter...${NC}"; read -r

  ask_mc "What does 'dig +trace example.com' do?" \
    "Shows traceroute (network hops) to example.com's server" \
    "Queries all DNS record types simultaneously" \
    "Enables verbose DNSSEC validation output" \
    "Shows the full recursive resolution from root -> TLD -> authoritative in one command" \
    "D" 10 \
    "+trace is DNS-specific, not network traceroute. Different tool." \
    "That would be dig ANY. +trace follows the delegation chain." \
    "DNSSEC validation is the +dnssec flag." \
    "" \
    "dig +trace follows the entire DNS delegation chain:|1. Queries root servers for .com NS|2. Queries .com TLD for example.com NS|3. Queries authoritative server for the A record" \
    "dig +trace = full DNS tree walk in one command."

  blank; echo "  ${GRN}${BOLD}Zone 7 complete! You walked the DNS tree.${RST}"; score_bar; zone_complete 7; pause
}

# Theory-only fallback when dig is not installed
zone7_theory_only() {
  echo ""
  echo -e "${BOLD}  DNS Resolution Flow (theory walk-through)${NC}"
  echo ""
  echo -e "  Step 1: dig @a.root-servers.net A example.com"
  echo -e "  ${DIM}  → AUTHORITY SECTION: com. 172800 IN NS a.gtld-servers.net. (and others)${NC}"
  echo -e "  ${DIM}  Root only knows which NS handles .com TLD${NC}"
  echo ""
  echo -e "  Step 2: dig @a.gtld-servers.net A example.com"
  echo -e "  ${DIM}  → AUTHORITY SECTION: example.com. 86400 IN NS a.iana-servers.net.${NC}"
  echo -e "  ${DIM}  TLD knows example.com\'s nameserver, but not the IP${NC}"
  echo ""
  echo -e "  Step 3: dig @a.iana-servers.net A example.com"
  echo -e "  ${DIM}  → ANSWER SECTION: example.com. 86400 IN A 93.184.216.34${NC}"
  echo -e "  ${DIM}  Authoritative server gives the real IP!${NC}"
  echo ""
  press_enter

  ask_mc "What does a root nameserver return when you ask for example.com's IP?" \
    "The final A record with example.com's IP" \
    "CNAME records redirecting to www.example.com" \
    "NS records pointing to the .com TLD nameservers — it does not know the IP itself" \
    "An error — root servers do not handle direct queries" \
    "C" 10 \
    "Root servers do not have leaf-level A records — they delegate to TLDs." \
    "CNAME is not part of the delegation chain." \
    "" \
    "Root servers DO respond — they just delegate instead of resolving." \
    "Root servers only hold NS records for TLDs (.com, .dk, .org etc.)." \
    "Root = knows TLDs only."

  ask_mc "After the root server, you ask a.gtld-servers.net. What does it return?" \
    "The final A record with example.com's IP" \
    "MX records for example.com's mail server" \
    "NS records pointing to example.com's own authoritative nameserver (a.iana-servers.net)" \
    "It redirects you back to the root server" \
    "C" 10 \
    "TLD servers do not have the final IP either." \
    "MX records are not part of the A record delegation chain." \
    "" \
    "Forward progress only — no loops back to root." \
    "The .com TLD knows which NS is authoritative for each .com domain.|It returns NS records pointing to the domain's own authoritative server." \
    "TLD -> domain's own NS. One more step to go."

  ask_mc "Which server finally returns the actual A record for example.com?" \
    "a.gtld-servers.net — the .com TLD nameserver" \
    "a.root-servers.net — the root nameserver" \
    "8.8.8.8 — Google's recursive resolver" \
    "a.iana-servers.net — the authoritative nameserver for example.com" \
    "D" 10 \
    "a.gtld-servers.net returned NS records (delegation), not the A record." \
    "Root servers only delegate to TLDs." \
    "8.8.8.8 is a resolver that would walk this chain for you, not the source." \
    "" \
    "The authoritative nameserver owns the DNS zone for example.com.|Only it can give you the definitive, authoritative A record." \
    "Authoritative = final answer. resolver = walks the chain for you."
}

# ─────────────────────────────────────────────────────────────────────────────

zone8_http() {
  header
  echo -e "${CYAN}${BOLD}  ┌─────────────────────────────────────────────┐"
  echo -e "  │  ZONE 8 — HTTP: Methods, Status Codes,       │"
  echo -e "  │            Headers & Sessions                │"
  echo -e "  └─────────────────────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${BOLD}GET vs POST${NC}"
  echo -e "  ${CYAN}GET${NC}   = retrieve data. Params in URL. No body. Bookmarkable. Cached."
  echo -e "  ${CYAN}POST${NC}  = send/create data. Params in body (hidden). Not cached."
  echo ""
  echo -e "  ${BOLD}Status Codes${NC}"
  echo -e "  ${G}2xx${NC} Success       200 OK, 201 Created, 204 No Content"
  echo -e "  ${YELLOW}3xx${NC} Redirect      301 Moved Permanently, 302 Found (temp)"
  echo -e "  ${R}4xx${NC} Client Error  400 Bad Request, 401 Unauthorized,"
  echo -e "                       403 Forbidden, 404 Not Found"
  echo -e "  ${MAGENTA}5xx${NC} Server Error  500 Internal Server Error, 503 Unavailable"
  echo ""
  echo -e "  ${DIM}  If you remember only 3: 200, 404, 500${NC}"
  echo ""
  echo -e "  ${BOLD}Headers${NC}"
  echo -e "  ${CYAN}Accept${NC}        → Client tells server: 'I want this format'"
  echo -e "                    e.g. Accept: application/json"
  echo -e "  ${CYAN}Content-Type${NC}  → Describes the format of the BODY being sent"
  echo -e "                    e.g. Content-Type: application/json"
  echo ""
  echo -e "  ${BOLD}HTTP is stateless — how do you stay logged in?${NC}"
  echo -e "  → Server sends a ${CYAN}cookie${NC} via Set-Cookie header (e.g. JSESSIONID)"
  echo -e "  → Browser stores it and sends it with every request via Cookie header"
  echo -e "  → Server recognises you by the cookie value"
  echo ""
  press_enter

  ask_mc "When should you use POST instead of GET?" \
    "When you want the response to be cached by the browser" \
    "When you want parameters visible in the URL" \
    "POST and GET are interchangeable — use either" \
    "When sending data that changes server state, or sending sensitive data (e.g. passwords)" \
    "D" 10 \
    "GET is cached. POST is NOT cached." \
    "GET puts params in URL. POST puts them in body (not visible)." \
    "They have fundamentally different semantics and safety properties." \
    "" \
    "GET = safe + idempotent. Retrieves data. Params in URL. Bookmarkable. Cached.|POST = unsafe. Sends/creates data. Params in body. Not cached.|Never use GET for passwords — URL appears in browser history and server logs." \
    "GET = read. POST = write/send. POST for passwords."

  ask_mc "A user submits a form with their password. Which method should the form use, and why?" \
    "GET — because it is faster and supports caching" \
    "POST — because it is encrypted, GET is not" \
    "GET — because passwords are short enough to fit in the URL" \
    "POST — because POST puts parameters in the body, not the URL (history/log safe)" \
    "D" 10 \
    "GET caching is a disadvantage here. Passwords should never be cached." \
    "POST is NOT encrypted by default. HTTPS provides encryption for BOTH methods." \
    "Length is irrelevant. Passwords in URLs are exposed in logs and history." \
    "" \
    "Passwords should use POST because:|1. Body is not logged in server access logs (URL is)|2. Not stored in browser history|3. Not leaked in Referer header|Note: POST alone is NOT encryption — use HTTPS for that." \
    "POST for passwords: body is hidden from logs. HTTPS for encryption."

  ask_mc "A Spring Boot endpoint successfully creates a new resource. Which status code is correct REST?" \
    "200 OK" \
    "201 Created" \
    "204 No Content" \
    "302 Found" \
    "B" 10 \
    "200 OK = success but resource already existed or data returned. 201 = newly created." \
    "" \
    "204 = success but no response body (e.g. DELETE)." \
    "302 = redirect. Not used for resource creation." \
    "REST status codes: 200=OK  201=Created  204=No Content|400=Bad Request  401=Unauthorized  403=Forbidden  404=Not Found|500=Internal Server Error  503=Service Unavailable" \
    "Created = 201. Not 200. The 1 means it is new."

  ask_mc "What is the difference between 401 and 403?" \
    "401 = forbidden; 403 = not authenticated" \
    "Both mean the same — access denied" \
    "401 = server error; 403 = client error" \
    "401 = not authenticated (not logged in); 403 = authenticated but forbidden" \
    "D" 10 \
    "Reversed. 401 = not authenticated. 403 = forbidden." \
    "They have different meanings — authentication vs authorization." \
    "Both are 4xx = client errors. 5xx = server errors." \
    "" \
    "401 Unauthorized = you have not proven who you are (not logged in).|403 Forbidden = we know who you are, but you do not have permission.|Example: 401 = no session cookie. 403 = logged in as user, tried admin page." \
    "401 = who are you? (authentication). 403 = I know you, but no. (authorization)"

  ask_mc "HTTP is stateless. How does a website keep you logged in between requests?" \
    "The browser automatically re-sends your username and password each time" \
    "HTTP/2 added a persistent 'logged-in' flag to the protocol" \
    "The server stores your IP address and recognises it on future requests" \
    "Via cookies — the server sends a session cookie; browser resends it every request" \
    "D" 10 \
    "Re-sending credentials each request would be insecure and slow." \
    "HTTP/2 adds multiplexing and header compression. Not a logged-in flag." \
    "IPs change (mobile, NAT). Not reliable for session tracking." \
    "" \
    "HTTP stateless = each request is independent. No memory of prior requests.|Session solution: server sends Set-Cookie: JSESSIONID=abc123 on login.|Browser stores cookie and sends Cookie: JSESSIONID=abc123 with every request.|Server looks up session by cookie value." \
    "Cookie = session ID. Browser sends it automatically. Server recognises you."

  ask_mc "What is the difference between the Accept and Content-Type headers?" \
    "Content-Type = what format the client wants; Accept = body format" \
    "They are the same — two names for the same concept" \
    "Accept only in responses; Content-Type only in requests" \
    "Accept = what format the client wants; Content-Type = format of the body being sent" \
    "D" 10 \
    "Reversed. Accept = what I want back. Content-Type = what I am sending." \
    "Completely different purposes." \
    "Accept can appear in requests. Content-Type appears in both." \
    "" \
    "Accept: application/json  = I want JSON back|Content-Type: application/json = the body I am sending IS JSON|In a POST request: both can appear." \
    "Accept = I accept this format. Content-Type = this is my content's type."

  blank; echo "  ${GRN}${BOLD}Zone 8 complete!${RST}"; score_bar; zone_complete 8; pause
}

# ─────────────────────────────────────────────────────────────────────────────
# RESULTS SCREEN
# ─────────────────────────────────────────────────────────────────────────────


# =============================================================================
#  RESULTS
# =============================================================================
results() {
  clear
  bigcap
  printf "  ${BOLD}${CYN}NETMASTER COMPLETE -- RESULTS FOR ${W}%s${RST}\n" "$PLAYER_NAME"
  bigcap; blank

  local pct=0
  [[ $MAX_SCORE -gt 0 ]] && pct=$(( (SCORE * 100) / MAX_SCORE ))

  local grade grade_col grade_msg
  if   [[ $pct -ge 90 ]]; then grade=12; grade_col="${GRN}"; grade_msg="Outstanding. You own this topic."
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
  echo "  ${W}KEY FACTS TO LOCK IN BEFORE THE EXAM${RST}"
  blank
  printf "  ${YLW}OSI vs TCP/IP${RST}\n"
  printf "  ${DIM}  OSI=7 layers | TCP/IP=4 layers | (L1+L2)->Link (L3)->Internet (L4)->Transport (L5+L6+L7)->App${RST}\n"
  blank
  printf "  ${YLW}Ports to memorise${RST}\n"
  printf "  ${DIM}  22=SSH  53=DNS  80=HTTP  443=HTTPS  3306=MySQL  5432=PostgreSQL  8080=dev${RST}\n"
  blank
  printf "  ${YLW}DNS delegation chain${RST}\n"
  printf "  ${DIM}  Root (NS for TLDs) -> TLD (NS for domains) -> Authoritative (actual A record)${RST}\n"
  blank
  printf "  ${YLW}TTL is overloaded${RST}\n"
  printf "  ${DIM}  TCP/IP TTL = hop count | DNS TTL = cache seconds${RST}\n"
  blank
  printf "  ${YLW}HTTP${RST}\n"
  printf "  ${DIM}  GET=read/cacheable | POST=write/body | 200=OK 201=Created 401=auth 403=authz 404=missing${RST}\n"
  printf "  ${DIM}  Stateless -> cookies carry session ID | Accept=want | Content-Type=sending${RST}\n"
  blank
  sep; blank
  bigcap
  printf "  ${GRN}Thanks for playing netmaster, ${BOLD}%s${RST}${GRN}!${RST}\n" "$PLAYER_NAME"
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
  while true; do
    BACK_TO_INTRO=false
    SCORE=0; MAX_SCORE=0; CORRECT=0; WRONG=0; RETRIED=0
    QUESTION_HISTORY=(); PREV_Q_ARGS=(); PREV_Q_FUNC=""

    intro

    [[ $START_ZONE -le 1 ]] && zone1_osi_model
    [[ $START_ZONE -le 2 ]] && zone2_ip_mac
    [[ $START_ZONE -le 3 ]] && zone3_router_switch_ports
    [[ $START_ZONE -le 4 ]] && zone4_tcp_packet
    [[ $START_ZONE -le 5 ]] && zone5_dns_basics
    [[ $START_ZONE -le 6 ]] && zone6_ttl_nameservers
    [[ $START_ZONE -le 7 ]] && zone7_dig_lab
    [[ $START_ZONE -le 8 ]] && zone8_http

    [[ "$BACK_TO_INTRO" == true ]] && continue
    results
    break
  done
}

main "$@"

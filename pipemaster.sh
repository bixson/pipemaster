#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║              CICDMASTER - CI/CD & GitHub Actions Exam Trainer               ║
# ║                     KEA Datamatiker Technology Exam                         ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ─── COLORS ────────────────────────────────────────────────────────────────────
R=$'\033[0;31m'   RED=$'\033[1;31m'
G=$'\033[0;32m'   GRN=$'\033[1;32m'
Y=$'\033[0;33m'   YLW=$'\033[1;33m'
B=$'\033[0;34m'   BLU=$'\033[1;34m'
M=$'\033[0;35m'   MAG=$'\033[1;35m'
C=$'\033[0;36m'   CYN=$'\033[1;36m'
W=$'\033[1;37m'   DIM=$'\033[2m'
RST=$'\033[0m'    BOLD=$'\033[1m'
BG_RED=$'\033[41m'  BG_GRN=$'\033[42m'  BG_YLW=$'\033[43m'

# Compatibility Aliases
GREEN=$GRN; YELLOW=$YLW; BLUE=$BLU; CYAN=$CYN; MAGENTA=$MAG; WHITE=$W; GRAY=$DIM; NC=$RST

# ─── SCORE TRACKING ────────────────────────────────────────────────────────────
SCORE=0
MAX_SCORE=0
CORRECT=0
WRONG=0
RETRIED=0
ZONE=0
PLAYER_NAME="Learner"
ZONE_SCORES=()
ZONE_MAX=()

declare -a QUESTION_HISTORY=()
CURRENT_Q_INDEX=0

# ─── PROGRESS FILE ─────────────────────────────────────────────────────────────
GAMEDIR="$HOME/.pipemaster"
LABDIR="$GAMEDIR/lab"
LOGFILE="$GAMEDIR/session.log"
PROGRESS_FILE="$GAMEDIR/progress"
mkdir -p "$LABDIR"

save_progress() {
    echo "SCORE=$SCORE" > "$PROGRESS_FILE"
    echo "MAX_SCORE=$MAX_SCORE" >> "$PROGRESS_FILE"
    echo "LAST_ZONE=$1" >> "$PROGRESS_FILE"
    echo "DATE=$(date)" >> "$PROGRESS_FILE"
}

load_progress() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        source "$PROGRESS_FILE"
        echo -e "${CYAN}Found previous session: Score $SCORE/$MAX_SCORE (Zone: $LAST_ZONE) — $DATE${NC}"
        echo -e "${YELLOW}Press [r] to resume from zone $LAST_ZONE, or any key for fresh start:${NC} "
        read -n1 choice
        echo
        if [[ "$choice" != "r" && "$choice" != "R" ]]; then
            SCORE=0; MAX_SCORE=0
        fi
    fi
}

# ─── VISUAL HELPERS ────────────────────────────────────────────────────────────
sep()    { printf "\n  ${DIM}${C}%s${RST}\n" "-----------------------------------------------------------"; }
bigcap() { printf "  ${BOLD}${C}%s${RST}\n"  "==========================================================="; }
pause()  { echo; printf "  ${DIM}[ Press ENTER to continue ]${RST}"; read -r; }
press_enter() { pause; }
blank()  { echo; }

typeit() {
  local text="$1" delay="${2:-18}"
  local i char
  for (( i=0; i<${#text}; i++ )); do
    char="${text:$i:1}"
    printf "%s" "$char"
    sleep "0.0${delay}" 2>/dev/null || true
  done
  echo
}

pbar() {
  local cur="$1" max="$2" width="${3:-40}"
  [[ $max -le 0 ]] && max=1
  local filled=$(( (cur * width) / max ))
  local bar="" i
  for ((i=0; i<filled; i++));     do bar+="#"; done
  for ((i=filled; i<width; i++)); do bar+="-"; done
  local pct=$(( (cur * 100) / max ))
  printf "  [%s] %d%%\n" "$bar" "$pct"
}

section_header() {
  local name="$1"
  bigcap
  printf "  ${BOLD}${CYN}%s${RST}\n" "$name"
  bigcap; blank
}

# ─── FEEDBACK BOXES ────────────────────────────────────────────────────────────
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
lab_pass()      { echo "  ${BOLD}${BG_GRN}  LAB PASS ${RST}${GRN}  ${1:-File verified.}${RST}"; }
lab_fail()      { echo "  ${BOLD}${BG_RED}  LAB FAIL ${RST}${R}  ${1}${RST}"; }

lab_header() {
  blank; sep
  printf "  ${BOLD}${MAG}[ LAB ] %s${RST}\n" "$1"
  printf "  ${DIM}%s${RST}\n" "${2:-Practical Exercise}"
  printf "  ${DIM}Working directory: ${W}~/.pipemaster/lab/${RST}\n"
  sep; blank
}

# ─── SCORE HELPERS ─────────────────────────────────────────────────────────────
LAB_TASKS=0
LAB_CORRECT=0
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

# ─── CORE GAME ENGINE ──────────────────────────────────────────────────────────
ask_mc() {
  local q="$1"
  local oa="$2" ob="$3" oc="$4" od="$5"
  local correct="${6^^}" pts="$7"
  local wa="$8" wb="$9" wc="${10}" wd="${11}"
  local teaching="${12:-}" memtip="${13:-}"

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank
  echo -e "  ${CYAN}${BOLD}Q: ${q}${RST}"
  blank
  echo -e "  ${YLW}A)${RST} $oa"
  echo -e "  ${YLW}B)${RST} $ob"
  echo -e "  ${YLW}C)${RST} $oc"
  echo -e "  ${YLW}D)${RST} $od"
  blank

  local ans ans2
  while true; do
    printf "  ${CYN}Your answer [A/B/C/D]: ${RST}"
    read -rsn1 ans

    if [[ "$ans" == $'\x0e' ]]; then
      echo; printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
      correct_box; _award "$pts"; return 0
    elif [[ "$ans" == $'\x02' ]]; then
      echo; printf "  ${YLW}[UNDO - Question reset]${RST}\n"
      SCORE="$score_before"; MAX_SCORE="$max_before"; CORRECT="$correct_before"
      WRONG="$wrong_before"; RETRIED="$retried_before"
      unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
      return 0
    fi

    ans="${ans^^}"
    case "$ans" in A|B|C|D) break ;; esac
    echo; echo -e "  ${RED}  Please type A, B, C or D${RST}"
  done

  echo
  printf "  ${DIM}You chose: %s${RST}\n" "$ans"

  if [[ "$ans" == "$correct" ]]; then
    correct_box "The answer is $correct."; _award "$pts"; return
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

ask_typed() {
  local q="$1" expected="$2" pts="$3"
  local retry_hint="${4:-}" model="${5:-}"
  local teaching="${6:-}" memtip="${7:-}" mode="${8:-contains}"

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank; echo -e "  ${CYAN}${BOLD}Q: ${q}${RST}"
  printf "  ${CYN}> ${RST}"

  read -rsn1 ans_first
  if [[ "$ans_first" == $'\x0e' ]]; then
    echo; printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
    correct_box; _award "$pts"; return 0
  elif [[ "$ans_first" == $'\x02' ]]; then
    echo; printf "  ${YLW}[UNDO - Question reset]${RST}\n"
    SCORE="$score_before"; MAX_SCORE="$max_before"; CORRECT="$correct_before"
    WRONG="$wrong_before"; RETRIED="$retried_before"
    unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
    return 0
  fi

  printf "%s" "$ans_first"
  local ans ans2
  read -r ans_rest
  ans="${ans_first}${ans_rest}"
  ans="$(echo "$ans" | xargs 2>/dev/null || echo "$ans")"

  _typed_match() {
    local a="${1,,}" e="${2,,}"
    if [[ "$mode" == "contains" ]]; then echo "$a" | grep -qiF "$e"
    else [[ "$a" == "$e" ]]; fi
  }

  if _typed_match "$ans" "$expected"; then
    correct_box "Key concept present: '$expected'"; _award "$pts"; return
  fi

  echo -e "  ${RED}  Not quite.${RST}  ${DIM}Hint: ${retry_hint}${RST}"
  blank
  printf "  ${YLW}  [RETRY] One more try for half points > ${RST}"; read -r ans2
  ans2="$(echo "$ans2" | xargs 2>/dev/null || echo "$ans2")"

  if _typed_match "$ans2" "$expected"; then
    correct_box "Correct on retry!"; _half "$pts"; return
  fi

  wrong_box "Still not right. Moving on."
  answer_reveal "${model:-$expected}"; _miss "$pts"
  
  if [[ -n "$teaching" ]]; then
    IFS='|' read -ra tlines <<< "$teaching"; teach "${tlines[@]}"
  fi
  [[ -n "$memtip" ]] && tip "$memtip"
}

# ─── SIMULATED LAB ENVIRONMENT ─────────────────────────────────────────────────
do_task() {
  local instr="$1" check="$2" pts="$3"
  local solution="${4:-}" explanation="${5:-}"

  LAB_TASKS=$((LAB_TASKS + 1))

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank
  printf "  ${MAG}${BOLD}[ TASK ]${RST} ${W}%s${RST}\n" "$instr"
  blank
  printf "  ${DIM}-> Do this in your lab terminal (cd ~/.pipemaster/lab/)${RST}\n"
  printf "  ${DIM}-> When done, press ENTER here to verify.${RST}\n"

  local input
  read -rsn1 input

  if [[ "$input" == $'\x0e' ]]; then
    echo; printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
    lab_pass "Task accepted."; _award "$pts"; LAB_CORRECT=$((LAB_CORRECT + 1))
    return 0
  elif [[ "$input" == $'\x02' ]]; then
    echo; printf "  ${YLW}[UNDO - Task reset]${RST}\n"
    SCORE="$score_before"; MAX_SCORE="$max_before"; CORRECT="$correct_before"
    WRONG="$wrong_before"; RETRIED="$retried_before"; LAB_TASKS=$((LAB_TASKS - 1))
    unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
    return 0
  fi

  # Run check in LABDIR context
  if (cd "$LABDIR" && eval "$check" &>/dev/null 2>&1); then
    lab_pass; _award "$pts"; LAB_CORRECT=$((LAB_CORRECT + 1)); return
  fi

  blank
  printf "  ${RED}${BOLD}  [x] Verification failed.${RST}\n"
  blank
  if [[ -n "$solution" ]]; then
    printf "  ${W}  Solution:${RST}\n"
    IFS='|' read -ra slines <<< "$solution"
    for sline in "${slines[@]}"; do
      printf "  ${BOLD}${CYN}    %s${RST}\n" "$sline"
    done
  fi
  [[ -n "$explanation" ]] && printf "\n  ${DIM}  Why: %s${RST}\n" "$explanation"
  blank
  printf "  ${YLW}  Make the fix now, then press ENTER for half points:${RST}\n"
  read -r

  if (cd "$LABDIR" && eval "$check" &>/dev/null 2>&1); then
    lab_pass "Correct after hint!"; _half "$pts"; LAB_CORRECT=$((LAB_CORRECT + 1)); return
  fi

  lab_fail "Still not verified. Moving on."; _miss "$pts"
}

setup_labs() {
    mkdir -p "$LABDIR"
    # Basic README for the lab
    cat > "$LABDIR/README.md" << 'EOF'
# pipemaster Sandbox
Follow the instructions in the main trainer.
Work in this directory to complete tasks.
EOF
    
    # Zone 2 Lab: workflow with missing needs
    mkdir -p "$LABDIR/workflows"
    cat > "$LABDIR/workflows/deploy.yaml" << 'EOF'
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: mvn test
  deploy:
    # MISSING: needs: [test]
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
EOF

    # Zone 4 Lab: workflow missing a run step
    cat > "$LABDIR/workflows/build.yaml" << 'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      # MISSING: run: mvn package -DskipTests
EOF

    # Zone 5 Lab: workflow missing caching
    cat > "$LABDIR/workflows/cache.yaml" << 'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # MISSING Cache step here
      - run: mvn test
EOF

    # Zone 6 Lab: Script permissions
    cat > "$LABDIR/deploy.sh" << 'EOF'
#!/bin/bash
echo "Deploying..."
EOF
    chmod 644 "$LABDIR/deploy.sh"

    # Zone 7 Lab: Insecure Docker and SSH deployment
    cat > "$LABDIR/compose.yaml" << 'EOF'
services:
  app:
    ports:
      - "3306:3306" # INSECURE: binds to 0.0.0.0
EOF
    cat > "$LABDIR/deploy.yaml" << 'EOF'
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        # MISSING: SSH command to pull and up
        run: echo "deploying..."
EOF
}

setup_labs

# ─── ASCII HEADER ──────────────────────────────────────────────────────────────
show_header() {
    clear
    printf "${CYAN}"
    cat << 'EOF'

                                                        )    )
                                              __       (    (
                                            (    )        )__)
                                            |   '|'      |   |
                                            |   '|    .·´.·´
                                            |   '|.·´.·´
                                            |    .·´
                                         .·´     `·.
                                       (_____________)
 /$$$$$$$  /$$$$$$ /$$$$$$$  /$$$$$$$$ /$$      /$$  /$$$$$$   /$$$$$$  /$$$$$$$$ /$$$$$$$$ /$$$$$$$
| $$__  $$|_  $$_/| $$__  $$| $$_____/| $$$    /$$$ /$$__  $$ /$$__  $$|__  $$__/| $$_____/| $$__  $$
| $$  \ $$  | $$  | $$  \ $$| $$      | $$$$  /$$$$| $$  \ $$| $$  \__/   | $$   | $$      | $$  \ $$
| $$$$$$$/  | $$  | $$$$$$$/| $$$$$   | $$ $$/$$ $$| $$$$$$$$|  $$$$$$    | $$   | $$$$$   | $$$$$$$/
| $$____/   | $$  | $$____/ | $$__/   | $$  $$$| $$| $$__  $$ \____  $$   | $$   | $$__/   | $$__  $$
| $$        | $$  | $$      | $$      | $$\  $ | $$| $$  | $$ /$$  \ $$   | $$   | $$      | $$  \ $$
| $$       /$$$$$$| $$      | $$$$$$$$| $$ \/  | $$| $$  | $$|  $$$$$$/   | $$   | $$$$$$$$| $$  | $$
|__/      |______/|__/      |________/|__/     |__/|__/  |__/ \______/    |__/   |________/|__/  |__/

                                      [ CI/CD — Github ]
EOF
    printf "${RST}"
    echo
    typeit "  Topic: CI/CD, GitHub Actions & Maven in CI" 10
    typeit "  Zones: 7 | Questions per zone: 4-5 | Scoring: exam-calibrated" 10
    echo
}

# ─── ZONE MENU ─────────────────────────────────────────────────────────────────
show_menu() {
    bigcap
    printf "  ${BOLD}${W}SELECT ZONE${RST}  |  ${DIM}Current Score: ${CYN}%d/%d${RST}\n" "$SCORE" "$MAX_SCORE"
    bigcap
    echo
    echo -e "  ${CYN}[1]${RST} Zone 1 — CI/CD Concepts"
    echo -e "  ${CYN}[2]${RST} Zone 2 — Workflow Structure: Jobs & Steps"
    echo -e "  ${CYN}[3]${RST} Zone 3 — Triggers"
    echo -e "  ${CYN}[4]${RST} Zone 4 — uses: vs run:"
    echo -e "  ${CYN}[5]${RST} Zone 5 — Caching"
    echo -e "  ${CYN}[6]${RST} Zone 6 — Hash-Pinning & Security"
    echo -e "  ${CYN}[7]${RST} Zone 7 — Maven in CI & Docker in CD"
    echo
    echo -e "  ${CYN}[9]${RST} Show score / grade estimate"
    echo -e "  ${CYN}[R]${RST} Quick Reference Cheat Sheet"
    echo -e "  ${CYN}[0]${RST} Exit"
    echo
    printf "  ${CYN}${BOLD}[ Press ENTER for FULL EXAM ]${RST}  or choice: "
}

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 1: CI/CD CONCEPTS
# ══════════════════════════════════════════════════════════════════════════════
zone1() {
    section_header "ZONE 1 — CI/CD Concepts"
    local z_score=0
    local z_start=$SCORE

    echo -e "${GRAY}What is CI/CD, why does it exist, and what does it guarantee?${NC}"
    echo
    press_enter

    # Q1 - MC
    ask_mc \
        "What is a CI pipeline in GitHub Actions?" \
        "A manual checklist of code review steps" \
        "A file (workflow) that defines automated jobs and steps for code quality" \
        "A cloud server that hosts the production database" \
        "A tool for managing project boards and issues" \
        "B" 2 \
        "A is code review, which is usually part of the PR but not the 'pipeline' itself." \
        "CORRECT — it is a set of automated jobs/steps defined in a YAML workflow." \
        "C is hosting, not the pipeline." \
        "D is GitHub Issues/Projects."

    # Q2 - MC
    ask_mc \
        "What is the key difference between CI and CD?" \
        "CI runs on every push; CD runs only on weekdays" \
        "CI checks code quality; CD delivers the software to an environment" \
        "CI requires Docker; CD does not" \
        "CI is for backend; CD is for frontend" \
        "B" 2 \
        "A is incorrect — timing is not the distinction." \
        "CORRECT — CI = quality gate; CD = delivery/deployment." \
        "C is false — neither requires Docker inherently." \
        "D is false — both apply to any part of the codebase."


    # Q4 - MC
    ask_mc \
        "In GitHub Actions terminology, where are CI workflow files stored?" \
        "In the root of the repository" \
        "In a folder called .ci/ at the root" \
        "In .github/workflows/ as .yaml or .yml files" \
        "In the GitHub web UI only, not in the repo" \
        "C" 2 \
        "A is wrong — they must be in the specific .github/workflows/ directory." \
        "B is wrong — .ci/ is not a recognized path for GitHub Actions." \
        "CORRECT — .github/workflows/*.yaml is the required location." \
        "D is wrong — workflows live in the repository alongside the code."

    # Q3 - MC: Cloud Models
    ask_mc \
        "What is the difference between IaaS and PaaS?" \
        "IaaS = you manage infrastructure; PaaS = you manage OS" \
        "IaaS = cloud manages everything; PaaS = you manage hardware" \
        "IaaS = you manage the OS and runtime; PaaS = you only deploy code" \
        "IaaS is for frontend; PaaS is for backend" \
        "C" 2 \
        "A is backwards — Cloud manages infrastructure in both, but you manage OS in IaaS." \
        "B is false — Cloud never lets you manage hardware." \
        "CORRECT — IaaS (e.g. EC2) gives you an OS; PaaS (e.g. Heroku) handles the runtime." \
        "D is false — both are for any type of application."

    # Q4 - MC: SSH Keys
    ask_mc \
        "When setting up SSH authentication for GitHub, which key should you NEVER share?" \
        "id_rsa.pub (Public Key)" \
        "id_rsa (Private Key)" \
        "authorized_keys" \
        "known_hosts" \
        "B" 2 \
        "A is safe to share; it goes on the server." \
        "CORRECT — your private key is your secret identity. Never share it." \
        "C is for the server side." \
        "D stores host fingerprints, not your identity."

    # Q5 - Typed: Redirection
    ask_typed \
        "Which operator do you use to APPEND output to a file without overwriting it?" \
        ">>" 2 \
        "Think: > overwrites, while this operator adds to the end." \
        ">>" \
        "Use >> to append output. Example: 'echo \"log\" >> file.txt' adds to the end."

    ZONE_SCORES+=($((SCORE - z_start)))
    ZONE_MAX+=(10)
    save_progress 1
}

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 2: WORKFLOW STRUCTURE — JOBS & STEPS
# ══════════════════════════════════════════════════════════════════════════════
zone2() {
    section_header "ZONE 2 — Workflow Structure: Jobs & Steps"
    local z_start=$SCORE

    echo -e "${GRAY}Understand the hierarchy: workflow → jobs → steps.${NC}"
    echo
    press_enter

    # Q1 - MC
    ask_mc \
        "By default, how do multiple jobs in the same workflow execute?" \
        "Sequentially — one after another" \
        "In parallel — simultaneously on separate runners" \
        "Randomly — GitHub decides based on load" \
        "Only one job runs; you cannot have multiple jobs" \
        "B" 2 \
        "A is wrong — steps are sequential, not jobs. Jobs are parallel by default." \
        "CORRECT — jobs run in parallel on separate runners unless you use needs:." \
        "C is wrong — the default behaviour is deterministic parallel execution." \
        "D is wrong — you can define as many jobs as needed."

    # Q2 - MC
    ask_mc \
        "How do steps within a single job execute?" \
        "In parallel on the same runner" \
        "In parallel on separate runners" \
        "Sequentially — one at a time on the same runner" \
        "Randomly based on runner load" \
        "C" 2 \
        "A is wrong — steps share the same runner and run one at a time." \
        "B is wrong — separate runners are for separate jobs, not steps." \
        "CORRECT — steps run sequentially within a job on the same runner." \
        "D is wrong — step order is defined and deterministic."

    # Q3 - Typed
    ask_typed \
        "You need Job B to wait for Job A to finish before starting. What keyword do you use?" \
        "needs" 2 \
        "It's a job-level keyword, not a step. Think about declaring a dependency between jobs." \
        "Use the 'needs:' keyword at the job level: needs: [job-a]. This creates a dependency so Job B waits for Job A."

    # Q4 - MC
    ask_mc \
        "What does runs-on: ubuntu-latest mean in a job definition?" \
        "The job runs on the developer's local Ubuntu machine" \
        "The job runs on a GitHub-hosted Ubuntu runner" \
        "The job requires Ubuntu to be installed in the Docker image" \
        "The job only runs when the latest Ubuntu is released" \
        "B" 2 \
        "A is wrong — CI runs on GitHub-hosted (or self-hosted) runners, not your local machine." \
        "CORRECT — runs-on specifies the runner environment for the job." \
        "C is wrong — this is a runner OS, not a Docker image requirement." \
        "D is wrong — 'latest' refers to the runner OS tag, not a release trigger."

    # Q5 - Typed
    ask_typed \
        "Why does each job get its own fresh runner environment?" \
        "isolation" 2 \
        "Think about what this means for sharing files between jobs." \
        "isolation" \
        "Each job is isolated — it runs on a separate, fresh runner. This means jobs do not share files or state. If you need artifacts between jobs, you must explicitly upload and download them."

    # Lab: Zone 2 - Needs Dependency
    lab_header "Fixing Workflow Dependencies" "The 'deploy' job must wait for the 'test' job to pass."
    do_task \
        "Add 'needs: [test]' to the 'deploy' job in 'workflows/deploy.yaml'." \
        "grep -q \"needs:[[:space:]]*\[test\]\" workflows/deploy.yaml" \
        5 \
        "needs: [test]" \
        "The 'needs' keyword creates a dependency. Without it, deploy would run in parallel with tests!"

    ZONE_SCORES+=($((SCORE - z_start)))
    ZONE_MAX+=(15)
    save_progress 2
}

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 3: TRIGGERS
# ══════════════════════════════════════════════════════════════════════════════
zone3() {
    section_header "ZONE 3 — Triggers"
    local z_start=$SCORE

    echo -e "${GRAY}When and how does a GitHub Actions workflow start?${NC}"
    echo
    press_enter

    # Q1 - MC
    ask_mc \
        "Which trigger keyword allows you to manually start a workflow from the GitHub UI?" \
        "manual_trigger:" \
        "workflow_dispatch:" \
        "on_demand:" \
        "trigger: manual" \
        "B" 2 \
        "A is not a valid GitHub Actions keyword." \
        "CORRECT — workflow_dispatch: adds a manual 'Run workflow' button in the Actions UI." \
        "C is not a valid GitHub Actions keyword." \
        "D is not valid YAML syntax for GitHub Actions triggers."

    # Q2 - MC
    ask_mc \
        "What is the purpose of adding pull_request: as a trigger?" \
        "It runs the workflow when a PR is closed" \
        "It runs the workflow when code is pushed to any branch" \
        "It runs CI when a pull request targets the specified branches, enabling review gating" \
        "It forces the reviewer to approve CI results before merging" \
        "C" 2 \
        "A is wrong — pull_request: triggers on PR open/update, not close by default." \
        "B is wrong — that describes push: not pull_request:." \
        "CORRECT — CI runs on PRs targeting specified branches, blocking merges until CI passes." \
        "D is wrong — branch protection rules enforce that, not the trigger itself."

    # Q3 - Typed
    ask_typed \
        "You want CI to run on pushes to main AND on pull requests targeting main. Write the on: block." \
        "pull_request" 2 \
        "You need two keys under on: — one for push and one for pull_request, each with branches: [main]." \
        "on:\n  push:\n    branches:\n      - main\n  pull_request:\n    branches:\n      - main"

    # Q4 - MC
    ask_mc \
        "What is the practical effect of having workflow_dispatch: with no extra arguments?" \
        "The workflow runs every 5 minutes automatically" \
        "Nothing — it requires at least one input to work" \
        "A 'Run workflow' button appears in the GitHub Actions UI for manual triggering" \
        "The workflow can only be triggered via the GitHub API, not the UI" \
        "C" 2 \
        "A describes schedule: with a cron expression." \
        "B is wrong — workflow_dispatch: alone (with no inputs) is valid and adds the button." \
        "CORRECT — a bare workflow_dispatch: adds a manual trigger button in the Actions tab." \
        "D is wrong — the UI button appears; API triggering is also possible but not exclusive."

    ZONE_SCORES+=($((SCORE - z_start)))
    ZONE_MAX+=(8)
    save_progress 3
}

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 4: uses: vs run:
# ══════════════════════════════════════════════════════════════════════════════
zone4() {
    section_header "ZONE 4 — uses: vs run:"
    local z_start=$SCORE

    echo -e "${GRAY}The two types of steps — and when to use each.${NC}"
    echo
    press_enter

    # Q1 - MC
    ask_mc \
        "What does uses: do in a GitHub Actions step?" \
        "Runs a shell command on the runner" \
        "Calls a pre-built action from another repository" \
        "Imports a secret into the environment" \
        "Defines which runner OS to use" \
        "B" 2 \
        "A describes run: not uses:." \
        "CORRECT — uses: references a GitHub Action (a reusable unit) stored in another repo." \
        "C is wrong — secrets are accessed via env: or secrets context, not uses:." \
        "D is wrong — that is runs-on: at the job level."

    # Q2 - MC
    ask_mc \
        "What does run: do in a GitHub Actions step?" \
        "Calls an action from the GitHub Marketplace" \
        "Sets up a specific tool like Java or Node.js" \
        "Executes a shell command on the runner" \
        "Defines the runner operating system" \
        "C" 2 \
        "A describes uses:." \
        "B is done via uses: actions/setup-java@v4 etc." \
        "CORRECT — run: executes a shell command directly on the runner (bash, sh, etc.)." \
        "D is runs-on: at the job level."

    # Q3 - Typed
    ask_typed \
        "Give a concrete example of when run: is more useful than uses:." \
        "mvn" 2 \
        "Think about running Maven commands. You can't use a pre-built action for every custom command." \
        "run: is useful for custom shell commands like 'run: mvn test', 'run: docker build -t myapp .', or 'run: curl http://localhost:8080/healthz'. No pre-built action exists for these."

    # Q4 - MC
    ask_mc \
        "Which of these is a correct uses: step for checking out code?" \
        "run: git checkout main" \
        "uses: actions/checkout@v4" \
        "uses: git/checkout@latest" \
        "run: actions/checkout" \
        "B" 2 \
        "A uses run: — this would only work with a configured git setup, not recommended in CI." \
        "CORRECT — actions/checkout@v4 is the official action for checking out repository code." \
        "C is wrong — the correct namespace is actions/, not git/." \
        "D is wrong — actions/checkout is an action, so it must use uses:, not run:."

    # Q5 - Lab
    section_header "  MINI LAB: Classify these steps"
    echo -e "${GRAY}For each step below, say whether it would use 'uses:' or 'run:'.${NC}"
    echo
    echo -e "  1. Checkout the repository code"
    echo -e "  2. Run Maven tests"
    echo -e "  3. Set up Java 21 (Temurin distribution)"
    echo -e "  4. Build a Docker image with a custom tag"
    echo -e "  5. Cache Maven dependencies"
    echo
    echo -ne "${YELLOW}Your answers (e.g. 'uses run uses run uses'): ${NC}"
    read -r lab_answer
    lab_lower=$(echo "$lab_answer" | tr '[:upper:]' '[:lower:]')
    correct_pattern="uses run uses run uses"
    if [[ "$lab_lower" == *"uses"*"run"*"uses"*"run"*"uses"* ]]; then
        correct "Pattern matches: uses / run / uses / run / uses" 3
    else
        wrong "Expected: uses / run / uses / run / uses\n  1→uses:actions/checkout  2→run:mvn test  3→uses:actions/setup-java  4→run:docker build  5→uses:actions/cache" 3
    fi

    lab_header "Uses vs Run" "Sometimes pre-built actions don't cover everything."
    do_task \
        "Add a step to 'workflows/build.yaml' that executes 'mvn package -DskipTests' using the 'run:' keyword." \
        "grep -q \"run:[[:space:]]*mvn[[:space:]]*package[[:space:]]*-DskipTests\" workflows/build.yaml" \
        5 \
        "run: mvn package -DskipTests" \
        "The 'run' keyword is for shell commands like Maven, Gradle, or custom scripts."

    ZONE_SCORES+=($((SCORE - z_start)))
    ZONE_MAX+=(16)
    save_progress 4
}

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 5: CACHING
# ══════════════════════════════════════════════════════════════════════════════
zone5() {
    section_header "ZONE 5 — Caching in GitHub Actions"
    local z_start=$SCORE

    echo -e "${GRAY}Understand why caching matters, how cache keys work, and the tradeoffs.${NC}"
    echo
    press_enter

    # Q1 - MC
    ask_mc \
        "What is the primary purpose of caching Maven dependencies in CI?" \
        "To permanently store compiled .class files in the repository" \
        "To avoid downloading all dependencies from the internet on every CI run" \
        "To share dependencies between different projects" \
        "To compress the Maven repository for smaller Docker images" \
        "B" 2 \
        "A is wrong — .class files can be cached too, but the primary purpose is dependency downloading." \
        "CORRECT — caching saves time (and CO2) by reusing previously downloaded packages." \
        "C is wrong — cache is scoped to a specific repository/workflow." \
        "D is wrong — caching is for CI speed, not Docker image size."

    # Q2 - Typed
    ask_typed \
        "What happens to the cache if the key changes (e.g. pom.xml modified)?" \
        "invalidated" 2 \
        "Think: when the key changes, the old data is no longer valid." \
        "invalidated" \
        "A cache key determines which data to reuse. If the key changes, the old cache is invalidated and a fresh download occurs."

    # Q3 - MC
    ask_mc \
        "In this cache key: key: maven-\${{ hashFiles('**/pom.xml') }}  — what triggers a cache refresh?" \
        "Every push to any branch" \
        "Any change to a pom.xml file anywhere in the project" \
        "Only changes to the src/ directory" \
        "Only when a new GitHub Actions runner is provisioned" \
        "B" 2 \
        "A is wrong — the key is based on file content hash, not push events." \
        "CORRECT — hashFiles hashes the content of pom.xml. If pom.xml changes, the hash changes, old cache is discarded." \
        "C is wrong — the cache key only watches pom.xml, not src/." \
        "D is wrong — the cache key is content-based, not runner-based."

    # Q4 - MC
    ask_mc \
        "Why is the heuristic 'invalidate cache on pom.xml change' acceptable but imperfect?" \
        "It re-downloads too infrequently, risking stale dependencies" \
        "It sometimes re-downloads all dependencies when only unrelated parts of pom.xml changed" \
        "It only caches 3rd-party dependencies, not the project's own classes" \
        "pom.xml changes are too rare to be useful as a cache key" \
        "B" 2 \
        "A is wrong — it errs on the side of re-downloading too often, not too infrequently." \
        "CORRECT — any pom.xml change (even comments) busts the cache, even if dependencies didn't change." \
        "C is a true statement but not the reason the heuristic is imperfect." \
        "D is wrong — pom.xml changes regularly during development."

    # Q5 - Typed
    ask_typed \
        "Which environmental metric is improved by shorter CI runtime from caching?" \
        "CO2" 2 \
        "Think of the greenhouse gas emissions associated with compute power." \
        "CO2" \
        "Caching reduces CI runtime, which reduces compute power consumption and associated CO2 emissions."

    # Lab: Zone 5 - Maven Cache
    lab_header "Speeding up CI" "A fresh runner is slow. Use actions/cache."
    do_task \
        "Add an 'actions/cache@v4' step to 'workflows/cache.yaml' that caches the '~/.m2/repository' path." \
        "grep -q \"uses:[[:space:]]*actions/cache@v4\" workflows/cache.yaml && grep -q \"path:[[:space:]]*~/.m2/repository\" workflows/cache.yaml" \
        5 \
        "uses: actions/cache@v4|  with:|    path: ~/.m2/repository" \
        "Caching the Maven repository saves minutes of download time in large projects."

    ZONE_SCORES+=($((SCORE - z_start)))
    ZONE_MAX+=(15)
    save_progress 5
}

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 6: HASH-PINNING & SECURITY
# ══════════════════════════════════════════════════════════════════════════════
zone6() {
    section_header "ZONE 6 — Hash-Pinning & Security"
    local z_start=$SCORE

    echo -e "${GRAY}Security hardening: why version tags are dangerous, and how to fix it.${NC}"
    echo
    press_enter

    # Q1 - MC
    ask_mc \
        "What is the security problem with using uses: actions/setup-java@v4?" \
        "v4 will stop working after 12 months automatically" \
        "v4 is a git tag that can be deleted and recreated to point to malicious code" \
        "v4 requires a paid GitHub plan to use" \
        "v4 downloads Java from an untrusted mirror" \
        "B" 2 \
        "A is wrong — tags don't expire automatically." \
        "CORRECT — a git tag is mutable. A malicious actor (or compromised maintainer) can move the tag to different code." \
        "C is wrong — GitHub Actions are free for public repositories." \
        "D is wrong — the issue is with tag mutability, not the Java download source."

    # Q2 - Typed
    ask_typed \
        "Besides security, what is the other key benefit of hash-pinning?" \
        "reproducibility" 2 \
        "Think: getting the exact same result every single time." \
        "reproducibility" \
        "Hash-pinning ensures you get the exact same code every time (Reproducibility) and prevents tag-swapping attacks (Security)."

    # Q3 - MC
    ask_mc \
        "Which of these is a correctly hash-pinned step?" \
        "uses: actions/setup-java@latest" \
        "uses: actions/setup-java@v4.3.0" \
        "uses: actions/setup-java@2dfa2011c5b2a0f1489bf9e433881c92c1631f88 # v4.3.0" \
        "run: git checkout actions/setup-java@sha256" \
        "C" 2 \
        "A uses 'latest' which is the worst option — most mutable tag possible." \
        "B uses a version tag which is still mutable, just more specific." \
        "CORRECT — the full commit SHA is cryptographically unique and cannot be faked." \
        "D is invalid syntax — run: executes shell, not action references."

    # Q4 - MC
    ask_mc \
        "Why is a commit SHA cryptographically safer than a version tag like v4?" \
        "SHAs are stored encrypted; tags are stored in plain text" \
        "SHAs are generated from the content — it is computationally infeasible to create a collision" \
        "SHAs are verified by GitHub's security team before publishing" \
        "SHAs cannot be used with third-party actions, only official ones" \
        "B" 2 \
        "A is wrong — both are stored as plain text in git." \
        "CORRECT — a SHA is a cryptographic hash of the commit content. Creating a different commit with the same SHA is practically impossible." \
        "C is wrong — GitHub does not manually verify every action commit." \
        "D is wrong — SHAs work for any action in any public repository."

    # Q5 - MC: Permissions
    ask_mc \
        "What does 'chmod 755 script.sh' do?" \
        "Gives everyone full control (rwx)" \
        "Owner: rwx; Group: r-x; Others: r-x" \
        "Owner: rw-; Group: r--; Others: r--" \
        "Makes the script hidden" \
        "B" 2 \
        "A is chmod 777." \
        "CORRECT — 7 (rwx) for owner, 5 (r-x) for group and others." \
        "C is chmod 644." \
        "D is nonsense."

    # Q7 - Typed: Port Monitoring
    ask_typed \
        "Which command is used to show all listening ports and their associated PIDs on Linux?" \
        "ss" 2 \
        "Think of a modern replacement for 'netstat'. Use the flags '-tulnp'." \
        "ss -tulnp" \
        "The 'ss' (socket statistics) command with '-tulnp' shows TCP/UDP listening ports and the process using them."

    # Lab: Zone 6 - Permissions
    lab_header "File Permissions" "Scripts must be executable to run in CI."
    do_task \
        "Make 'deploy.sh' executable for the owner (at least)." \
        "[[ -x deploy.sh ]]" \
        5 \
        "chmod +x deploy.sh" \
        "In CI/CD, if you try to run a script that isn't executable, the job will fail with 'Permission denied'."

    ZONE_SCORES+=($((SCORE - z_start)))
    ZONE_MAX+=(17)
    save_progress 6
}

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 7: MAVEN IN CI & DOCKER IN CD
# ══════════════════════════════════════════════════════════════════════════════
zone7() {
    section_header "ZONE 7 — Maven in CI & Docker in CD"
    local z_start=$SCORE

    echo -e "${GRAY}Which Maven commands belong in CI, and how does Docker fit into CD?${NC}"
    echo
    press_enter

    # Q1 - MC
    ask_mc \
        "Which Maven command is most common in a basic CI pipeline for a Java project?" \
        "mvn install" \
        "mvn deploy" \
        "mvn test" \
        "mvn clean" \
        "C" 2 \
        "A installs to local .m2 repo — useful, but mvn test is the core CI check." \
        "B deploys to a remote artifact repository — that is CD, not CI." \
        "CORRECT — mvn test compiles and runs all unit/integration tests, which is the CI contract." \
        "D only cleans build output — it doesn't verify anything."

    # Q2 - MC
    ask_mc \
        "What does mvn package do in a CI context?" \
        "Deploys the JAR to a remote Maven repository" \
        "Compiles the source and packages it into a JAR/WAR without running integration tests" \
        "Only downloads dependencies, does not compile" \
        "Pushes the Docker image to a container registry" \
        "B" 2 \
        "A is mvn deploy." \
        "CORRECT — mvn package compiles code and creates the deployable artifact (JAR/WAR)." \
        "C is mvn dependency:go-offline or similar." \
        "D has nothing to do with Maven."

    # Q3 - Typed
    ask_typed \
        "Building the Dockerfile in CI ensures successful ___________ testing." \
        "integration" 2 \
        "Think about the 'I' in CI: Testing how components (code + OS) work together." \
        "integration" \
        "Building the Dockerfile in CI is an integration test. It catches errors in the environment setup before they reach production."

    # Q4 - MC
    ask_mc \
        "In a CD pipeline that pushes a Docker image to GHCR, what provides the authentication token?" \
        "A hardcoded password in the YAML file" \
        "The developer's personal GitHub token stored as a secret" \
        "secrets.GITHUB_TOKEN — GitHub's built-in token with repo-scoped permissions" \
        "The docker login command run manually before CI starts" \
        "C" 2 \
        "A is a critical security vulnerability — never hardcode credentials." \
        "B is risky — personal tokens have broader scope than needed." \
        "CORRECT — GITHUB_TOKEN is automatically provided by GitHub Actions with scoped permissions." \
        "D is wrong — CD runs unattended; there is no manual step."

    # Q5 - MC
    ask_mc \
        "How can you build a frontend and a backend in parallel in one GitHub Actions workflow?" \
        "Use two run: commands on the same step" \
        "Define two separate jobs — they run in parallel by default" \
        "Add parallel: true to the steps: block" \
        "Use two workflow files — one for frontend, one for backend" \
        "B" 2 \
        "A is wrong — run: executes sequentially within a step." \
        "CORRECT — two jobs (e.g. build-frontend: and build-backend:) run in parallel automatically." \
        "C is wrong — parallel: is not a valid GitHub Actions keyword." \
        "D would work but is unnecessarily complex; parallel jobs in one workflow is cleaner."

    # Q6 - MC: Docker Port Security
    ask_mc \
        "Your MySQL container is exposed via '3306:3306' on a cloud VM. Why is this BAD?" \
        "It makes the database slow" \
        "It prevents other containers from connecting" \
        "It binds to 0.0.0.0, making the DB accessible to the whole internet" \
        "It requires a special Docker license" \
        "C" 2 \
        "A is wrong — exposure doesn't affect raw performance." \
        "B is wrong — containers can still connect, but so can everyone else." \
        "CORRECT — on a cloud VM, '3306:3306' is public. Use '127.0.0.1:3306:3306' to restrict access." \
        "D is nonsense."

    # Q7 - MC: Package Management
    ask_mc \
        "What is the difference between 'apt update' and 'apt upgrade' on Ubuntu?" \
        "update installs apps; upgrade removes apps" \
        "update refreshes the package list; upgrade installs the latest versions" \
        "update is for kernel; upgrade is for user apps" \
        "They are the same thing" \
        "B" 2 \
        "A is wrong." \
        "CORRECT — update gets the 'menu' of what's available; upgrade actually installs the 'food'." \
        "C is wrong — kernel is just another package." \
        "D is wrong — they are two distinct steps."

    # Q8 - Typed: Monitoring
    ask_typed \
        "Which command is an interactive process monitor often used on Linux servers?" \
        "htop" 2 \
        "Think of a more colorful, interactive version of 'top'." \
        "htop" \
        "htop provides a real-time, interactive view of CPU, RAM, and processes."

    # Lab 1: Port Security
    lab_header "Docker Security" "Don't expose your DB to the world."
    do_task \
        "Edit 'compose.yaml' to bind port 3306 to '127.0.0.1' only." \
        "grep -q \"127.0.0.1:3306:3306\" compose.yaml" \
        5 \
        "127.0.0.1:3306:3306" \
        "Binding to 127.0.0.1 ensures only local processes (or SSH tunnels) can reach the port."

    # Lab 2: SSH Deploy
    lab_header "Cloud Deployment" "Automating the rollout."
    do_task \
        "Add a run command to 'deploy.yaml' that runs 'docker compose up -d' on a remote server via ssh." \
        "grep -q \"ssh.*docker compose up -d\" deploy.yaml" \
        5 \
        "ssh ubuntu@server 'docker compose up -d'" \
        "Deployment often involves SSH-ing into a target VM and running a container restart command."

    ZONE_SCORES+=($((SCORE - z_start)))
    ZONE_MAX+=(35)
    save_progress 7
}

# ─── SCORE / GRADE DISPLAY ─────────────────────────────────────────────────────
show_score() {
    section_header "SCORE & GRADE ESTIMATE"

    local pct=0
    if [[ $MAX_SCORE -gt 0 ]]; then
        pct=$(( (SCORE * 100) / MAX_SCORE ))
    fi

    printf "  ${BOLD}${W}Perfect Score : ${CYN}%d / %d${RST}\n" "$SCORE" "$MAX_SCORE"
    printf "  ${BOLD}${W}Accuracy      : ${YLW}%d%%${RST}\n" "$pct"
    echo
    printf "  ${GRN}Correct   : %d${RST}\n" "$CORRECT"
    printf "  ${YLW}Retried   : %d${RST}\n" "$RETRIED"
    printf "  ${RED}Wrong     : %d${RST}\n" "$WRONG"
    echo
    pbar "$SCORE" "$MAX_SCORE"

    # Zone breakdown
    if [[ ${#ZONE_SCORES[@]} -gt 0 ]]; then
        echo
        echo -e "  ${GRAY}Zone breakdown:${RST}"
        local zone_names=("CI/CD Concepts" "Jobs & Steps" "Triggers" "uses vs run" "Caching" "Hash-Pinning" "Maven & Docker")
        for i in "${!ZONE_SCORES[@]}"; do
            local zs=${ZONE_SCORES[$i]}
            local zm=${ZONE_MAX[$i]}
            local zp=0
            [[ $zm -gt 0 ]] && zp=$(( (zs * 100) / zm ))
            local bar=""
            local filled=$(( zp / 10 ))
            for ((j=0; j<filled; j++)); do bar+="█"; done
            for ((j=filled; j<10; j++)); do bar+="░"; done
            printf "  ${CYN}Zone %d${RST} %-15s ${GRAY}%s${RST} ${WHITE}%2d%%${RST}\n" \
                $((i+1)) "[${zone_names[$i]}]" "$bar" $zp
        done
        echo
    fi

    # Grade estimate (Danish 7-scale)
    echo -e "  ${WHITE}Grade estimate (Danish 7-trins skala):${NC}"
    echo
    if   [[ $pct -ge 90 ]]; then
        echo -e "  ${BOLD}${BG_GRN}  12  ${RST}${GRN} Excellent. Exam-ready.${RST}"
    elif [[ $pct -ge 77 ]]; then
        echo -e "  ${BOLD}${BG_GRN}  10  ${RST}${GRN} Very good. Minor gaps only.${RST}"
    elif [[ $pct -ge 63 ]]; then
        echo -e "  ${BOLD}${BG_YLW}   7  ${RST}${YLW} Good. A few areas need sharpening.${RST}"
    elif [[ $pct -ge 50 ]]; then
        echo -e "  ${BOLD}${BG_YLW}   4  ${RST}${YLW} Pass. Notable gaps — keep drilling.${RST}"
    elif [[ $pct -ge 37 ]]; then
        echo -e "  ${BOLD}${BG_RED}   2  ${RST}${RED} Minimum pass. Significant gaps.${RST}"
    else
        echo -e "  ${BOLD}${BG_RED}  -3  ${RST}${RED} Not ready. Restart from Zone 1.${RST}"
    fi

    echo
    echo -e "  ${DIM}Tip: Aim for 77%+ (10 or 12) before your exam date.${RST}"
    echo
}

# ══════════════════════════════════════════════════════════════════════════════
# QUICK REFERENCE (shown before/after sessions)
# ══════════════════════════════════════════════════════════════════════════════
quick_ref() {
    section_header "QUICK REFERENCE — CI/CD Cheat Sheet"
    echo -e "${MAGENTA}STRUCTURE${NC}"
    echo -e "  Workflow (.yaml) → ${CYAN}jobs:${NC} → ${CYAN}steps:${NC}"
    echo -e "  Jobs: ${YELLOW}parallel${NC} by default (separate runners)"
    echo -e "  Steps: ${YELLOW}sequential${NC} within a job (same runner)"
    echo -e "  ${CYAN}needs: [job-name]${NC}  → make a job wait for another"
    echo
    echo -e "${MAGENTA}STEP KEYWORDS${NC}"
    echo -e "  ${GREEN}uses:${NC}  call a pre-built action   e.g. uses: actions/checkout@v4"
    echo -e "  ${GREEN}run:${NC}   execute shell command     e.g. run: mvn test"
    echo
    echo -e "${MAGENTA}TRIGGERS${NC}"
    echo -e "  ${CYAN}push:${NC}              on push to branch"
    echo -e "  ${CYAN}pull_request:${NC}      on PR to branch"
    echo -e "  ${CYAN}workflow_dispatch:${NC} manual button in GitHub UI"
    echo
    echo -e "${MAGENTA}CACHING${NC}"
    echo -e "  ${CYAN}uses: actions/cache@v4${NC}"
    echo -e "  ${YELLOW}path:${NC}  ~/.m2/repository  (where Maven stores deps)"
    echo -e "  ${YELLOW}key:${NC}   maven-\${{ hashFiles('**/pom.xml') }}"
    echo -e "  Cache busts when pom.xml changes → re-downloads all deps"
    echo
    echo -e "${MAGENTA}HASH-PINNING${NC}"
    echo -e "  Problem:  git tags are mutable → supply-chain attack risk"
    echo -e "  Solution: pin to commit SHA"
    echo -e "  ${CYAN}uses: actions/setup-java@2dfa2011c5b2a0f1...  # v4.3.0${NC}"
    echo -e "  Benefits: ${GREEN}Reproducibility${NC} + ${GREEN}Security${NC}"
    echo
    echo -e "${MAGENTA}MAVEN IN CI${NC}"
    echo -e "  ${YELLOW}mvn test${NC}          compile + run tests  ← core CI step"
    echo -e "  ${YELLOW}mvn package${NC}        build JAR/WAR artifact"
    echo -e "  ${YELLOW}mvn verify${NC}         integration tests"
    echo -e "  ${YELLOW}mvn package -DskipTests${NC}  package without re-running tests"
    echo
    echo -e "${MAGENTA}DOCKER IN CD${NC}"
    echo -e "  Build image:    ${CYAN}docker build -t myapp:latest .${NC}"
    echo -e "  Push to GHCR:   ${CYAN}uses: docker/build-push-action@...${NC}"
    echo -e "  Auth token:     ${CYAN}secrets.GITHUB_TOKEN${NC} (built-in, scoped)"
    echo
}

# ─── MAIN ENTRYPOINT ──────────────────────────────────────────────────────────
main() {
    # CLI flags
    case "${1:-}" in
        --help|-h)
            echo "Usage: bash pipemaster.sh [--zone N] [--ref] [--score]"
            echo "  --zone N   Jump to zone N (1-7)"
            echo "  --ref      Show quick reference cheat sheet"
            echo "  --all      Run all zones"
            echo "  --score    Show current score"
            exit 0
            ;;
        --ref)   show_header; quick_ref; exit 0 ;;
        --all)   show_header; for z in 1 2 3 4 5 6 7; do zone$z; press_enter; done; show_score; exit 0 ;;
        --score) show_score; exit 0 ;;
        --zone)
            show_header
            [[ -n "${2:-}" ]] && zone$2 && show_score && exit 0
            ;;
    esac

    show_header
    
    printf "  ${W}Your name: ${RST}"
    read -r PLAYER_NAME
    [[ -z "$PLAYER_NAME" ]] && PLAYER_NAME="Learner"
    
    load_progress

    while true; do
        show_menu
        read -rn1 choice
        echo
        case "$choice" in
            "") # ENTER pressed
                for z in 1 2 3 4 5 6 7; do
                    zone$z
                    press_enter
                done
                show_score
                ;;
            1) zone1 ;;
            2) zone2 ;;
            3) zone3 ;;
            4) zone4 ;;
            5) zone5 ;;
            6) zone6 ;;
            7) zone7 ;;
            9) show_score ;;
            0)
                echo
                printf "  ${CYN}Final score: %d / %d${RST}\n" "$SCORE" "$MAX_SCORE"
                show_score
                printf "  ${GRAY}Good luck at the exam, %s! 🚀${RST}\n" "$PLAYER_NAME"
                exit 0
                ;;
            r|R) show_header; quick_ref ;;
            *)
                echo -e "  ${RED}Invalid choice.${RST}"
                ;;
        esac
        press_enter
    done
}

main "$@"
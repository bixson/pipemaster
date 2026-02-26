<div align="center">

```
 /$$$$$$$  /$$$$$$ /$$$$$$$  /$$$$$$$$ /$$      /$$  /$$$$$$   /$$$$$$  /$$$$$$$$ /$$$$$$$$ /$$$$$$$
| $$__  $$|_  $$_/| $$__  $$| $$_____/| $$$    /$$$ /$$__  $$ /$$__  $$|__  $$__/| $$_____/| $$__  $$
| $$  \ $$  | $$  | $$  \ $$| $$      | $$$$  /$$$$| $$  \ $$| $$  \__/   | $$   | $$      | $$  \ $$
| $$$$$$$/  | $$  | $$$$$$$/| $$$$$   | $$ $$/$$ $$| $$$$$$$$|  $$$$$$    | $$   | $$$$$   | $$$$$$$/
| $$____/   | $$  | $$____/ | $$__/   | $$  $$$| $$| $$__  $$ \____  $$   | $$   | $$__/   | $$__  $$
| $$        | $$  | $$      | $$      | $$\  $ | $$| $$  | $$ /$$  \ $$   | $$   | $$      | $$  \ $$
| $$       /$$$$$$| $$      | $$$$$$$$| $$ \/  | $$| $$  | $$|  $$$$$$/   | $$   | $$$$$$$$| $$  | $$
|__/      |______/|__/      |________/|__/     |__/|__/  |__/ \______/    |__/   |________/|__/  |__/
```

**Master CI/CD and GitHub Actions. One zone at a time.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash%204.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Git%20Bash-blue.svg)](#requirements)

</div>

---

**pipemaster** is a fully interactive terminal trainer designed specifically for the **KEA Datamatiker Technology Exam**. It covers CI/CD fundamentals, GitHub Actions workflow structure, triggers, caching, security, and Maven/Docker integration.

No installation. No dependencies. Just bash.

---

## Quick Start

```bash
# Option 1: clone and run
git clone https://github.com/bixson/pipemaster.git
cd pipemaster
bash pipemaster.sh

# Option 2: run directly (curl)
bash <(curl -fsSL https://raw.githubusercontent.com/bixson/pipemaster/master/pipemaster.sh)
```

---

## What You Train

| Zone | Topic | Key Concepts | Lab |
|------|-------|--------------|-----|
| 1 | **CI/CD Concepts** | Pipelines, IaaS vs PaaS, SSH Keys | |
| 2 | **Jobs & Steps** | Hierarchy, Parallelism, Dependencies (`needs:`) | ✓ |
| 3 | **Triggers** | `push`, `pull_request`, `workflow_dispatch` | |
| 4 | **uses: vs run:** | Reusable Actions vs Shell Commands | ✓ |
| 5 | **Caching** | `actions/cache`, `hashFiles`, Cache Invalidation | ✓ |
| 6 | **Security** | Hash-pinning (SHAs), Permissions, `ss -tulnp` | ✓ |
| 7 | **Maven & Docker** | `mvn test`, `package`, `secrets.GITHUB_TOKEN` | ✓ |

---

## How It Works

pipemaster mixes **theory questions** and **real-world lab tasks** — you edit files in a sandbox environment and the script verifies them instantly.

### When you get something wrong, it actually helps you

**Multiple choice** — tells you *why your specific pick was wrong*, then reveals the answer:
```
  WRONG    v4 is a git tag that can be deleted and recreated to point to malicious code.
  -> Correct answer: C) uses: actions/setup-java@2dfa2011c5b2a0f... # v4.3.0

  +--[ TEACHING MOMENT ]--------------------------------------+
  |  A git tag is mutable. A malicious actor can move the tag |
  |  to different code. SHAs are cryptographically unique.    |
  +-----------------------------------------------------------+
```

**Typed answers** — a directional hint, then one retry for half points:
```
  Not quite.  Hint: Think of the greenhouse gas emissions.

  [RETRY] One more try for half points >
```

**Practical lab tasks** — reveals the exact solution on failure:
```
  [x] Verification failed.

  Solution:
    needs: [test]

  Why: The 'needs' keyword creates a dependency. 
       Without it, deploy would run in parallel!

  Make the fix now, then press ENTER for half points:
```

---

## Scoring & Grade Estimate

Designed to match the **Danish 7-trins skala** used in KEA exams.

| Score | Grade | Performance |
|-------|-------|-------------|
| 90%+  | **12** | Excellent. Exam-ready. |
| 77%+  | **10** | Very good. Minor gaps only. |
| 63%+  | **7**  | Good. A few areas need sharpening. |
| 50%+  | **4**  | Pass. Notable gaps — keep drilling. |
| 37%+  | **2**  | Minimum pass. Significant gaps. |
| <37%  | **-3** | Not ready. Restart from Zone 1. |

---

## CLI Options

```bash
bash pipemaster.sh               # full game (all 7 zones)
bash pipemaster.sh --zone 5      # jump straight to Zone 5 (Caching)
bash pipemaster.sh --ref         # show quick reference cheat sheet
bash pipemaster.sh --score       # show current score/grade
bash pipemaster.sh --all         # run all zones non-interactively
```

---

## Requirements

| Platform | Requirement |
|----------|-------------|
| **macOS** | Terminal.app or iTerm2, bash 3.2+ |
| **Linux** | Any terminal emulator, bash 4.0+ |
| **Windows** | Git Bash (included with Git for Windows) |

No external packages needed. The game creates a sandbox at `~/.pipemaster/lab/` where you perform real file edits.

---

## Contributing

Contributions are welcome — new questions, better lab checks, or additional zones.

1. Fork the repo
2. Create a branch: `git checkout -b fix/typo-zone5`
3. Open a PR with a short description

---

## License

MIT

---

<div align="center">


If this helped you — consider leaving a star.

</div>

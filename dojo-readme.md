<div align="center">

```
 ____   ___      _  ___    __  __    _    ____ _____ _____ ____  
|  _ \ / _ \    | |/ _ \  |  \/  |  / \  / ___|_   _| ____|  _ \ 
| | | | | | |_  | | | | | | |\/| | / _ \ \___ \ | | |  _| | |_) |
| |_| | |_| | |_| | |_| | | |  | |/ ___ \ ___) || | | |___|  _ < 
|____/ \___/ \___/ \___/  |_|  |_/_/   \_\____/ |_| |_____|_| \_\
```

**Master the Linux terminal. One zone at a time.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash%204.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Git%20Bash-blue.svg)](#requirements)

</div>

---

**dojomaster** is a fully interactive terminal game that trains you on the core Linux command-line skill set — the kind that comes up in job interviews, cloud deployments, and university exams.

No installation. No dependencies. Just bash.

---

## Quick Start

```bash
# Option 1: clone and run
git clone https://github.com/bixson/dojomaster.git
cd dojomaster
bash dojomaster.sh

# Option 2: run directly (curl)
bash <(curl -fsSL https://raw.githubusercontent.com/bixson/dojomaster/master/dojomaster.sh)
```

---

## What You Train

| Zone | Topic | Commands |
|------|-------|----------|
| 1 | **Navigation** | `cd` `ls` `pwd` `mkdir -p` |
| 2 | **File Operations** | `touch` `cp -r` `mv` `echo` `>` `>>` |
| 3 | **Text Search** | `cat` `head` `tail -f` `grep -r` `grep -i` |
| 4 | **Pipes & Redirection** | `\|` `>` `>>` `<` `wc -l` |
| 5 | **Permissions** | `chmod` `chown -R` `ls -l` octal notation |
| 6 | **Processes** | `ps ax` `kill -9` `top` `htop` `pgrep` |
| 7 | **SSH & Remote** | `ssh -i` `scp` `authorized_keys` public key auth |

---

## How It Works

dojomaster mixes **theory questions** and **real shell tasks** — you run actual commands in a second terminal while the game verifies the results.

### When you get something wrong, it actually helps you

Most quiz tools just show the correct answer and move on. dojomaster does three things instead:

**Multiple choice** — tells you *why your specific pick was wrong*, not just what the right answer is:
```
  WRONG    cp COPIES -- the original stays at /tmp. You would need rm to remove it.
  -> Correct answer: B) mv /tmp/data.txt /var/data.txt

  +--[ TEACHING MOMENT ]--------------------------------------+
  |  mv = move. cp = copy (original stays). rm = remove.     |
  |  mv handles both moving AND renaming in one command.      |
  +-----------------------------------------------------------+
  [TIP] mv = Move. cp = Copy. mv removes the source automatically.
```

**Typed answers** — a directional hint, then one retry for half points:
```
  Not quite.  [Try: Use echo to produce text, then redirect it into the file]

  [RETRY] One more try for half points >
```

**Practical tasks** — reveals the exact command to run, then lets you retry for half points:
```
  [X] Check failed. Here is the command:

    Command:  grep ERROR logs/server.log > reports/errors.txt
    Why: grep filters matching lines, > saves them to a new file.

  Run that now, then press ENTER for half points:
```

---

## Scoring

| Score | Grade |
|-------|-------|
| 90%+  | **12** — Outstanding |
| 75%+  | **10** — Excellent |
| 55%+  | **7**  — Good pass |
| 35%+  | **4**  — Passing |
| <35%  | **02** — Try again |

---

## CLI Options

```
bash dojomaster.sh               # full game (all 7 zones)
bash dojomaster.sh --zone 5      # jump straight to zone 5
bash dojomaster.sh --list        # list all zones with topics
bash dojomaster.sh --help        # show help
bash dojomaster.sh --version     # show version
```

---

## Requirements

| Platform | Requirement |
|----------|-------------|
| **macOS** | Terminal.app or iTerm2, bash 3.2+ |
| **Linux** | Any terminal emulator, bash 4.0+ |
| **Windows** | Git Bash (included with Git for Windows) |

No external packages needed. The game creates a sandbox at `~/.linux-dojo/` with real files you interact with.

---

## What You Practise (Detail)

<details>
<summary>Zone 1 — Navigation</summary>

- Difference between terminal, shell, and command
- `cd ..` vs `cd .` vs `cd /`
- `pwd` — print working directory
- `ls -la` — list all files including hidden with details
- `mkdir -p` — create nested directories in one command

</details>

<details>
<summary>Zone 2 — File Operations</summary>

- `touch` — create empty files / update timestamps
- `cp` vs `mv` vs `rm`
- `cp -r` — recursive directory copy
- `echo text > file` vs `echo text >> file` — overwrite vs append
- The most common Linux mistake: using `>` when you meant `>>`

</details>

<details>
<summary>Zone 3 — Text Search</summary>

- `cat`, `head`, `tail` — read files
- `tail -f` — live log monitoring
- `grep PATTERN FILE` — filter lines
- `grep -i` — case insensitive
- `grep -r` — recursive search in directories
- Saving grep output to a file

</details>

<details>
<summary>Zone 4 — Pipes & Redirection</summary>

- `|` — connecting commands (plumbing)
- `>` overwrite vs `>>` append
- `<` — redirecting file as stdin
- `wc -l` — counting lines
- `ls | wc -l` vs `ls -a | wc -l` — the `. and ..` gotcha
- Multi-stage pipelines: `grep | wc -l`

</details>

<details>
<summary>Zone 5 — Permissions</summary>

- Reading `ls -l` output: `-rwxr-xr--`
- Octal notation: `r=4`, `w=2`, `x=1`
- `chmod 755`, `644`, `600`, `700` — what each means
- `chown user:group` — change ownership
- `chown -R` — recursive ownership change
- SSH security requirements: `700` for `.ssh`, `600` for keys

</details>

<details>
<summary>Zone 6 — Processes</summary>

- `ps` vs `ps ax` vs `ps aux` vs `ps faux`
- Finding a process: `ps ax | grep nginx`
- The grep-shows-itself trap (subtract 1)
- PID — what it is and why you need it
- `kill PID` vs `kill -9 PID` — polite vs force
- `top` / `htop` for live monitoring

</details>

<details>
<summary>Zone 7 — SSH & Remote Access</summary>

- What SSH is and how it works
- Public key authentication — how the challenge-response works
- `ssh user@host`
- `ssh -i keyfile user@host`
- Where public keys live on the server: `~/.ssh/authorized_keys`
- `scp` — upload and download files securely
- Required file permissions for SSH to accept keys

</details>

---

## Contributing

Contributions are welcome — new zones, corrections, or better question explanations.

1. Fork the repo
2. Create a branch: `git checkout -b zone/docker` or `git checkout -b fix/typo-zone3`
3. Make your changes
4. Open a PR with a short description

---

## Roadmap

- [ ] `--quick` mode: theory questions only, no practical tasks
- [ ] `--drill` mode: rapid-fire questions with no explanations
- [ ] Zone 8: Package Management (`apt`, `systemctl`, `journalctl`)
- [ ] Zone 9: Shell Scripting basics
- [ ] Score history: track improvement over multiple runs
- [ ] Multiplayer: compare scores with your team

---

## License

MIT

---

<div align="center">

Made for anyone learning Linux from the command line.

If this helped you — consider leaving a star.

</div>

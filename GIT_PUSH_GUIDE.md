# Git Push Guide — UVM Projects

**Remote:** `git@github.com:ramyasridharma94-hash/UVM_Projects.git`  
**Branch:** `master`  
**Local path:** `/home/radharma/Documents/UVM_Projects/UVM_projects`

---

## One-Time Setup (Already Done)

These steps were already completed. Do NOT repeat them.

```bash
# 1. Navigate to project root
cd /home/radharma/Documents/UVM_Projects/UVM_projects

# 2. Initialize git repo
git init

# 3. Set local identity
git config user.name "ramyasridharma94-hash"
git config user.email "ramyasridharma94@users.noreply.github.com"

# 4. Stage all files
git add .

# 5. Create first commit
git commit -m "Initial commit"

# 6. Add remote
git remote add origin git@github.com:ramyasridharma94-hash/UVM_Projects.git

# 7. Push and track remote branch
git push -u origin master
```

---

## Everyday Push Workflow

Use these commands every time you want to push new or changed files.

### Step 1 — Go to the project directory

```bash
cd /home/radharma/Documents/UVM_Projects/UVM_projects
```

### Step 2 — Check what changed

```bash
git status
```

Sample output:
```
On branch master
Changes not staged for commit:
  modified:   protocols/axi4/rtl/axi4_slave.sv

Untracked files:
  protocols/axi5/
```

### Step 3 — Stage your changes

**Option A — Stage everything (all new and modified files):**
```bash
git add .
```

**Option B — Stage a specific file:**
```bash
git add protocols/axi4/rtl/axi4_slave.sv
```

**Option C — Stage a specific folder:**
```bash
git add protocols/axi5/
```

**Option D — Stage only modified files, skip untracked:**
```bash
git add -u
```

### Step 4 — Verify what is staged

```bash
git diff --cached --stat
```

Sample output:
```
 protocols/axi4/rtl/axi4_slave.sv | 12 ++++++------
 protocols/axi5/rtl/axi5_slave.sv | 95 ++++++++++++++++++++++++++++++
 2 files changed, 101 insertions(+), 6 deletions(-)
```

### Step 5 — Commit with a message

```bash
git commit -m "Brief description of what you changed"
```

Good commit message examples:
```bash
git commit -m "Fix AXI4 burst counter rollover in axi4_slave"
git commit -m "Add PCIe UVM protocol project"
git commit -m "Update AHB driver to support WRAP4 burst"
git commit -m "Add UART parity coverage to uart_coverage.sv"
```

### Step 6 — Push to GitHub

```bash
git push
```

Or explicitly:
```bash
git push origin master
```

Sample output:
```
Enumerating objects: 7, done.
Counting objects: 100% (7/7), done.
Delta compression using up to 8 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 1.23 KiB | 1.23 MiB/s, done.
Total 4 (delta 2), reused 0 (delta 0), pack-reused 0
To github.com:ramyasridharma94-hash/UVM_Projects.git
   c8dc21a..f9a3b12  master -> master
```

---

## Full Sequence — Copy-Paste Block

```bash
cd /home/radharma/Documents/UVM_Projects/UVM_projects
git status
git add .
git diff --cached --stat
git commit -m "Your commit message here"
git push
```

---

## Scenario: Adding a New Protocol Project

```bash
# 1. Go to project root
cd /home/radharma/Documents/UVM_Projects/UVM_projects

# 2. Create new project folders (example: PCIe)
mkdir -p protocols/pcie/{rtl,tb/{interface,agent,sequences,env,tests,top},sim}

# 3. Write your .sv files into those folders
# ... edit files ...

# 4. Check what git sees
git status

# 5. Stage the new project
git add protocols/pcie/

# 6. Confirm staged files
git diff --cached --stat

# 7. Commit
git commit -m "Add PCIe UVM protocol project with driver and basic tests"

# 8. Push
git push
```

---

## Scenario: Modifying an Existing File

```bash
cd /home/radharma/Documents/UVM_Projects/UVM_projects

# Edit the file (e.g., fix a bug in APB driver)
# ... make changes to protocols/apb/tb/agent/apb_driver.sv ...

# Check the diff before staging
git diff protocols/apb/tb/agent/apb_driver.sv

# Stage just that file
git add protocols/apb/tb/agent/apb_driver.sv

# Commit
git commit -m "Fix APB driver: PENABLE must be deasserted before next SETUP phase"

# Push
git push
```

---

## Scenario: Deleting a File

```bash
cd /home/radharma/Documents/UVM_Projects/UVM_projects

# Remove the file and tell git about it
git rm protocols/apb/tb/tests/apb_old_test.sv

# Or if you already deleted it manually
git add -u

# Commit
git commit -m "Remove obsolete apb_old_test"

# Push
git push
```

---

## Scenario: Adding a New Bridge Project

```bash
cd /home/radharma/Documents/UVM_Projects/UVM_projects

mkdir -p bridges/axi_to_pcie/{rtl,tb/{interface,master_agent,slave_agent,sequences,env,tests,top},sim}

# ... write files ...

git add bridges/axi_to_pcie/
git commit -m "Add AXI-to-PCIe bridge UVM project"
git push
```

---

## Useful Diagnostic Commands

```bash
# See all commits (history)
git log --oneline

# See what files changed in last commit
git show --stat HEAD

# See the full diff of last commit
git show HEAD

# Check remote is correctly set
git remote -v

# Check local vs remote status
git status

# See unpushed commits
git log origin/master..HEAD --oneline

# Undo last commit (keeps file changes)
git reset HEAD~1

# Undo staged files (un-stage without losing edits)
git restore --staged .
```

---

## Verify Push Succeeded

After `git push`, verify on GitHub:

```
https://github.com/ramyasridharma94-hash/UVM_Projects
```

Or from the terminal:
```bash
git log origin/master --oneline -5
```

If local and remote show the same latest commit hash, the push was successful.

---

## SSH Troubleshooting

```bash
# Test SSH connection
ssh -T git@github.com
# Expected: Hi ramyasridharma94-hash! You've successfully authenticated...

# Check your SSH key
ls ~/.ssh/
# Should see: id_ed25519  id_ed25519.pub  known_hosts

# If SSH fails, add key to agent
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_ed25519
```

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Go to project | `cd /home/radharma/Documents/UVM_Projects/UVM_projects` |
| Check changes | `git status` |
| Stage all | `git add .` |
| Stage one file | `git add <filepath>` |
| Stage one folder | `git add <folder>/` |
| Review staged | `git diff --cached --stat` |
| Commit | `git commit -m "message"` |
| Push | `git push` |
| View history | `git log --oneline` |
| Verify on remote | `git log origin/master --oneline -5` |
| Test SSH auth | `ssh -T git@github.com` |

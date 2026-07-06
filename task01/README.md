# Task 01 — Kubernetes Node Provisioning

Provision a **production-ready Kubernetes worker node** on **Ubuntu 24.04 LTS** that is
ready to `kubeadm join` an existing cluster.

Automation tool: **Ansible** (declarative + idempotent — safe to re-run), with a
standalone **Bash validation script** for post-provision verification.

---

## What this does

| Area | Delivered by | Summary |
|------|--------------|---------|
| Base system & CLI tooling | `roles/base` | Hostname, DNS (systemd-resolved), timezone, NTP, common production CLI tools |
| Sysadmin accounts | `roles/sysadmins` | Users with **auto-generated passwords**, `sudo`, SSH keys, forced password rotation |
| Command audit logging | `roles/audit` | Every command run by any user is captured to a **dedicated log file** (`/var/log/commands.log`) via Snoopy → rsyslog, plus `auditd` for privilege events |
| Kernel prep | `roles/kernel` | Swap **disabled** (runtime + `fstab` + zram), required modules loaded, k8s sysctl params |
| Container runtime | `roles/containerd` | `containerd` with **systemd cgroup driver**, pinned **pause image**, and production hardening in `config.toml` |
| Kubernetes packages | `roles/kubernetes` | `kubelet`, `kubeadm`, `kubectl` pinned + held; node ready to join |
| Validation | `scripts/validate.sh` | Verifies every kernel parameter & prerequisite; **exits non-zero** and reports each failed check |

---

## Layout

```
task01/
├── ansible.cfg
├── site.yml                     # main playbook
├── Makefile                     # convenience wrapper
├── group_vars/all.yml           # tunables (versions, users, tools)
├── inventory/hosts.ini.example  # copy to hosts.ini and edit
├── roles/
│   ├── base/                    # hostname, DNS, CLI tools
│   ├── sysadmins/               # accounts + generated passwords
│   ├── audit/                   # per-command audit logging
│   ├── kernel/                  # swap off, modules, sysctl
│   ├── containerd/              # container runtime
│   └── kubernetes/              # kubelet/kubeadm/kubectl
└── scripts/
    └── validate.sh              # post-provision validation
```

---

## Usage

### 1. Prerequisites (control node)

```bash
sudo apt-get update && sudo apt-get install -y ansible
ansible --version   # >= 2.14
```

### 2. Configure inventory

```bash
cd task01
cp inventory/hosts.ini.example inventory/hosts.ini
$EDITOR inventory/hosts.ini      # set target host + ansible_user
$EDITOR group_vars/all.yml       # set k8s version, hostname, sysadmins, SSH keys
```

### 3. Provision

Remote target(s):

```bash
make provision                   # or: ansible-playbook -i inventory/hosts.ini site.yml
```

Provision the local machine (the node itself):

```bash
make provision-local             # ansible-playbook -i localhost, -c local site.yml
```

Dry-run (no changes, shows diff):

```bash
make check
```

### 4. Validate

The playbook copies `scripts/validate.sh` to `/usr/local/sbin/k8s-node-validate`.

```bash
sudo k8s-node-validate           # exits 0 if all checks pass, non-zero otherwise
```

### Testing

See **[TESTING.md](TESTING.md)** for how to test on a real VM (Vagrant / Multipass),
or via Molecule. Do not test in a Docker container.

### 5. Join the cluster

On an existing control-plane node:

```bash
kubeadm token create --print-join-command
```

Run the printed `kubeadm join ...` on the provisioned node.

---

## Generated credentials

Auto-generated sysadmin passwords are written **locally on the control node** to
`task01/secrets/<user>.password` (mode `0600`) at provision time. They are shown once in
the play recap summary. Accounts are created with password change forced on first login.

> `secrets/` is git-ignored. Distribute passwords out-of-band and rotate after first login.
> For fully key-based access set `sysadmins[*].password_login: false` in `group_vars/all.yml`.

---

## Design decisions

- **Ansible over Bash** for the provisioner: idempotent, re-runnable, auditable, and the
  handlers give correct "reload only on change" semantics for sysctl/containerd/rsyslog.
- **Bash for validation**: zero-dependency, runs directly on the node, easy to wire into
  CI or a readiness gate.
- **Snoopy for command auditing**: produces a single, human-readable, dedicated log of
  every `execve` (user, uid, tty, cwd, command) — exactly the "dedicated file" requirement.
  `auditd` is added alongside for tamper-resistant privilege/identity events.
- **containerd from the official Docker apt repo**: newer and better maintained than the
  distro package; `SystemdCgroup = true` to match the kubelet's default cgroup driver.
- **Pinned versions**: Kubernetes minor version and pause image are pinned and `apt-mark
  hold`ed so an unattended `apt upgrade` can't break the node.

## Idempotency & safety

- Re-running the playbook is safe; changed handlers only fire on real changes.
- `apt-mark hold` prevents accidental kubelet/containerd upgrades.
- Swap is disabled at three layers (runtime, `fstab`, zram-generator) so it stays off across reboots.

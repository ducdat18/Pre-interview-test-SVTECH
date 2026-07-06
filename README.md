# SVTECH — SRE Pre-Interview Test

Submission by **ducdat18**.

| Task | Deliverable | Location | Status |
|------|-------------|----------|--------|
| **01 — Kubernetes Node Provisioning** | Ansible provisioner + Bash validation for an Ubuntu 24.04 worker node | [`task01/`](task01/) | ✅ Done — tested on Ubuntu 24.04 |
| **02 — Observability: Log Management** | System architecture diagram (PNG) for 1,000–2,000 endpoints | [`task02/`](task02/) | 🖼️ Diagram |
| **03 — Incident Scenarios** | Selected answers + reasoning for three scenarios | [`task03/`](task03/) | ✅ Done |

---

## Task 01 — Kubernetes Node Provisioning

Idempotent **Ansible** project that turns a fresh Ubuntu 24.04 host into a
production-ready Kubernetes worker, ready to `kubeadm join`. Covers sysadmin
accounts (auto-generated passwords + sudo), hostname/DNS, per-command audit
logging, swap disable, kernel modules/sysctls, `containerd` (systemd cgroup +
pinned pause image), and `kubelet/kubeadm/kubectl`. Ships a standalone
validation script and Vagrant / Molecule test harnesses.

See [`task01/README.md`](task01/README.md) and [`task01/TESTING.md`](task01/TESTING.md).

> Tested on a fresh Ubuntu 24.04 VM — the validation script passes all checks.

## Task 02 — Observability Design

Centralized log management architecture for 1,000–2,000 mixed endpoints
(servers, network devices, applications): collection/transport, parsing /
normalization / enrichment, and storage / retention / archival. Diagram in
[`task02/`](task02/).

## Task 03 — Incident Scenarios

First-response choices and reasoning for three production incident scenarios.
See [`task03/answers.md`](task03/answers.md).

---

## Repository layout

```
.
├── task01/   # Ansible provisioner, validation script, tests
├── task02/   # Log-management architecture diagram (PNG)
└── task03/   # Incident scenario answers
```

# Testing the Kubernetes node provisioning

> ⚠️ Test on a **real VM or cloud instance**, not a Docker container.
> Containers can't toggle swap, load `br_netfilter`/`overlay`, or run systemd
> faithfully — the result would be meaningless. WSL2 is also not representative.

There are three ways to test, from quick to CI-grade.

---

## 1. Vagrant — one command, real VM (best for local Windows)

Requires **VirtualBox + Vagrant** on the host. No Ansible needed on the host —
`ansible_local` installs and runs it inside the guest.

```bash
cd task01
vagrant up            # create VM + run site.yml + run validate.sh (fails if not ready)
vagrant provision     # re-run → proves idempotency (no unexpected changes)
vagrant ssh -c 'sudo k8s-node-validate'
vagrant destroy -f
```

Pass = `validate.sh` prints `All checks passed` and `vagrant up` finishes green.

---

## 2. Multipass — manual VM (lightweight)

```powershell
winget install Canonical.Multipass
multipass launch 24.04 --name k8s-node --cpus 2 --memory 4G --disk 20G
multipass transfer -r .\task01 k8s-node:/home/ubuntu/task01
multipass shell k8s-node
```
Inside the VM:
```bash
sudo apt-get update && sudo apt-get install -y ansible
cd task01
ansible-galaxy collection install -r requirements.yml
sudo ansible-playbook -i localhost, -c local site.yml -e target=all
sudo k8s-node-validate            # expect exit 0
```

---

## 3. Molecule — CI-grade (converge → idempotence → verify)

Requires **VirtualBox + Vagrant** and:
```bash
pip install molecule "molecule-plugins[vagrant]" ansible
```
Run:
```bash
cd task01
molecule test        # full cycle incl. an automatic idempotence assertion
molecule converge    # provision only, keep VM for inspection
molecule verify      # run validate.sh against the VM
molecule destroy
```

---

## What "pass" means

1. `ansible-playbook` completes with no failed tasks.
2. A second run reports `changed=0` for the settled tasks (idempotent).
3. `k8s-node-validate` exits `0` with `All checks passed`.
4. `kubeadm join …` (token from a control-plane) successfully registers the node.

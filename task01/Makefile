SHELL := /bin/bash
PLAYBOOK := site.yml
INVENTORY := inventory/hosts.ini

.PHONY: help provision provision-local check lint validate clean

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

provision:  ## Provision remote node(s) from inventory
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK)

provision-local:  ## Provision the local machine (run on the node itself)
	ansible-playbook -i localhost, -c local $(PLAYBOOK)

check:  ## Dry-run with diff (no changes applied)
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --check --diff

lint:  ## Lint the playbook (requires ansible-lint)
	ansible-lint $(PLAYBOOK) || true
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --syntax-check

validate:  ## Run the validation script locally
	sudo bash scripts/validate.sh

clean:  ## Remove locally generated secrets
	rm -rf secrets/

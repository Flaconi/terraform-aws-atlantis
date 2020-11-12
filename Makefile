ifneq (,)
.error This Makefile requires GNU Make.
endif

.PHONY: changelog release lint lint-files terraform-fmt _pull-tf _pull-fl 
CURRENT_DIR = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# -------------------------------------------------------------------------------------------------
# Docker image versions
# -------------------------------------------------------------------------------------------------
TF_VERSION     = 0.12.29
FL_VERSION     = 0.3
YL_VERSION     = 1.20

FL_IGNORES = .git/,.github/,*/.terraform/,.idea/,.chglog/


# -------------------------------------------------------------------------------------------------
# Read-only Targets
# -------------------------------------------------------------------------------------------------

lint:
	@$(MAKE) --no-print-directory terraform-fmt-tf _WRITE=false
	@$(MAKE) --no-print-directory lint-files

lint-files: _pull-fl
	@echo "################################################################################"
	@echo "# file-lint"
	@echo "################################################################################"
	@docker run --rm $$(tty -s && echo "-it" || echo) -v $(CURRENT_DIR):/data cytopia/file-lint:$(FL_VERSION) file-cr --text --ignore '$(FL_IGNORES)' --path .
	@docker run --rm $$(tty -s && echo "-it" || echo) -v $(CURRENT_DIR):/data cytopia/file-lint:$(FL_VERSION) file-crlf --text --ignore '$(FL_IGNORES)' --path .
	@docker run --rm $$(tty -s && echo "-it" || echo) -v $(CURRENT_DIR):/data cytopia/file-lint:$(FL_VERSION) file-trailing-single-newline --text --ignore '$(FL_IGNORES)' --path .
	@docker run --rm $$(tty -s && echo "-it" || echo) -v $(CURRENT_DIR):/data cytopia/file-lint:$(FL_VERSION) file-trailing-space --text --ignore '$(FL_IGNORES)' --path .
	@docker run --rm $$(tty -s && echo "-it" || echo) -v $(CURRENT_DIR):/data cytopia/file-lint:$(FL_VERSION) file-utf8 --text --ignore '$(FL_IGNORES)' --path .
	@docker run --rm $$(tty -s && echo "-it" || echo) -v $(CURRENT_DIR):/data cytopia/file-lint:$(FL_VERSION) file-utf8-bom --text --ignore '$(FL_IGNORES)' --path .


terraform-fmt:
	@$(MAKE) --no-print-directory terraform-fmt-tf _WRITE=true

terraform-fmt-tf: _WRITE=true
terraform-fmt-tf: _pull-tf
	@# Lint all Terraform files
	@echo "################################################################################"
	@echo "# Terraform fmt"
	@echo "################################################################################"
	@echo
	@echo "------------------------------------------------------------"
	@echo "# *.tf files"
	@echo "------------------------------------------------------------"
	@if docker run $$(tty -s && echo "-it" || echo) --rm \
		-v "$(PWD):/data" hashicorp/terraform:$(TF_VERSION) fmt \
			$$(test "$(_WRITE)" = "false" && echo "-check" || echo "-write=true") \
			-diff \
			-list=true \
			-recursive \
			/data; then \
		echo "OK"; \
	else \
		echo "Failed"; \
		exit 1; \
	fi;
	@echo
	@echo "------------------------------------------------------------"
	@echo "# *.tfvars files"
	@echo "------------------------------------------------------------"
	@if docker run $$(tty -s && echo "-it" || echo) --rm --entrypoint=/bin/sh \
		-v "$(PWD):/data" hashicorp/terraform:$(TF_VERSION) \
		-c "find . -not \( -path './*/.terragrunt-cache/*' -o -path './*/.terraform/*' \) \
			-name '*.tfvars' -type f -print0 \
			| xargs -0 -n1 terraform fmt \
				$$(test '$(_WRITE)' = 'false' && echo '-check' || echo '-write=true') \
				-diff \
				-list=true"; then \
		echo "OK"; \
	else \
		echo "Failed"; \
		exit 1; \
	fi;
	@echo

changelog:
	git-chglog -o CHANGELOG.md --next-tag `semtag final -s minor -o`

release:
	semtag final -s minor

# -------------------------------------------------------------------------------------------------
# Helper Targets
# -------------------------------------------------------------------------------------------------

_pull-tf:
	docker pull hashicorp/terraform:$(TF_VERSION)

_pull-fl:
	docker pull cytopia/file-lint:$(FL_VERSION)

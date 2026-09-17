MAKEDOC ?= $(HOME)/work/makedoc
MANUSCRIPT_CONFIG := $(CURDIR)/settings/build.yaml
THEORY_COVERAGE_PNG := outputs/goal008/theory-v2/gaussian-dependence-coverage.png

.PHONY: manuscript manuscript-check test-goal008 test-goal009 goal009-check

manuscript: $(THEORY_COVERAGE_PNG)
	$(MAKE) -C "$(MAKEDOC)" CONFIG="$(MANUSCRIPT_CONFIG)" all manifest

manuscript-check: $(THEORY_COVERAGE_PNG)
	$(MAKE) -C "$(MAKEDOC)" CONFIG="$(MANUSCRIPT_CONFIG)" validate-config
	$(MAKE) -C "$(MAKEDOC)" CONFIG="$(MANUSCRIPT_CONFIG)" check

test-goal008:
	Rscript -e 'testthat::test_dir("tests/testthat", filter = "goal008", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'

test-goal009:
	Rscript -e 'testthat::test_dir("tests/testthat", filter = "goal009", reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)'

goal009-check:
	Rscript scripts/run_goal009_criticism.R check

$(THEORY_COVERAGE_PNG): outputs/goal008/theory-v2/gaussian-dependence-coverage.pdf
	pdftoppm -singlefile -png -r 160 "$<" "$(basename $@)"

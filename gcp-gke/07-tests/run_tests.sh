#!/usr/bin/env bash
# ==============================================================================
# GKE Platform Blueprint - Comprehensive Validation & Test Runner
# ==============================================================================
# Usage: ./gcp-gke/07-tests/run_tests.sh
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GCP_GKE_DIR="${REPO_ROOT}/gcp-gke"

cd "${REPO_ROOT}"

# --- ANSI Color Codes ---
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m" # No Color

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_check() {
    local test_name="$1"
    shift
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e -n "  [RUN] ${test_name} ... "
    
    local output
    if output="$("$@" 2>&1)"; then
        echo -e "${GREEN}PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo -e "${RED}--- Error Details ---${NC}"
        echo "${output}" | sed 's/^/    /'
        echo -e "${RED}---------------------${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

echo -e "\n${BOLD}${CYAN}================================================================${NC}"
echo -e "${BOLD}${CYAN}   GKE Platform Blueprint - Automated Validation Test Suite      ${NC}"
echo -e "${BOLD}${CYAN}================================================================${NC}"
echo -e "Repository Root: ${REPO_ROOT}"
echo -e "Target Module  : ${GCP_GKE_DIR}\n"

# ==============================================================================
# 1. TOOLCHAIN CHECKS
# ==============================================================================
echo -e "${BOLD}1. Verifying CLI Toolchains & Runtime Prerequisites${NC}"

run_check "Python 3 is installed" python3 --version
run_check "Terraform is installed" terraform --version
run_check "Terragrunt is installed" terragrunt --version
run_check "Helm 3 is installed" helm version --short
run_check "PyYAML library is installed" python3 -c "import yaml; print(yaml.__name__)"

# ==============================================================================
# 2. YAML SYNTAX & PARSING CHECKS
# ==============================================================================
echo -e "\n${BOLD}2. Validating Platform YAML Configurations${NC}"

run_check "Validate all non-template YAML files parse cleanly" python3 -c "
import glob, yaml, sys
yaml_files = [f for f in glob.glob('${GCP_GKE_DIR}/**/*.yaml', recursive=True) + glob.glob('${GCP_GKE_DIR}/**/*.yml', recursive=True) if 'templates' not in f]
errors = []
for f in sorted(yaml_files):
    try:
        with open(f) as fp:
            yaml.safe_load(fp)
    except Exception as e:
        errors.append((f, str(e)))
if errors:
    for f, err in errors:
        print(f'ERROR in {f}: {err}', file=sys.stderr)
    sys.exit(1)
print(f'Successfully parsed {len(yaml_files)} YAML configuration files.')
"

run_check "StorageClass consistency (infra/prod.yaml vs jenkins/prod.yaml)" python3 -c "
import yaml, sys
with open('${GCP_GKE_DIR}/01-config/clients/amex/prod/infra/prod.yaml') as f:
    infra = yaml.safe_load(f)
with open('${GCP_GKE_DIR}/01-config/clients/amex/prod/jenkins/prod.yaml') as f:
    jenkins = yaml.safe_load(f)

infra_sc = infra.get('storage', {}).get('storageClassName')
jenkins_sc = jenkins.get('controller', {}).get('persistence', {}).get('storageClass') or jenkins.get('persistence', {}).get('storageClass')
if not infra_sc or not jenkins_sc or infra_sc != jenkins_sc:
    print(f'Mismatch: infra storageClassName ({infra_sc}) != jenkins persistence.storageClass ({jenkins_sc})', file=sys.stderr)
    sys.exit(1)
print(f'Matched storage class: {infra_sc}')
"

run_check "Validate apps.enabled declaration in infra/prod.yaml" python3 -c "
import yaml, sys
with open('${GCP_GKE_DIR}/01-config/clients/amex/prod/infra/prod.yaml') as f:
    cfg = yaml.safe_load(f)
if not cfg.get('apps', {}).get('enabled'):
    print('apps.enabled is missing or false in infra/prod.yaml', file=sys.stderr)
    sys.exit(1)
"

# ==============================================================================
# 3. PYTHON SCRIPT AST COMPILATION
# ==============================================================================
echo -e "\n${BOLD}3. Validating Python Scripts Syntax & AST Compilation${NC}"

run_check "Compile all Python scripts (py_compile)" python3 -c "
import glob, py_compile, sys
py_files = glob.glob('${GCP_GKE_DIR}/**/*.py', recursive=True)
errors = []
for f in py_files:
    try:
        py_compile.compile(f, doraise=True)
    except Exception as e:
        errors.append((f, str(e)))
if errors:
    for f, err in errors:
        print(f'Syntax error in {f}: {err}', file=sys.stderr)
    sys.exit(1)
print(f'Successfully validated {len(py_files)} Python scripts.')
"

# ==============================================================================
# 4. TERRAFORM & TERRAGRUNT FORMATTING CHECKS
# ==============================================================================
echo -e "\n${BOLD}4. Checking Code Style & Canonical Formatting${NC}"

run_check "Terraform modules format (terraform fmt -check)" terraform fmt -check -recursive "${GCP_GKE_DIR}/03-modules"

run_check "Terragrunt live environment format (terragrunt hcl fmt --check)" terragrunt hcl fmt --check --working-dir "${GCP_GKE_DIR}/04-live/clients/amex/prod"

run_check "Root Terragrunt format check (gcp-gke/root.hcl)" terragrunt hcl fmt --check --file "${GCP_GKE_DIR}/root.hcl"

run_check "Live root Terragrunt format check (gcp-gke/04-live/root.hcl)" terragrunt hcl fmt --check --file "${GCP_GKE_DIR}/04-live/root.hcl"

# ==============================================================================
# 5. REUSABLE MODULE CONTRACTS & VERSION PINNING
# ==============================================================================
echo -e "\n${BOLD}5. Verifying Reusable Terraform Module Contracts${NC}"

run_check "Verify all 03-modules have main.tf, variables.tf, and versions.tf" python3 -c "
import os, glob, sys
modules = glob.glob('${GCP_GKE_DIR}/03-modules/*')
required_files = ['main.tf', 'variables.tf', 'versions.tf']
errors = []
for m in sorted(modules):
    if not os.path.isdir(m): continue
    for rf in required_files:
        path = os.path.join(m, rf)
        if not os.path.exists(path):
            errors.append(f'{os.path.basename(m)} is missing {rf}')
if errors:
    for err in errors:
        print(err, file=sys.stderr)
    sys.exit(1)
print(f'All {len(modules)} modules have standard contracts.')
"

# ==============================================================================
# 6. HELM CHART VERIFICATION & MANIFEST RENDERING
# ==============================================================================
echo -e "\n${BOLD}6. Validating generic-app Helm Chart${NC}"

run_check "Helm chart lint (helm lint)" helm lint "${GCP_GKE_DIR}/05-helm-charts/generic-app"

run_check "Helm template render with default values.yaml" helm template test-default "${GCP_GKE_DIR}/05-helm-charts/generic-app"

run_check "Helm template render with amex/prod backend-web-values.yaml" helm template test-backend "${GCP_GKE_DIR}/05-helm-charts/generic-app" -f "${GCP_GKE_DIR}/01-config/clients/amex/prod/apps/backend-web-values.yaml"

run_check "Helm template render with amex/prod frontend-web-values.yaml" helm template test-frontend "${GCP_GKE_DIR}/05-helm-charts/generic-app" -f "${GCP_GKE_DIR}/01-config/clients/amex/prod/apps/frontend-web-values.yaml"

run_check "Helm template render with 06-examples backend-web-values.yaml" helm template test-ex-backend "${GCP_GKE_DIR}/05-helm-charts/generic-app" -f "${GCP_GKE_DIR}/06-examples/applications/backend-web-values.yaml"

# ==============================================================================
# 7. TERRAGRUNT DAG & DEPENDENCY GRAPH RESOLUTION
# ==============================================================================
echo -e "\n${BOLD}7. Validating Terragrunt Dependency Graph (DAG)${NC}"

run_check "Terragrunt DAG graph resolution (all 7 layers present)" python3 -c "
import subprocess, sys

cmd = ['terragrunt', 'dag', 'graph', '--working-dir', '${GCP_GKE_DIR}/04-live/clients/amex/prod']
res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode != 0:
    print(res.stderr, file=sys.stderr)
    sys.exit(1)

expected_layers = [
    '00-bootstrap',
    '01-network',
    '02-gke',
    '03-artifact-registry',
    '04-storage',
    '06-jenkins',
    '07-applications'
]
missing = [layer for layer in expected_layers if layer not in res.stdout]
if missing:
    print(f'Missing layers in DAG: {missing}', file=sys.stderr)
    sys.exit(1)

print('All 7 layers successfully connected in DAG.')
"

# ==============================================================================
# 8. SCAFFOLDING SCRIPTS EXECUTION
# ==============================================================================
echo -e "\n${BOLD}8. Testing Scaffolding Generators Idempotency${NC}"

run_check "Run 02-scaffold_client.py" python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/02-scaffold_client.py" "${GCP_GKE_DIR}/01-config/clients/amex/prod/infra/prod.yaml"

run_check "Run 03-scaffold_jenkins.py" python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/03-scaffold_jenkins.py" "${GCP_GKE_DIR}/01-config/clients/amex/prod/infra/prod.yaml"

run_check "Run 04-scaffold_apps.py" python3 "${GCP_GKE_DIR}/02-scripts/scaffolding/04-scaffold_apps.py" "${GCP_GKE_DIR}/01-config/clients/amex/prod/infra/prod.yaml"

run_check "Run deploy-env.sh orchestrator in dry-run mode" bash "${GCP_GKE_DIR}/02-scripts/deploy-env.sh" amex prod --dry-run

run_check "Verify no unformatted Terragrunt files produced by scaffolders" terragrunt hcl fmt --check --working-dir "${GCP_GKE_DIR}/04-live/clients/amex/prod"

# ==============================================================================
# SUMMARY & EXIT CODE
# ==============================================================================
echo -e "\n${BOLD}${CYAN}================================================================${NC}"
echo -e "${BOLD}Test Results Summary:${NC}"
echo -e "  Total Tests Executed: ${BOLD}${TOTAL_TESTS}${NC}"
echo -e "  Passed: ${GREEN}${BOLD}${PASSED_TESTS}${NC}"
echo -e "  Failed: ${RED}${BOLD}${FAILED_TESTS}${NC}"
echo -e "${BOLD}${CYAN}================================================================${NC}"

if [ "${FAILED_TESTS}" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✔ All validation checks passed successfully!${NC}\n"
    exit 0
else
    echo -e "${RED}${BOLD}✘ Some validation checks failed. Please review the errors above.${NC}\n"
    exit 1
fi


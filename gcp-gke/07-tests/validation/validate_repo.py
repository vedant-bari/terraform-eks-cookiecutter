#!/usr/bin/env python3
"""Read-only repository checks for the GKE Terraform/Terragrunt blueprint."""
from __future__ import annotations
import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GKE = ROOT / "gcp-gke"
LIVE = GKE / "04-live/clients/amex/prod"
errors: list[str] = []
warnings: list[str] = []

def check(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

def parse_yaml(path: Path):
    try:
        import yaml
    except ImportError as exc:
        raise RuntimeError("PyYAML is required for YAML validation") from exc

    class UniqueKeyLoader(yaml.SafeLoader):
        pass

    def construct_mapping(loader, node, deep=False):
        mapping = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if key in mapping:
                raise ValueError(f"duplicate YAML key: {key!r}")
            mapping[key] = loader.construct_object(value_node, deep=deep)
        return mapping

    UniqueKeyLoader.add_constructor(
        yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping
    )
    with path.open(encoding="utf-8") as handle:
        return yaml.load(handle, Loader=UniqueKeyLoader)

# 1. Parse active configuration/example YAML and reject duplicate keys.
yaml_files = sorted(
    list((GKE / "01-config").rglob("*.yaml"))
    + list((GKE / "01-config").rglob("*.yml"))
    + list((GKE / "06-examples").rglob("*.yaml"))
    + list((GKE / "06-examples").rglob("*.yml"))
)
for path in yaml_files:
    try:
        parse_yaml(path)
    except Exception as exc:
        errors.append(f"YAML error in {path.relative_to(ROOT)}: {exc}")
print(f"YAML files checked: {len(yaml_files)}")

# Cross-file configuration contracts for the retained AMEX test environment.
try:
    infra_cfg = parse_yaml(GKE / "01-config/clients/amex/prod/infra/prod.yaml") or {}
    observability_cfg = parse_yaml(
        GKE / "01-config/clients/amex/prod/monitoring-and-logging/prod.yaml"
    ) or {}
    jenkins_cfg = parse_yaml(GKE / "01-config/clients/amex/prod/jenkins/prod.yaml") or {}
    infra_sc = (infra_cfg.get("storage") or {}).get("storageClassName")
    jenkins_sc = ((jenkins_cfg.get("controller") or {}).get("persistence") or {}).get("storageClass")
    check(bool(infra_sc) and infra_sc == jenkins_sc,
          f"StorageClass mismatch: infra={infra_sc!r}, Jenkins={jenkins_sc!r}")
    check(bool((infra_cfg.get("apps") or {}).get("enabled")),
          "AMEX prod infra config must explicitly enable apps")
    check(bool((observability_cfg.get("monitoring") or {}).get("alertmanager", {}).get("enabled")),
          "AMEX observability config must enable Alertmanager")
    check(bool((observability_cfg.get("tempo") or {}).get("persistence", {}).get("enabled")),
          "AMEX observability config must enable persistent Tempo storage")
    check(bool((observability_cfg.get("monitoring") or {}).get("additionalPrometheusRulesMap")),
          "AMEX observability config must define workload alert rules")
    grafana_cfg = (observability_cfg.get("monitoring") or {}).get("grafana") or {}
    alertmanager_cfg = (observability_cfg.get("monitoring") or {}).get("alertmanager") or {}
    alloy_cfg = observability_cfg.get("alloy") or {}
    check(grafana_cfg.get("ingress", {}).get("enabled") is False,
          "Grafana ingress must remain disabled by default")
    check(grafana_cfg.get("admin", {}).get("existingSecret") == "grafana-admin-credentials",
          "Grafana admin credentials must be sourced from the pre-created Kubernetes Secret")
    check("alertmanager-webhook" in (alertmanager_cfg.get("alertmanagerSpec") or {}).get("secrets", []),
          "Alertmanager webhook credentials must be sourced from the pre-created Kubernetes Secret")
    check(bool((alloy_cfg.get("rbac") or {}).get("rules")),
          "Alloy must define read-only Kubernetes RBAC rules for pod logs and events")
    check((observability_cfg.get("chart_versions") or {}).get("tempo") == "3.2.1",
          "Tempo Helm chart version must be pinned")
except Exception as exc:
    errors.append(f"AMEX config contract validation failed: {exc}")


# 2. Python syntax without writing __pycache__ files.
python_files = sorted((GKE / "02-scripts").rglob("*.py"))
for path in python_files:
    try:
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except SyntaxError as exc:
        errors.append(f"Python syntax error in {path.relative_to(ROOT)}:{exc.lineno}: {exc.msg}")
print(f"Python files checked: {len(python_files)}")

# 3. Terraform resource address uniqueness within each reusable module.
for module_dir in sorted(p for p in (GKE / "03-modules").iterdir() if p.is_dir()):
    addresses: dict[tuple[str, str], Path] = {}
    for tf_file in module_dir.glob("*.tf"):
        source = tf_file.read_text(encoding="utf-8")
        for match in re.finditer(r'(?m)^\s*resource\s+"([^"]+)"\s+"([^"]+)"\s*\{', source):
            address = (match.group(1), match.group(2))
            if address in addresses:
                errors.append(
                    f"Duplicate Terraform resource {address[0]}.{address[1]} in "
                    f"{module_dir.name}: {addresses[address].name} and {tf_file.name}"
                )
            else:
                addresses[address] = tf_file
print("Terraform resource address uniqueness checked.")

# Explicit regression checks for the D1 Jenkins/VPC fixes.
jenkins_tf = (GKE / "03-modules/10-jenkins/main.tf").read_text(encoding="utf-8")
check(len(re.findall(r'resource\s+"kubernetes_cluster_role_v1"\s+"jenkins_agent_deployer"\s*\{', jenkins_tf)) == 1,
      "Jenkins ClusterRole must be declared exactly once")
check(len(re.findall(r'resource\s+"kubernetes_cluster_role_binding_v1"\s+"jenkins_agent_deployer_binding"\s*\{', jenkins_tf)) == 1,
      "Jenkins ClusterRoleBinding must be declared exactly once")
jenkins_yaml_text = (GKE / "01-config/clients/amex/prod/jenkins/prod.yaml").read_text(encoding="utf-8")
check(jenkins_yaml_text.count('serviceAccountName: "jenkins-agent"') == 1,
      "Jenkins agent serviceAccountName must be defined only at Pod spec level")
vpc_outputs = (GKE / "03-modules/02-vpc/outputs.tf").read_text(encoding="utf-8")
check("value       = module.vpc.subnets_self_links[0]" in vpc_outputs,
      "VPC subnet_self_link output must use subnets_self_links")


# Reusable modules must expose their standard Terraform module contract.
for module_dir in sorted(p for p in (GKE / "03-modules").iterdir() if p.is_dir()):
    for required_file in ("main.tf", "variables.tf", "versions.tf"):
        check((module_dir / required_file).is_file(),
              f"Module {module_dir.name} is missing {required_file}")


# 4. Stable backend key mapping in both root configurations.
expected = {
    "00-bootstrap": "bootstrap",
    "01-network": "network",
    "02-gke": "gke",
    "03-artifact-registry": "artifact-registry",
    "04-storage": "storage",
    "05-monitoring": "monitoring",
    "06-jenkins": "jenkins",
    "07-applications": "applications",
}
for root_file in (GKE / "04-live/root.hcl", GKE / "root.hcl"):
    source = root_file.read_text(encoding="utf-8")
    block = re.search(r"state_layer_keys\s*=\s*\{(.*?)\n\s*\}", source, re.S)
    actual = dict(re.findall(r'"([^"]+)"\s*=\s*"([^"]+)"', block.group(1))) if block else {}
    check(actual == expected, f"Backend layer mapping mismatch in {root_file.relative_to(ROOT)}")
    check('prefix   = "gcp-gke/${local.client_name}/${local.env_name}/${local.state_layer_key}/terraform.tfstate"' in source,
          f"Backend prefix is not using stable logical layer key in {root_file.relative_to(ROOT)}")
print("Stable backend prefix mapping checked.")

# 5. Live-unit structure, module source paths, and dependency paths.
expected_live = [
    "00-bootstrap", "01-network", "02-gke", "03-artifact-registry",
    "04-storage", "05-monitoring", "06-jenkins", "07-applications",
]
for layer in expected_live:
    hcl = LIVE / layer / "terragrunt.hcl"
    check(hcl.is_file(), f"Missing live unit: {hcl.relative_to(ROOT)}")
    if not hcl.is_file():
        continue
    content = hcl.read_text(encoding="utf-8")
    ancestors = [hcl.parent, *hcl.parent.parents]
    check(any((ancestor / "root.hcl").is_file() for ancestor in ancestors),
          f"No discoverable root.hcl for {hcl.relative_to(ROOT)}")

    for module_path in re.findall(r'source\s*=\s*"\$\{get_repo_root\(\)\}/([^"]+)"', content):
        check((ROOT / module_path).exists(), f"Missing module source {module_path} referenced by {hcl.relative_to(ROOT)}")
    for dep in re.findall(r'config_path\s*=\s*"([^"]+)"', content):
        check((hcl.parent / dep / "terragrunt.hcl").is_file(),
              f"Broken dependency {dep} in {hcl.relative_to(ROOT)}")
    for dep_block in re.findall(r'paths\s*=\s*\[(.*?)\]', content, re.S):
        for dep in re.findall(r'"([^"]+)"', dep_block):
            check((hcl.parent / dep / "terragrunt.hcl").is_file(),
                  f"Broken dependency path {dep} in {hcl.relative_to(ROOT)}")
monitoring_hcl = LIVE / "05-monitoring/terragrunt.hcl"
if monitoring_hcl.is_file():
    monitoring_source = monitoring_hcl.read_text(encoding="utf-8")
    check("03-modules/05-monitoring" in monitoring_source,
          "Monitoring live unit must reference the existing 05-monitoring module")
    check("monitoring-and-logging" in monitoring_source,
          "Monitoring live unit must load the environment observability YAML")
    check('dependency "gke"' in monitoring_source,
          "Monitoring live unit must depend on GKE outputs")
monitoring_module = (GKE / "03-modules/05-monitoring/main.tf").read_text(encoding="utf-8")
check('resource "helm_release" "tempo"' in monitoring_module,
      "Monitoring module must deploy Tempo")
check('chart            = "tempo"' in monitoring_module,
      "Monitoring module must use the Tempo Helm chart")
print("Live-unit/module/dependency paths checked.")

# Validate source paths in scaffolding templates as well as generated live units.
for template in (GKE / "02-scripts/templates").glob("*.template"):
    content = template.read_text(encoding="utf-8")
    for module_path in re.findall(r'source\s*=\s*"\$\{get_repo_root\(\)\}/([^"]+)"', content):
        check((ROOT / module_path).exists(), f"Missing module source {module_path} in {template.relative_to(ROOT)}")


# Mock outputs may support init/validate, but never a deployment plan.
for path in list((GKE / "04-live").rglob("terragrunt.hcl")) + list((GKE / "02-scripts/templates").glob("*.template")):
    content = path.read_text(encoding="utf-8")
    for allowed in re.findall(r'mock_outputs_allowed_terraform_commands\s*=\s*\[([^]]*)\]', content):
        check('"plan"' not in allowed, f"Mock outputs are allowed for plan in {path.relative_to(ROOT)}")


# 6. Orchestration safety invariants.
plan_script = (GKE / "02-scripts/plan-env.sh").read_text(encoding="utf-8")
apply_script = (GKE / "02-scripts/apply-env.sh").read_text(encoding="utf-8")
destroy_script = (GKE / "02-scripts/destroy-env.sh").read_text(encoding="utf-8")
deploy_script = (GKE / "02-scripts/deploy-env.sh").read_text(encoding="utf-8")
check("terragrunt import" not in plan_script + apply_script + destroy_script + deploy_script,
      "Automatic/manual import command found in orchestration scripts")
check("terragrunt run -- apply" not in plan_script, "Plan script must never apply")
check("05-monitoring" in plan_script, "Plan script must include the monitoring layer")
check("05-monitoring" in apply_script, "Apply script must include the monitoring layer")
check("05-monitoring" in destroy_script, "Destroy script must include the monitoring layer")
check("terragrunt run -- plan" not in apply_script, "Apply script must not regenerate plans")
check("--destroy" in destroy_script and "mode=destroy" in destroy_script,
      "Destroy script is missing explicit opt-in or destroy-plan manifest checks")
check("scaffold" not in deploy_script.lower(), "Deploy wrapper must not invoke scaffolding")
check("terraform.tfstate" not in plan_script, "Plan script must not manipulate state objects")

check('run -- apply "$plan_file"' in apply_script,
      "Apply script must apply a saved plan file")
check("sha256" in apply_script and "read -r -p" in apply_script,
      "Apply script must verify saved plan integrity and prompt per layer")
check('run -- apply "$plan_file"' in destroy_script,
      "Destroy script must apply a previously saved destroy plan")

for script in (GKE / "02-scripts/plan-env.sh", GKE / "02-scripts/apply-env.sh",
               GKE / "02-scripts/destroy-env.sh", GKE / "02-scripts/deploy-env.sh"):
    text = script.read_text(encoding="utf-8")
    check("|| true" not in text, f"Failure masking '|| true' found in {script.relative_to(ROOT)}")
print("Deployment/destruction safety invariants checked.")

# 7. Shell syntax for all scripts.
import subprocess
shell_files = sorted((GKE / "02-scripts").rglob("*.sh")) + [GKE / "07-tests/run_tests.sh"]
for path in shell_files:
    result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
    if result.returncode:
        errors.append(f"Shell syntax error in {path.relative_to(ROOT)}: {result.stderr.strip()}")
print(f"Shell scripts syntax-checked: {len(shell_files)}")

# 8. Optional, read-only format/lint checks when tools are installed.
def optional(command: list[str], label: str) -> None:
    if not __import__("shutil").which(command[0]):
        warnings.append(f"{label}: skipped (tool not installed)")
        return
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        errors.append(f"{label} failed: {(result.stdout + result.stderr).strip()}")

optional(["terraform", "fmt", "-check", "-recursive", str(GKE / "03-modules")], "terraform fmt -check")
optional(["terragrunt", "hcl", "fmt", "--check", "--working-dir", str(LIVE)], "terragrunt hcl fmt --check")
optional(["helm", "lint", str(GKE / "05-helm-charts/generic-app")], "helm lint")

optional(["helm", "template", "test-backend", str(GKE / "05-helm-charts/generic-app"),
          "-f", str(GKE / "01-config/clients/amex/prod/apps/backend-web-values.yaml")],
         "helm template backend")
optional(["helm", "template", "test-frontend", str(GKE / "05-helm-charts/generic-app"),
          "-f", str(GKE / "01-config/clients/amex/prod/apps/frontend-web-values.yaml")],
         "helm template frontend")


for warning in warnings:
    print(f"SKIP: {warning}")
if errors:
    print("\nFAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)
print("\nPASS: read-only GKE repository validation completed.")

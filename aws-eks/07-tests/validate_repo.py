#!/usr/bin/env python3
"""Read-only static validation for the AWS EKS Terraform/Terragrunt blueprint."""
from __future__ import annotations
import ast
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AWS = ROOT / "aws-eks"
LIVE = AWS / "04-live/clients/amex/dev"
errors: list[str] = []

def check(ok: bool, message: str) -> None:
    if not ok:
        errors.append(message)

try:
    import yaml
except ImportError:
    print("PyYAML is required: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(2)

class UniqueLoader(yaml.SafeLoader):
    pass

def construct_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"duplicate YAML key: {key!r}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result
UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping)

yaml_files = (
    sorted((AWS / "01-config").rglob("*.yaml"))
    + sorted((AWS / "01-config").rglob("*.yml"))
    + sorted((AWS / "06-examples").rglob("*.yaml"))
    + sorted((AWS / "06-examples").rglob("*.yml"))
    + [AWS / "05-helm-charts/generic-app/values.yaml"]
)
for path in yaml_files:
    try:
        with path.open(encoding="utf-8") as handle:
            yaml.load(handle, Loader=UniqueLoader)
    except Exception as exc:
        errors.append(f"YAML error in {path.relative_to(ROOT)}: {exc}")
print(f"YAML files checked: {len(yaml_files)}")

config_path = AWS / "01-config/clients/amex/dev/infra/dev.yaml"
try:
    cfg = yaml.load(config_path.read_text(encoding="utf-8"), Loader=UniqueLoader) or {}
    check(cfg.get("client", {}).get("name") == "amex", "AMEX dev client.name contract is missing")
    check(cfg.get("environment") == "dev", "AMEX dev environment contract is missing")
    check(bool(cfg.get("aws", {}).get("region")), "AWS region is required")
    check(bool(cfg.get("bootstrap", {}).get("state_bucket_name")), "S3 backend bucket name is required")
    eks = cfg.get("eks") or {}
    check(bool(eks.get("cluster_name")) and bool(eks.get("cluster_version")), "EKS cluster name/version are required")
    check(not eks.get("endpoint_public_access") or bool(eks.get("endpoint_public_access_cidrs")),
          "Public EKS endpoint requires an explicit CIDR allowlist")
    vpc = cfg.get("vpc") or {}
    check(len(vpc.get("azs", [])) == len(vpc.get("private_subnets", [])),
          "Private subnet count must match the configured AZ count")
    check(len(vpc.get("azs", [])) == len(vpc.get("public_subnets", [])),
          "Public subnet count must match the configured AZ count")
    bastion = cfg.get("bastion") or {}
    check(bastion.get("create") is False, "Sample AMEX bastion must remain disabled by default")
    check(bastion.get("associate_public_ip_address") is True,
          "If enabled in the public subnet, the sample bastion needs outbound SSM connectivity")
    for rule in bastion.get("ingress_rules", []):
        check("0.0.0.0/0" not in rule.get("cidr_blocks", []),
              "Bastion ingress must not be open to the world")
    check((cfg.get("applications") or {}).get("enabled") is False,
          "Sample applications must remain opt-in by default")
except Exception as exc:
    errors.append(f"AMEX config contract validation failed: {exc}")

modules = AWS / "03-modules"
for module in sorted(p for p in modules.iterdir() if p.is_dir()):
    for name in ("main.tf", "variables.tf", "versions.tf"):
        check((module / name).is_file(), f"{module.name} missing {name}")

# Validate the EKS module v21 breaking-input-name mapping and provider contract.
eks_module = (modules / "04-eks/main.tf").read_text(encoding="utf-8")
check('version = "~> 21.0"' in eks_module, "EKS module must use the v21 major line")
for pattern, label in (
    (r"\bname\s*=\s*var\.cluster_name", "name"),
    (r"\bkubernetes_version\s*=\s*var\.cluster_version", "kubernetes_version"),
    (r"\bendpoint_private_access\s*=\s*var\.cluster_endpoint_private_access", "endpoint_private_access"),
    (r"\bendpoint_public_access\s*=\s*var\.cluster_endpoint_public_access", "endpoint_public_access"),
    (r"\baddons\s*=\s*var\.cluster_addons", "addons"),
    (r"\benabled_log_types\s*=\s*var\.cluster_enabled_log_types", "enabled_log_types"),
):
    check(bool(re.search(pattern, eks_module)), f"EKS v21 input mapping missing: {label}")

expected_layers = [
    "01-network", "02-bastion", "03-eks", "04-ebs-csi",
    "05-efs-csi", "06-monitoring", "07-logging", "08-applications",
]
root_hcl = (AWS / "04-live/root.hcl").read_text(encoding="utf-8")
state_map_match = re.search(r"state_layer_keys\s*=\s*\{(.*?)\n\s*\}", root_hcl, re.S)
expected_state_map = {
    "00-bootstrap": "bootstrap", "01-network": "network", "02-bastion": "bastion",
    "03-eks": "eks", "04-ebs-csi": "ebs-csi", "05-efs-csi": "efs-csi",
    "06-monitoring": "monitoring", "07-logging": "logging",
    "08-applications": "applications",
}
actual_state_map = dict(re.findall(r'"([^"]+)"\s*=\s*"([^"]+)"', state_map_match.group(1))) if state_map_match else {}
check(actual_state_map == expected_state_map, "Stable S3 state layer mapping does not match the expected logical keys")
check('use_lockfile = true' in root_hcl and 'aws-eks/' in root_hcl and 'state_layer_key' in root_hcl,
      "S3 backend must use the stable AWS EKS logical state-key prefix")
for layer in expected_layers:
    check(f'"{layer}"' in root_hcl, f"Stable backend layer key missing: {layer}")
    check((AWS / "02-scripts/templates" / f"{layer}.hcl.template").is_file(),
          f"Missing Terragrunt scaffolding template for {layer}")

for layer in expected_layers:
    hcl = LIVE / layer / "terragrunt.hcl"
    check(hcl.is_file(), f"Missing live unit: {hcl.relative_to(ROOT)}")
    if not hcl.is_file():
        continue
    content = hcl.read_text(encoding="utf-8")
    template = AWS / "02-scripts/templates" / f"{layer}.hcl.template"
    check(template.read_text(encoding="utf-8") == content,
          f"Scaffolding template differs from live unit for {layer}")
    for module_path in re.findall(r'source\s*=\s*"\$\{get_repo_root\(\)\}/([^"]+)"', content):
        check((ROOT / module_path).exists(), f"Missing module source {module_path}")
    for dep in re.findall(r'config_path\s*=\s*"([^"]+)"', content):
        check((hcl.parent / dep / "terragrunt.hcl").is_file(), f"Broken dependency {dep} in {hcl.relative_to(ROOT)}")
    for dep_block in re.findall(r'paths\s*=\s*\[([^]]*)\]', content, re.S):
        for dep in re.findall(r'"([^"]+)"', dep_block):
            check((hcl.parent / dep / "terragrunt.hcl").is_file(),
                  f"Broken dependency path {dep} in {hcl.relative_to(ROOT)}")
    ancestors = [hcl.parent, *hcl.parent.parents]
    check(any((ancestor / "root.hcl").is_file() for ancestor in ancestors),
          f"No discoverable root.hcl for {hcl.relative_to(ROOT)}")
    for allowed in re.findall(r'mock_outputs_allowed_terraform_commands\s*=\s*\[([^]]*)\]', content):
        check('"plan"' not in allowed, f"Mock outputs must not be allowed for plan in {hcl.relative_to(ROOT)}")

check((AWS / "02-scripts/scaffolding/scaffold_client.py").is_file(), "Missing client scaffolding script")
chart_dir = AWS / "05-helm-charts/generic-app"
check((chart_dir / "Chart.yaml").is_file(), "Missing shared generic application chart")
check(not (chart_dir / "templates/poddisruptionbudget.yaml").exists(),
      "Generic application chart contains duplicate PodDisruptionBudget templates")
try:
    chart_values = yaml.safe_load((chart_dir / "values.yaml").read_text(encoding="utf-8")) or {}
    check((chart_values.get("networkPolicy") or {}).get("enabled") is False,
          "NetworkPolicy must be disabled by default in the generic chart")
    check((chart_values.get("storage") or {}).get("efs", {}).get("enabled") is False,
          "EFS mounting must be disabled by default in the generic chart")
except Exception as exc:
    errors.append(f"Generic chart values validation failed: {exc}")
check((AWS / "06-examples/storage/ebs-pvc.yaml").is_file(), "Missing EBS PVC example")
check((AWS / "06-examples/storage/efs-pvc.yaml").is_file(), "Missing EFS PVC example")

# Cross-component storage and observability contracts.
try:
    override = yaml.safe_load(
        (AWS / "01-config/clients/amex/dev/monitoring-and-logging/override.yaml").read_text(encoding="utf-8")
    ) or {}
    monitoring = override.get("monitoring") or {}
    loki = override.get("loki") or {}
    alloy = override.get("alloy") or {}
    check((monitoring.get("grafana") or {}).get("persistence", {}).get("storageClassName") == "__STORAGE_CLASS_NAME__",
          "Grafana persistence must use the EBS StorageClass placeholder")
    check((monitoring.get("prometheus") or {}).get("prometheusSpec", {}).get("storageSpec", {})
          .get("volumeClaimTemplate", {}).get("spec", {}).get("storageClassName") == "__STORAGE_CLASS_NAME__",
          "Prometheus persistence must use the EBS StorageClass placeholder")
    check((loki.get("singleBinary") or {}).get("persistence", {}).get("storageClass") == "__STORAGE_CLASS_NAME__",
          "Loki persistence must use the EBS StorageClass placeholder")
    check("__MONITORING_NAMESPACE__" in str(alloy), "Alloy Loki endpoint must use the monitoring namespace placeholder")
except Exception as exc:
    errors.append(f"Observability configuration contract validation failed: {exc}")

monitoring_module = (modules / "07-monitoring/main.tf").read_text(encoding="utf-8")
logging_module = (modules / "08-logging/main.tf").read_text(encoding="utf-8")
check("__STORAGE_CLASS_NAME__" in monitoring_module, "Monitoring module must render the shared StorageClass placeholder")
check("__STORAGE_CLASS_NAME__" in logging_module and "__MONITORING_NAMESPACE__" in logging_module,
      "Logging module must render storage and namespace placeholders")

plan_script = (AWS / "02-scripts/plan-env.sh").read_text(encoding="utf-8")
apply_script = (AWS / "02-scripts/apply-env.sh").read_text(encoding="utf-8")
destroy_script = (AWS / "02-scripts/destroy-env.sh").read_text(encoding="utf-8")
deploy_script = (AWS / "02-scripts/deploy-env.sh").read_text(encoding="utf-8")
check("run -- apply" not in plan_script, "Plan script must never apply")
check("run -- plan" not in apply_script, "Apply script must not regenerate plans")
check("--destroy" in destroy_script and "mode=destroy" in destroy_script, "Destroy must be explicit and manifest-validated")
check("plan-env.sh" in deploy_script and "exec bash" in deploy_script, "Deploy wrapper must only delegate to plan mode")
check("aws-eks" in root_hcl and "use_lockfile = true" in root_hcl, "S3 backend must use AWS EKS namespace and native lockfile")
check("force_destroy = true" not in (modules / "01-bootstrap/main.tf").read_text(encoding="utf-8"),
      "State bucket module must not force-delete objects")
bastion_variables = (modules / "03-bastion/variables.tf").read_text(encoding="utf-8")
check(bool(re.search(r'variable "ingress_rules"[\s\S]*?default\s*=\s*\[\]', bastion_variables)),
      "Bastion ingress must default to an empty allowlist")

legacy_deploy = (AWS / "15-scripts/deploy-env.sh").read_text(encoding="utf-8")
legacy_destroy = (AWS / "15-scripts/destroy-env.sh").read_text(encoding="utf-8")
legacy_bootstrap = (AWS / "15-scripts/01-create-bootstrap-bucket.sh").read_text(encoding="utf-8")
check("../02-scripts/deploy-env.sh" in legacy_deploy, "Legacy deploy wrapper must delegate to plan-only script")
check("../02-scripts/destroy-env.sh" in legacy_destroy, "Legacy destroy wrapper must delegate to guarded destroy script")
check("../02-scripts/bootstrap/create-state-bucket.sh" in legacy_bootstrap,
      "Legacy bootstrap wrapper must delegate to hardened bootstrap script")

# Python syntax, Terraform resource address uniqueness, and orchestration safety.
python_files = sorted((AWS / "02-scripts").rglob("*.py"))
for py_file in python_files:
    try:
        ast.parse(py_file.read_text(encoding="utf-8"), filename=str(py_file))
    except SyntaxError as exc:
        errors.append(f"Python syntax error in {py_file.relative_to(ROOT)}:{exc.lineno}: {exc.msg}")
print(f"Python files syntax-checked: {len(python_files)}")

for module_dir in sorted(p for p in modules.iterdir() if p.is_dir()):
    addresses = {}
    for tf_file in module_dir.glob("*.tf"):
        source = tf_file.read_text(encoding="utf-8")
        for match in re.finditer(r'(?m)^\s*resource\s+"([^"]+)"\s+"([^"]+)"\s*\{', source):
            address = (match.group(1), match.group(2))
            if address in addresses:
                errors.append(f"Duplicate Terraform resource {address[0]}.{address[1]} in {module_dir.name}")
            addresses[address] = tf_file

all_orchestration = plan_script + apply_script + destroy_script + deploy_script
check("terragrunt import" not in all_orchestration, "Orchestration scripts must not perform imports")
check("run -- apply" not in plan_script, "Plan script must never apply")
check("run -- plan" not in apply_script, "Apply script must not regenerate plans")
check('run -- apply "$plan_file"' in apply_script, "Apply script must apply a saved plan")
check('run -- apply "$plan_file"' in destroy_script, "Destroy script must apply a saved destroy plan")
check("sha256sum" in apply_script and "read -r -p" in apply_script,
      "Apply script must verify checksums and prompt for confirmation")
check("sha256sum" in destroy_script and "read -r -p" in destroy_script,
      "Destroy script must verify checksums and prompt for confirmation")
check("terraform.tfstate" not in plan_script, "Plan script must not manipulate remote state objects")
for script_text, script_name in ((plan_script, "plan"), (apply_script, "apply"),
                                 (destroy_script, "destroy"), (deploy_script, "deploy")):
    check("|| true" not in script_text, f"Failure masking '|| true' found in {script_name} script")

shell_files = sorted((AWS / "02-scripts").rglob("*.sh")) + [
    AWS / "15-scripts/deploy-env.sh",
    AWS / "15-scripts/destroy-env.sh",
    AWS / "15-scripts/01-create-bootstrap-bucket.sh",
    AWS / "07-tests/run_tests.sh",
]
for shell_file in shell_files:
    result = subprocess.run(["bash", "-n", str(shell_file)], capture_output=True, text=True)
    if result.returncode:
        errors.append(f"Shell syntax error in {shell_file.relative_to(ROOT)}: {result.stderr.strip()}")
print(f"Shell scripts syntax-checked: {len(shell_files)}")

if shutil.which("helm"):
    for command, label in (
        (["helm", "lint", str(chart_dir)], "helm lint"),
        (["helm", "template", "sample-nginx", str(chart_dir), "--namespace", "sample-nginx",
          "--values", str(AWS / "01-config/clients/amex/dev/applications/nginx.yaml")], "helm template sample"),
    ):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        if result.returncode:
            errors.append(f"{label} failed: {(result.stdout + result.stderr).strip()}")
else:
    print("SKIP: Helm is not installed; chart lint/render checks were not run.")

if errors:
    print("FAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)
print("PASS: read-only AWS EKS repository validation completed.")

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
    "04-storage", "06-jenkins", "07-applications",
]
for layer in expected_live:
    hcl = LIVE / layer / "terragrunt.hcl"
    check(hcl.is_file(), f"Missing live unit: {hcl.relative_to(ROOT)}")
    if not hcl.is_file():
        continue
    content = hcl.read_text(encoding="utf-8")
    for module_path in re.findall(r'source\s*=\s*"\$\{get_repo_root\(\)\}/([^"]+)"', content):
        check((ROOT / module_path).exists(), f"Missing module source {module_path} referenced by {hcl.relative_to(ROOT)}")
    for dep in re.findall(r'config_path\s*=\s*"([^"]+)"', content):
        check((hcl.parent / dep / "terragrunt.hcl").is_file(),
              f"Broken dependency {dep} in {hcl.relative_to(ROOT)}")
    for dep_block in re.findall(r'paths\s*=\s*\[(.*?)\]', content, re.S):
        for dep in re.findall(r'"([^"]+)"', dep_block):
            check((hcl.parent / dep / "terragrunt.hcl").is_file(),
                  f"Broken dependency path {dep} in {hcl.relative_to(ROOT)}")
print("Live-unit/module/dependency paths checked.")

# 6. Orchestration safety invariants.
plan_script = (GKE / "02-scripts/plan-env.sh").read_text(encoding="utf-8")
apply_script = (GKE / "02-scripts/apply-env.sh").read_text(encoding="utf-8")
destroy_script = (GKE / "02-scripts/destroy-env.sh").read_text(encoding="utf-8")
deploy_script = (GKE / "02-scripts/deploy-env.sh").read_text(encoding="utf-8")
check("terragrunt import" not in plan_script + apply_script + destroy_script + deploy_script,
      "Automatic/manual import command found in orchestration scripts")
check("terragrunt run -- apply" not in plan_script, "Plan script must never apply")
check("terragrunt run -- plan" not in apply_script, "Apply script must not regenerate plans")
check("--destroy" in destroy_script and "mode=destroy" in destroy_script,
      "Destroy script is missing explicit opt-in or destroy-plan manifest checks")
check("scaffold" not in deploy_script.lower(), "Deploy wrapper must not invoke scaffolding")
check("terraform.tfstate" not in plan_script, "Plan script must not manipulate state objects")
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

for warning in warnings:
    print(f"SKIP: {warning}")
if errors:
    print("\nFAILED:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)
print("\nPASS: read-only GKE repository validation completed.")

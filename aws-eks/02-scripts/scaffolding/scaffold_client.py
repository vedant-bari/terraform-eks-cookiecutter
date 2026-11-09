#!/usr/bin/env python3
"""Generate Terragrunt live units from the shared AWS EKS templates."""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML is required: python3 -m pip install pyyaml", file=sys.stderr)
    raise SystemExit(2)

AWS_DIR = Path(__file__).resolve().parents[2]
TEMPLATES_DIR = AWS_DIR / "02-scripts" / "templates"
LAYERS = (
    "01-network",
    "02-bastion",
    "03-eks",
    "04-ebs-csi",
    "05-efs-csi",
    "06-monitoring",
    "07-logging",
    "08-applications",
)

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", required=True, help="Client folder/name, e.g. amex")
    parser.add_argument("--environment", required=True, help="Environment, e.g. dev or prod")
    parser.add_argument("--config", type=Path, help="Optional explicit infrastructure YAML path")
    parser.add_argument("--force", action="store_true", help="Replace existing Terragrunt files")
    parser.add_argument("--dry-run", action="store_true", help="Show intended file operations only")
    args = parser.parse_args()

    config_path = args.config or (
        AWS_DIR / "01-config" / "clients" / args.client / args.environment
        / "infra" / f"{args.environment}.yaml"
    )
    if not config_path.is_file():
        print(f"Configuration file not found: {config_path}", file=sys.stderr)
        return 1

    try:
        config = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    except Exception as exc:
        print(f"Unable to parse {config_path}: {exc}", file=sys.stderr)
        return 1

    configured_client = (config.get("client") or {}).get("name")
    configured_environment = config.get("environment")
    if configured_client != args.client:
        print(f"client.name must equal '{args.client}' in {config_path}", file=sys.stderr)
        return 1
    if configured_environment != args.environment:
        print(f"environment must equal '{args.environment}' in {config_path}", file=sys.stderr)
        return 1

    live_root = AWS_DIR / "04-live" / "clients" / args.client / args.environment
    changed = 0
    for layer in LAYERS:
        template = TEMPLATES_DIR / f"{layer}.hcl.template"
        destination = live_root / layer / "terragrunt.hcl"
        if not template.is_file():
            print(f"Missing template: {template}", file=sys.stderr)
            return 1
        content = template.read_text(encoding="utf-8")

        if destination.is_file():
            existing = destination.read_text(encoding="utf-8")
            if existing == content:
                print(f"Up to date: {destination.relative_to(AWS_DIR)}")
                continue
            if not args.force:
                print(f"Preserved existing file (use --force to replace): {destination.relative_to(AWS_DIR)}")
                continue

        print(f"{'Would write' if args.dry_run else 'Writing'}: {destination.relative_to(AWS_DIR)}")
        if not args.dry_run:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(content, encoding="utf-8")
        changed += 1

    print(f"Scaffolding complete: {changed} file(s) {'would be ' if args.dry_run else ''}written.")
    print("The S3 backend bucket must be provisioned separately before Terragrunt init.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

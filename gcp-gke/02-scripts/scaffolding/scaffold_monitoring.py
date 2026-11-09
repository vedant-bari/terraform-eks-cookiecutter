#!/usr/bin/env python3
"""Generate the monitoring live unit from the reviewed monitoring template."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import yaml


def load_yaml(file_path: str) -> dict:
    path = Path(file_path)
    if not path.is_file():
        raise SystemExit(f"Configuration file not found: {path}")
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def render_template(template_name: str) -> str:
    templates_dir = Path(__file__).resolve().parent.parent / "templates"
    template_path = templates_dir / template_name
    if not template_path.is_file():
        raise SystemExit(f"Template file not found: {template_path}")
    return template_path.read_text(encoding="utf-8")


def write_file_if_changed(file_path: Path, content: str) -> None:
    file_path.parent.mkdir(parents=True, exist_ok=True)
    if file_path.exists() and file_path.read_text(encoding="utf-8") == content:
        print(f"Up to date: {file_path}")
        return
    file_path.write_text(content, encoding="utf-8")
    print(f"Created/updated: {file_path}")


def generate_monitoring_files(infra_config_path: str) -> None:
    config = load_yaml(infra_config_path)
    client_name = (config.get("client") or {}).get("name")
    environment = config.get("environment", "dev")
    if not client_name:
        raise SystemExit("'client.name' is required in the infrastructure YAML")

    repo_root = Path(__file__).resolve().parents[3]
    gke_root = repo_root / "gcp-gke"
    observability_config = (
        gke_root / "01-config" / "clients" / client_name / environment
        / "monitoring-and-logging" / f"{environment}.yaml"
    )
    if not observability_config.is_file():
        raise SystemExit(
            "Monitoring configuration is missing: "
            f"{observability_config}. Create and review it before scaffolding."
        )

    enabled = (config.get("observability") or {}).get("enabled", True)
    if not enabled:
        print(f"Observability is disabled for {client_name}/{environment}; skipping.")
        return

    live_unit = (
        gke_root / "04-live" / "clients" / client_name / environment
        / "05-monitoring" / "terragrunt.hcl"
    )
    write_file_if_changed(live_unit, render_template("monitoring.hcl.template"))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(
            "Usage: python3 gcp-gke/02-scripts/scaffolding/scaffold_monitoring.py "
            "<path-to-infra-yaml>"
        )
    generate_monitoring_files(sys.argv[1])

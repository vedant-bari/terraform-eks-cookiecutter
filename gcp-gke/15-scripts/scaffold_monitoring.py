#!/usr/bin/env python3
import os
import sys
import yaml

def load_yaml(file_path):
    if not os.path.exists(file_path):
        print(f"❌ Error: Configuration file not found at {file_path}")
        sys.exit(1)
    with open(file_path, 'r') as f:
        return yaml.safe_load(f)

def render_template(template_name, config_rel_path):
    templates_dir = os.path.join(os.path.dirname(__file__), "templates")
    template_path = os.path.join(templates_dir, template_name)
    if not os.path.exists(template_path):
        print(f"❌ Error: Template file not found at {template_path}")
        sys.exit(1)
    with open(template_path, 'r') as f:
        template_content = f.read()
    
    return template_content.replace("$config_rel_path", config_rel_path)

def write_file_if_changed(file_path, content):
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            existing_content = f.read()
        if existing_content == content:
            print(f"  ⚡ Up to date: {os.path.basename(os.path.dirname(file_path))}")
            return
    with open(file_path, 'w') as f:
        f.write(content)
    print(f"  ✔ Created/Updated: {os.path.basename(file_path) or os.path.basename(os.path.dirname(file_path))}")

def generate_monitoring_files(config_path):
    config = load_yaml(config_path)
    client_name = config.get('client', {}).get('name')
    environment = config.get('environment', 'dev')
    
    if not client_name:
        print("❌ Error: 'client.name' is missing in the YAML configuration.")
        sys.exit(1)

    print(f"🚀 Processing monitoring & logging layout for client: '{client_name}' ({environment})...")

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    live_dir = os.path.join(repo_root, "03-live", "clients", client_name, environment)
    
    # Check if monitoring is enabled in config (default to True)
    monitoring_enabled = config.get('monitoring', {}).get('enabled', True)
    if not monitoring_enabled:
        print(f"ℹ️ Monitoring is disabled in the YAML config for {client_name}. Skipping.")
        return

    config_rel_path = f"../../../../../12-platform-config/clients/{client_name}/infra/{environment}.yaml"

    # Generate the Monitoring Layer (e.g., Layer 05-monitoring)
    monitoring_content = render_template("monitoring.hcl.template", config_rel_path)
    write_file_if_changed(os.path.join(live_dir, "05-monitoring", "terragrunt.hcl"), monitoring_content)

    print(f"🎉 Monitoring layout synchronization completed successfully for {client_name}!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_monitoring.py <path_to_infra_yaml>")
        sys.exit(1)
    generate_monitoring_files(sys.argv[1])
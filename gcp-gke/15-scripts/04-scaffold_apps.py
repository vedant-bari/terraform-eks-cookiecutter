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

def generate_apps_files(config_path):
    config = load_yaml(config_path)
    client_name = config.get('client', {}).get('name')
    environment = config.get('environment', 'dev')
    
    if not client_name:
        print("❌ Error: 'client.name' is missing in the YAML configuration.")
        sys.exit(1)

    print(f"🚀 Processing applications layout for client: '{client_name}' ({environment})...")

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    live_dir = os.path.join(repo_root, "03-live", "clients", client_name, environment)
    
    apps_enabled = config.get('apps', {}).get('enabled', False)
    if not apps_enabled:
        print(f"ℹ️ Applications layer is disabled in the YAML config for {client_name}. Skipping.")
        return

    config_rel_path = f"../../../../../12-platform-config/clients/{client_name}/infra/{environment}.yaml"

    # Generate the Applications Layer (06-apps)
    apps_content = render_template("apps.hcl.template", config_rel_path)
    write_file_if_changed(os.path.join(live_dir, "06-apps", "terragrunt.hcl"), apps_content)

    # Generate the Artifact Registry Layer (05-artifact-registry)
    artifact_content = render_template("artifact-registry.hcl.template", config_rel_path)
    write_file_if_changed(os.path.join(live_dir, "05-artifact-registry", "terragrunt.hcl"), artifact_content)

    print(f"🎉 Applications layout synchronization completed successfully for {client_name}!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_apps.py <path_to_infra_yaml>")
        sys.exit(1)
    generate_apps_files(sys.argv[1])
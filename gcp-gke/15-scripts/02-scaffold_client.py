#!/usr/bin/env python3
import os
import sys
import yaml
from string import Template

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
    
    # Safely replace only our target placeholder, leaving Terraform's ${...} syntax untouched
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
    print(f"  ✔ Created/Updated: {os.path.basename(os.path.dirname(file_path))}")

def generate_terragrunt_files(config_path):
    config = load_yaml(config_path)
    client_name = config.get('client', {}).get('name')
    environment = config.get('environment', 'dev')
    
    if not client_name:
        print("❌ Error: 'client.name' is missing in the YAML configuration.")
        sys.exit(1)

    print(f"🚀 Processing infrastructure layout for client: '{client_name}' ({environment})...")

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    live_dir = os.path.join(repo_root, "03-live", "clients", client_name, environment)
    
    vpc_enabled = config.get('vpc', {}).get('create', False)
    bastion_enabled = config.get('bastion', {}).get('create', False)
    filestore_enabled = config.get('storage', {}).get('create', False)
    jenkins_enabled = config.get('jenkins', {}).get('create', False)

    config_rel_path = f"../../../../../12-platform-config/clients/{client_name}/infra/{environment}.yaml"

    # 1. Bootstrap Layer
    bootstrap_content = render_template("bootstrap.hcl.template", config_rel_path)
    write_file_if_changed(os.path.join(live_dir, "01-bootstrap", "terragrunt.hcl"), bootstrap_content)

    # 2. VPC Layer
    if vpc_enabled:
        vpc_content = render_template("vpc.hcl.template", config_rel_path)
        write_file_if_changed(os.path.join(live_dir, "02-vpc", "terragrunt.hcl"), vpc_content)

    # # 3. Bastion Layer
    # if bastion_enabled:
    #     bastion_content = render_template("bastion.hcl.template", config_rel_path)
    #     write_file_if_changed(os.path.join(live_dir, "03-bastion", "terragrunt.hcl"), bastion_content)

    # 4. GKE Layer
    gke_content = render_template("gke.hcl.template", config_rel_path)
    write_file_if_changed(os.path.join(live_dir, "04-gke", "terragrunt.hcl"), gke_content)

    # 5. Storage Class Layer
    if filestore_enabled:
        storage_content = render_template("storage.hcl.template", config_rel_path)
        write_file_if_changed(os.path.join(live_dir, "07-storage-class", "terragrunt.hcl"), storage_content)

    # 10. Jenkins Layer
    if jenkins_enabled:
        jenkins_content = render_template("jenkins.hcl.template", config_rel_path)
        write_file_if_changed(os.path.join(live_dir, "10-jenkins", "terragrunt.hcl"), jenkins_content)

    print(f"🎉 Infrastructure layout synchronization completed successfully for {client_name}!")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_client.py <path_to_infra_yaml>")
        sys.exit(1)
    generate_terragrunt_files(sys.argv[1])
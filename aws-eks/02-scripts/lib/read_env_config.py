#!/usr/bin/env python3
"""Print the values the shell scripts need from an infra YAML, one per line.

Output order (consumed with `readarray`):
  1. account_id
  2. region
  3. profile            ("" = default credential chain)
  4. state bucket name  (derived as <client>-<env>-tfstate-<account_id> unless overridden)
  5. EKS cluster name   (derived as <client>-<env>-eks unless overridden)
  6. deploy role ARN    ("" when aws.assume_deploy_role is false)

Derivation rules must stay identical to aws-eks/04-live/root.hcl.
"""
import sys

import yaml


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: read_env_config.py <infra-yaml> <client> <env>", file=sys.stderr)
        return 2
    path, client, env = sys.argv[1:]
    with open(path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    aws = cfg.get("aws") or {}
    bootstrap = cfg.get("bootstrap") or {}
    eks = cfg.get("eks") or {}
    account_id = str(aws.get("account_id", "")).strip()
    region = str(aws.get("region", "")).strip()
    profile = str(aws.get("profile", "") or "").strip()
    bucket = str(bootstrap.get("state_bucket_name", "") or "").strip()
    if not bucket:
        bucket = f"{client}-{env}-tfstate-{account_id}"

    cluster = str(eks.get("cluster_name", "") or "").strip() or f"{client}-{env}-eks"
    role_name = str((bootstrap.get("deploy_role") or {}).get("name", "") or "").strip()
    role_name = role_name or f"{client}-{env}-terraform-deploy"
    assume = aws.get("assume_deploy_role", True)
    role_arn = f"arn:aws:iam::{account_id}:role/{role_name}" if assume else ""

    missing = [k for k, v in (("aws.account_id", account_id), ("aws.region", region)) if not v]
    if missing:
        print(f"Missing required keys in {path}: {', '.join(missing)}", file=sys.stderr)
        return 1

    for value in (account_id, region, profile, bucket, cluster, role_arn):
        print(value)
    return 0


if __name__ == "__main__":
    sys.exit(main())

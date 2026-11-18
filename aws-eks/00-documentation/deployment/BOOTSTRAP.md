# Bootstrap: state bucket and deploy role

Do this once for each client/environment, before any other layer. It needs credentials for the target account that are allowed to create S3 buckets, IAM roles, and set EBS default encryption. An admin SSO profile works.

## 1. Fill in the infra config

Edit `aws-eks/01-config/clients/<client>/<env>/infra/<env>.yaml`:

- `aws.account_id`: the 12-digit target account. The AWS provider refuses to run against any other account (`allowed_account_ids`).
- `aws.region`
- `aws.profile`: the SSO or CLI profile name. Set it to `""` to use the default credential chain.
- `aws.tags.Owner`, `aws.tags.CostCenter`, `budget.*`: replace every `CHANGE_ME`.

The state bucket name is derived as `<client>-<env>-tfstate-<account_id>` unless you set `bootstrap.state_bucket_name`.

## 2. Create the bucket

```bash
aws sso login --profile <profile>
./aws-eks/02-scripts/bootstrap/01-create-bootstrap-bucket.sh <client> <env>
```

The script:
- checks that your credentials belong to `aws.account_id`
- creates the bucket, or leaves an existing one in place
- blocks public access and enforces bucket-owner object ownership
- turns on versioning and SSE-S3 encryption
- applies the tags from the YAML file

It is safe to re-run.

## 3. Apply 00-bootstrap

```bash
terragrunt --working-dir aws-eks/04-live/clients/<client>/<env>/00-bootstrap run -- plan
terragrunt --working-dir aws-eks/04-live/clients/<client>/<env>/00-bootstrap run -- apply
```

The plan should show the following:
- **Import** of `aws_s3_bucket.tf_state`. An `import` block does this, so no manual `terragrunt import` is needed.
- **Create** of the bucket sub-resources: versioning, encryption, lifecycle (keep 5 noncurrent versions), ownership, public-access block, and a TLS-only bucket policy.
- **Create** of `aws_ebs_encryption_by_default`, if enabled.
- **Create** of the deploy role `<client>-<env>-terraform-deploy`. Every later layer assumes this role through the provider that `root.hcl` generates.

00-bootstrap stores its own state in the same bucket, under `aws-eks/<client>/<env>/bootstrap/terraform.tfstate`. The bucket has `prevent_destroy`, and `destroy-env.sh` never touches this layer.

## 4. Deploy the remaining layers

On a fresh environment, use `deploy-env.sh`. It plans each layer, shows the plan, asks you to type `yes`, then applies it, one layer at a time:

```bash
./aws-eks/02-scripts/deploy-env.sh <client> <env>
```

Once the environment exists, use the saved-plan flow instead:

```bash
./aws-eks/02-scripts/plan-env.sh <client> <env> [--layer <layer>]
./aws-eks/02-scripts/apply-env.sh <client> <env> --plan-dir <dir> --approve
```

## Offline validation

To validate without credentials or a bucket, set `AWS_EKS_OFFLINE=true`. This swaps in a throwaway local backend:

```bash
AWS_EKS_OFFLINE=true terragrunt --working-dir aws-eks/04-live/clients/<client>/<env>/<layer> run -- validate
```

Never run `plan` or `apply` in offline mode.

## Access the cluster (after 02-eks)

Cluster admin access uses EKS access entries (`authentication_mode = API`); there is no `aws-auth` ConfigMap.

- **Admins:** the deploy role is always a cluster admin. To add people, list their IAM role ARNs in `eks.admin_principal_arns`. For an SSO role, leave out the `aws-reserved/sso.amazonaws.com/` path.
- **Using the deploy role:** if you aren't in that list, set up kubectl through the deploy role:

```bash
aws eks update-kubeconfig --name <client>-<env>-eks --region <region> --profile <profile> \
  --role-arn arn:aws:iam::<account_id>:role/<client>-<env>-terraform-deploy
kubectl get nodes -o wide            # nodes in the private subnets of eks.node_azs
kubectl get pods -n kube-system      # aws-node, coredns, kube-proxy, eks-pod-identity-agent, metrics-server, ebs/efs CSI
kubectl get node -o jsonpath='{.items[0].status.allocatable.pods}'   # 110 with prefix delegation
```

## Verify storage (after 04-storage)

```bash
kubectl get sc        # gp3 (default) and <client>-<env>-rwx (efs.csi.aws.com)
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: rwx-test, namespace: default }
spec:
  accessModes: [ReadWriteMany]
  storageClassName: amex-prod-rwx
  resources: { requests: { storage: 1Gi } }
YAML
kubectl get pvc rwx-test        # Bound within seconds (an EFS access point is created)
kubectl delete pvc rwx-test     # Removes the access point
```

A gp3 PVC stays `Pending` until a pod uses it (`WaitForFirstConsumer`), which is expected.

## Verify cluster add-ons (after 05-cluster-addons)

```bash
kubectl -n kube-system get deploy aws-load-balancer-controller cluster-autoscaler
kubectl get ingressclass alb
kubectl -n kube-system get pods -l app=secrets-store-csi-driver   # ASCP add-on (from 02-eks)

# Ingress -> ALB (public subnets, IP targets). The address appears after 1-3 minutes.
kubectl create deployment echo --image=public.ecr.aws/nginx/nginx:stable --port=80
kubectl expose deployment echo --port=80
kubectl create ingress echo --class=alb --rule='/*=echo:80' \
  --annotation alb.ingress.kubernetes.io/scheme=internet-facing \
  --annotation alb.ingress.kubernetes.io/target-type=ip
kubectl get ingress echo -w

# Scale-out: requests more CPU than the nodes have, so new nodes join (up to max_size).
kubectl scale deployment echo --replicas=30
kubectl set resources deployment echo --requests=cpu=500m
kubectl -n kube-system logs deploy/cluster-autoscaler | grep -i "scale-up"

# Clean up: delete the Ingress first so the ALB is removed.
kubectl delete ingress echo && kubectl delete svc,deployment echo
```

## Destroy

`destroy-env.sh` destroys layers in reverse order and never touches `00-bootstrap`.

Before it destroys `05-cluster-addons`, or `02-eks` if the add-ons layer isn't there, it checks the cluster for Ingresses, `LoadBalancer` Services and PVCs. It refuses to continue while any remain.
- **Why it checks:** in-cluster controllers create the matching ALBs/NLBs, EBS volumes and EFS access points, and those aren't in Terraform state. Removing the controllers or the cluster first leaves them behind, and the VPC destroy then hangs on their network interfaces.
- **What usually trips it:** StatefulSet PVCs. Prometheus, Loki and Tempo keep their PVCs after their Helm releases are removed.

To clear them:

```bash
kubectl get ingress,svc,pvc -A
kubectl delete pvc -n monitoring --all     # after 06-monitoring is destroyed
```

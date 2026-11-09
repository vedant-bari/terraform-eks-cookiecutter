# AWS EKS examples

These manifests are optional smoke-test examples. Apply them only after the EKS cluster and corresponding CSI component are healthy.

- storage/ebs-pvc.yaml creates a 20 GiB ReadWriteOnce claim using the ebs-gp3 StorageClass.
- storage/efs-pvc.yaml creates a 5 GiB ReadWriteMany claim using the efs-sc StorageClass.

```bash
kubectl apply -f aws-eks/06-examples/storage/ebs-pvc.yaml
kubectl apply -f aws-eks/06-examples/storage/efs-pvc.yaml
kubectl get pvc -A
```

Delete the example claims when finished, keeping in mind the StorageClass reclaim policy controls what happens to dynamically provisioned backing storage.

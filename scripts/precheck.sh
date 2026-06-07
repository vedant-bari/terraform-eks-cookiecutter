#!/bin/bash
set -e
aws sts get-caller-identity >/dev/null
echo "AWS access verified"
aws eks describe-addon-versions --region ap-south-1 >/dev/null
echo "EKS service verified"

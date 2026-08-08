# 1. Create the new directory for applications and navigate into it
mkdir -p 13-kubernetes-apps/test-app/templates
cd 13-kubernetes-apps

# 2. Generate Chart.yaml
cat << 'EOF' > test-app/Chart.yaml
apiVersion: v2
name: eks-test-app
description: A Helm chart to test EKS, ALB Ingress, and EFS Persistent Storage
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF

# 3. Generate values.yaml
cat << 'EOF' > test-app/values.yaml
replicaCount: 2

image:
  repository: nginx
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80

ingress:
  enabled: true
  className: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'

storage:
  efsFileSystemId: "fs-xxxxxxxxxxxxxxxxx" # REPLACE ME BEFORE DEPLOYING
  capacity: 5Gi
EOF

# 4. Generate pv.yaml
cat << 'EOF' > test-app/templates/pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ include "eks-test-app.fullname" . }}-efs-pv
spec:
  capacity:
    storage: {{ .Values.storage.capacity }}
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: {{ .Values.storage.efsFileSystemId }}
EOF

# 5. Generate pvc.yaml
cat << 'EOF' > test-app/templates/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "eks-test-app.fullname" . }}-efs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: {{ .Values.storage.capacity }}
  volumeName: {{ include "eks-test-app.fullname" . }}-efs-pv
EOF

# 6. Generate deployment.yaml
cat << 'EOF' > test-app/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "eks-test-app.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "eks-test-app.fullname" . }}
  template:
    metadata:
      labels:
        app: {{ include "eks-test-app.fullname" . }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          volumeMounts:
            - name: efs-storage
              mountPath: /usr/share/nginx/html
      volumes:
        - name: efs-storage
          persistentVolumeClaim:
            claimName: {{ include "eks-test-app.fullname" . }}-efs-pvc
EOF

# 7. Generate service.yaml
cat << 'EOF' > test-app/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "eks-test-app.fullname" . }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: {{ include "eks-test-app.fullname" . }}
EOF

# 8. Generate ingress.yaml
cat << 'EOF' > test-app/templates/ingress.yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "eks-test-app.fullname" . }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "eks-test-app.fullname" . }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}
EOF

# 9. Generate _helpers.tpl
cat << 'EOF' > test-app/templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "eks-test-app.fullname" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
EOF

# 10. Zip the entire application folder
zip -r test-app.zip test-app

echo "======================================================="
echo "✅ SUCCESS: test-app.zip has been created in the 13-kubernetes-apps directory!"
echo "======================================================="
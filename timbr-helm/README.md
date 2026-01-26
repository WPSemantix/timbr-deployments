# Timbr Helm Chart

## Overview

This Helm chart deploys the Timbr platform on Kubernetes clusters across multiple cloud providers:
- **AWS EKS** (Elastic Kubernetes Service)
- **Azure AKS** (Azure Kubernetes Service)
- **GCP GKE** (Google Kubernetes Engine)
- **Generic Kubernetes** (any standard Kubernetes cluster)

The chart is designed to be cloud-agnostic with automatic configuration based on the specified cloud provider, particularly for ingress controllers and storage classes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Cloud Provider Deployment Guides](#cloud-provider-deployment-guides)
  - [AWS EKS Deployment](#aws-eks-deployment)
  - [Azure AKS Deployment](#azure-aks-deployment)
  - [GCP GKE Deployment](#gcp-gke-deployment)
  - [Generic Kubernetes Deployment](#generic-kubernetes-deployment)
- [Configuration](#configuration)
- [Component Overview](#component-overview)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### General Requirements
- Kubernetes cluster version 1.24+
- Helm 3.8+
- kubectl configured to access your cluster
- At least 16GB RAM and 4 CPUs available in your cluster
- Storage provisioner configured in your cluster

### Cloud-Specific Prerequisites
See the respective cloud provider sections below for additional requirements.

---

## Quick Start

```bash
# Add Timbr Helm repository (if available)
# helm repo add timbr https://charts.timbr.ai
# helm repo update

# Clone or download this chart
git clone https://github.com/WPSemantix/timbr-deployments.git
cd timbr-deployments/timbr-helm

# Install with default AWS configuration
helm install timbr . \
  --namespace timbr \
  --create-namespace

# Or specify a different cloud provider
helm install timbr . \
  --namespace timbr \
  --create-namespace \
  --set cloudProvider.type=azure
```

---

## Cloud Provider Deployment Guides

### AWS EKS Deployment

#### Prerequisites

1. **AWS CLI** installed and configured
2. **eksctl** installed (optional, for cluster creation)
3. **AWS Load Balancer Controller** installed in your EKS cluster
4. **EBS CSI Driver** installed (for EBS volume support)

#### Step 1: Create EKS Cluster (if needed)

```bash
eksctl create cluster \
  --name timbr-cluster \
  --region us-east-1 \
  --nodegroup-name timbr-nodes \
  --node-type t3.xlarge \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed
```

#### Step 2: Install AWS Load Balancer Controller

```bash
# Create IAM policy
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json

# Create IAM role and service account
eksctl create iamserviceaccount \
  --cluster=timbr-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install the controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=timbr-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### Step 3: Install EBS CSI Driver

```bash
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster timbr-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster timbr-cluster \
  --service-account-role-arn arn:aws:iam::<AWS_ACCOUNT_ID>:role/<IAM_ROLE_NAME> \
  --force
```

#### Step 4: (Optional) Request ACM Certificate for HTTPS

```bash
aws acm request-certificate \
  --domain-name timbr.example.com \
  --validation-method DNS \
  --region us-east-1
```

Note the certificate ARN for use in the values file.

#### Step 5: Create Image Pull Secret

```bash
kubectl create namespace timbr

kubectl create secret docker-registry timbr-registry-cred \
  --namespace timbr \
  --docker-server=timbr.azurecr.io \
  --docker-username=<YOUR_USERNAME> \
  --docker-password=<YOUR_PASSWORD>
```

#### Step 6: Create values-aws.yaml

```yaml
cloudProvider:
  type: aws

ingress:
  enabled: true
  host: "timbr.example.com"
  aws:
    scheme: internet-facing  # or internal
    targetType: ip
  tls:
    enabled: true
    source: acm
    certificateArn: "arn:aws:acm:us-east-1:123456789012:certificate/xxx"

mysql:
  persistence:
    size: 30Gi
    storageClassName: "gp3"  # or leave empty for auto-detection

components:
  cache:
    persistence:
      size: 50Gi
      storageClassName: "gp3"
  virtualization:
    persistence:
      size: 50Gi
      storageClassName: "gp3"
```

#### Step 7: Install Timbr

```bash
helm install timbr . \
  --namespace timbr \
  --values values-aws.yaml
```

#### Step 8: Get ALB DNS Name

```bash
kubectl get ingress -n timbr timbr-ingress

# Configure your DNS to point to the ALB DNS name
# Example: timbr.example.com -> CNAME -> k8s-timbr-xxxxx.us-east-1.elb.amazonaws.com
```

---

### Azure AKS Deployment

#### Prerequisites

1. **Azure CLI** installed and configured (`az login`)
2. **Azure Application Gateway Ingress Controller (AGIC)** or **NGINX Ingress Controller**
3. **Azure Key Vault** (optional, for TLS certificates)

#### Step 1: Create AKS Cluster (if needed)

```bash
# Create resource group
az group create --name timbr-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group timbr-rg \
  --name timbr-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --enable-addons monitoring \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group timbr-rg --name timbr-cluster
```

#### Step 2: Install Ingress Controller

**Option A: NGINX Ingress Controller (Recommended)**

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

**Option B: Application Gateway Ingress Controller**

```bash
# Create Application Gateway
az network public-ip create \
  --resource-group timbr-rg \
  --name timbr-agw-pip \
  --allocation-method Static \
  --sku Standard

az network application-gateway create \
  --name timbr-agw \
  --resource-group timbr-rg \
  --location eastus \
  --sku Standard_v2 \
  --public-ip-address timbr-agw-pip \
  --vnet-name <VNET_NAME> \
  --subnet <SUBNET_NAME>

# Install AGIC using Helm
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

# Follow Microsoft's AGIC installation guide for full setup
# https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-install-existing
```

#### Step 3: Create Image Pull Secret

```bash
kubectl create namespace timbr

kubectl create secret docker-registry timbr-registry-cred \
  --namespace timbr \
  --docker-server=timbr.azurecr.io \
  --docker-username=<YOUR_USERNAME> \
  --docker-password=<YOUR_PASSWORD>
```

#### Step 4: (Optional) Setup TLS with Azure Key Vault

```bash
# Create Key Vault
az keyvault create \
  --name timbr-keyvault \
  --resource-group timbr-rg \
  --location eastus

# Import or create certificate
az keyvault certificate import \
  --vault-name timbr-keyvault \
  --name timbr-cert \
  --file /path/to/certificate.pfx
```

#### Step 5: Create values-azure.yaml

**For NGINX Ingress:**

```yaml
cloudProvider:
  type: generic  # Use generic for NGINX on Azure

ingress:
  enabled: true
  className: nginx
  host: "timbr.example.com"
  tls:
    enabled: true
    source: secret
    secretName: timbr-tls-secret  # Create this secret manually

mysql:
  persistence:
    size: 30Gi
    storageClassName: "managed-csi"  # or leave empty

components:
  cache:
    persistence:
      size: 50Gi
      storageClassName: "managed-csi"
  virtualization:
    persistence:
      size: 50Gi
      storageClassName: "managed-csi"
```

**For Application Gateway Ingress:**

```yaml
cloudProvider:
  type: azure

ingress:
  enabled: true
  host: "timbr.example.com"
  azure:
    backendProtocol: http
    sslRedirect: true
    usePrivateIp: false
  tls:
    enabled: true
    source: keyvault
    azureKeyVault:
      secretId: "https://timbr-keyvault.vault.azure.net/secrets/timbr-cert"

mysql:
  persistence:
    size: 30Gi
    storageClassName: "managed-csi"

components:
  cache:
    persistence:
      size: 50Gi
  virtualization:
    persistence:
      size: 50Gi
```

#### Step 6: Create TLS Secret (if using NGINX with secret)

```bash
kubectl create secret tls timbr-tls-secret \
  --namespace timbr \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key
```

#### Step 7: Install Timbr

```bash
helm install timbr . \
  --namespace timbr \
  --values values-azure.yaml
```

#### Step 8: Get Load Balancer IP

```bash
# For NGINX
kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller

# For AGIC
kubectl get ingress -n timbr timbr-ingress

# Configure your DNS to point to the IP/hostname
```

---

### GCP GKE Deployment

#### Prerequisites

1. **Google Cloud SDK (gcloud)** installed and configured
2. **GKE Ingress** (default) or **NGINX Ingress Controller**
3. **Google Cloud Storage** and **Compute Engine** permissions

#### Step 1: Create GKE Cluster (if needed)

```bash
gcloud config set project <PROJECT_ID>

gcloud container clusters create timbr-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-4 \
  --disk-size 100 \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 5 \
  --enable-autorepair \
  --enable-autoupgrade

# Get credentials
gcloud container clusters get-credentials timbr-cluster --zone us-central1-a
```

#### Step 2: (Optional) Reserve Static IP Address

```bash
# For Global Load Balancer
gcloud compute addresses create timbr-ip --global

# Get the IP address
gcloud compute addresses describe timbr-ip --global
```

#### Step 3: (Optional) Create Managed Certificate

The chart will automatically create a ManagedCertificate resource when using GCP with TLS enabled.

#### Step 4: Create Image Pull Secret

```bash
kubectl create namespace timbr

kubectl create secret docker-registry timbr-registry-cred \
  --namespace timbr \
  --docker-server=timbr.azurecr.io \
  --docker-username=<YOUR_USERNAME> \
  --docker-password=<YOUR_PASSWORD>
```

#### Step 5: Create values-gcp.yaml

```yaml
cloudProvider:
  type: gcp

ingress:
  enabled: true
  host: "timbr.example.com"
  gcp:
    staticIpName: "timbr-ip"  # Name of reserved static IP
    globalStaticIp: true
  tls:
    enabled: true
    source: ""  # Managed certificate will be created automatically

mysql:
  persistence:
    size: 30Gi
    storageClassName: "standard-rwo"  # or "premium-rwo" or leave empty

components:
  cache:
    persistence:
      size: 50Gi
      storageClassName: "standard-rwo"
  virtualization:
    persistence:
      size: 50Gi
      storageClassName: "standard-rwo"
```

#### Step 6: Install Timbr

```bash
helm install timbr . \
  --namespace timbr \
  --values values-gcp.yaml
```

#### Step 7: Configure DNS

```bash
# Get the ingress IP address
kubectl get ingress -n timbr timbr-ingress

# Configure your DNS to point to this IP
# Example: timbr.example.com -> A record -> 34.120.XX.XX

# Note: GCP Managed Certificates can take 15-60 minutes to provision
```

---

### Generic Kubernetes Deployment

For any standard Kubernetes cluster (on-premises, other cloud providers, etc.), using NGINX Ingress Controller.

#### Prerequisites

1. Kubernetes cluster 1.24+
2. NGINX Ingress Controller installed
3. Storage provisioner configured

#### Step 1: Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

#### Step 2: Create Image Pull Secret

```bash
kubectl create namespace timbr

kubectl create secret docker-registry timbr-registry-cred \
  --namespace timbr \
  --docker-server=timbr.azurecr.io \
  --docker-username=<YOUR_USERNAME> \
  --docker-password=<YOUR_PASSWORD>
```

#### Step 3: Create TLS Secret (Optional)

```bash
kubectl create secret tls timbr-tls-secret \
  --namespace timbr \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key
```

#### Step 4: Create values-generic.yaml

```yaml
cloudProvider:
  type: generic

ingress:
  enabled: true
  className: nginx
  host: "timbr.example.com"
  tls:
    enabled: true
    source: secret
    secretName: timbr-tls-secret

mysql:
  persistence:
    size: 30Gi
    storageClassName: ""  # Use cluster default or specify your storage class

components:
  cache:
    persistence:
      size: 50Gi
      storageClassName: ""
  virtualization:
    persistence:
      size: 50Gi
      storageClassName: ""
```

#### Step 5: Install Timbr

```bash
helm install timbr . \
  --namespace timbr \
  --values values-generic.yaml
```

#### Step 6: Access Timbr

```bash
# Get the NGINX ingress external IP or hostname
kubectl get service -n ingress-nginx nginx-ingress-ingress-nginx-controller

# Configure your DNS to point to this IP/hostname
```

---

## Configuration

### Core Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cloudProvider.type` | Cloud provider type (`aws`, `azure`, `gcp`, `generic`) | `aws` |
| `namespaceOverride` | Override the namespace | `""` (uses release namespace) |
| `createNamespace` | Create namespace if it doesn't exist | `false` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class (auto-detected if empty) | `""` |
| `ingress.host` | Hostname for the ingress | `""` |
| `ingress.tls.enabled` | Enable TLS | `false` |
| `ingress.tls.source` | TLS source (`acm`, `keyvault`, `secret`) | `""` |

#### AWS-Specific Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.aws.scheme` | ALB scheme | `internet-facing` |
| `ingress.aws.targetType` | ALB target type | `ip` |

#### Azure-Specific Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.azure.backendProtocol` | Backend protocol | `http` |
| `ingress.azure.sslRedirect` | Enable SSL redirect | `false` |
| `ingress.azure.usePrivateIp` | Use private IP | `false` |

#### GCP-Specific Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.gcp.staticIpName` | Static IP name | `""` |
| `ingress.gcp.globalStaticIp` | Use global static IP | `false` |

### MySQL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mysql.enabled` | Deploy MySQL | `true` |
| `mysql.image` | MySQL image | `timbr.azurecr.io/timbr-mysql-8:latest` |
| `mysql.persistence.size` | MySQL storage size | `30Gi` |
| `mysql.persistence.storageClassName` | Storage class (auto-detected if empty) | `""` |

### Secrets Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secrets.create` | Create secrets | `true` |
| `secrets.data.mysqlRootPassword` | MySQL root password | `welcome` |
| `secrets.data.llmApiKey` | LLM API key | `""` |
| `secrets.data.oauthSecret` | OAuth secret | `""` |

### Component Configuration

Each component (`platform`, `api`, `server`, `mdx`, `ga`, `scheduler`, `cache`, `virtualization`) supports:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `components.<name>.enabled` | Enable component | `true` |
| `components.<name>.image` | Container image | (component-specific) |
| `components.<name>.replicas` | Number of replicas | `1` |
| `components.<name>.service.port` | Service port | (component-specific) |

---

## Component Overview

The Timbr platform consists of the following components:

- **timbr-mysql**: MySQL database for metadata storage
- **timbr-platform**: Main Timbr web interface (Superset-based)
- **timbr-server**: Timbr SQL server (Hive-compatible)
- **timbr-api**: REST API service
- **timbr-mdx**: MDX query service
- **timbr-ga**: Graph analytics service
- **timbr-scheduler**: Background job scheduler
- **timbr-cache**: Query caching service (ClickHouse-based)
- **timbr-virtualization**: Data virtualization service

---

## Upgrading

```bash
# Update the chart values
helm upgrade timbr . \
  --namespace timbr \
  --values values-<your-cloud>.yaml

# View upgrade history
helm history timbr -n timbr

# Rollback if needed
helm rollback timbr <REVISION> -n timbr
```

---

## Uninstalling

```bash
# Uninstall the release
helm uninstall timbr -n timbr

# Delete PVCs (if needed)
kubectl delete pvc -n timbr --all

# Delete namespace (if needed)
kubectl delete namespace timbr
```

---

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n timbr
kubectl describe pod <POD_NAME> -n timbr
kubectl logs <POD_NAME> -n timbr
```

### Check Ingress Status

```bash
kubectl get ingress -n timbr
kubectl describe ingress timbr-ingress -n timbr
```

### Check Storage

```bash
kubectl get pvc -n timbr
kubectl get pv
kubectl describe pvc <PVC_NAME> -n timbr
```

### Common Issues

#### Pods in Pending State
- Check if storage class is available: `kubectl get storageclass`
- Check node resources: `kubectl describe node`
- Check PVC status: `kubectl get pvc -n timbr`

#### Ingress Not Working
- Verify ingress controller is running:
  ```bash
  # For AWS
  kubectl get pods -n kube-system | grep aws-load-balancer-controller
  
  # For NGINX
  kubectl get pods -n ingress-nginx
  
  # For GKE
  kubectl get pods -n kube-system | grep l7-lb
  ```
- Check ingress annotations and class name
- Verify DNS is pointing to correct IP/hostname

#### Image Pull Errors
- Verify image pull secret exists: `kubectl get secret -n timbr timbr-registry-cred`
- Check secret is correctly configured in values.yaml
- Verify registry credentials are valid

#### Database Connection Issues
- Check MySQL pod is running: `kubectl get pod -n timbr -l app.kubernetes.io/component=mysql`
- Check MySQL logs: `kubectl logs -n timbr <mysql-pod-name>`
- Verify database password in secrets

---

## Support

For issues, questions, or contributions:
- GitHub: https://github.com/WPSemantix/timbr-deployments
- Documentation: https://docs.timbr.ai

---

## License

This Helm chart is provided by Timbr.ai and is subject to the Timbr license agreement.

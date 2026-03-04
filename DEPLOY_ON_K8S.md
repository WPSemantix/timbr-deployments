# Deploy Timbr with Kubernetes

This guide explains how to deploy Timbr on Kubernetes. Although you can customize your deployment by adding additional services, every deployment must include the following mandatory components:
- **timbr-mysql**
- **timbr-server**
- **timbr-platform**

---

## 1. Pre-Deployment Timbr Services Customization

Before you deploy, ensure your Kubernetes manifests are correctly configured. The following YAML files provide the base configuration for the mandatory services.

> **IMPORTANT**  
> For security, you must update the default values for the following environment variables in every service manifest where they appear. Do not use the provided defaults in production.
> 
> ```
>   - name: TIMBR_DB_USER
>     value: db_user
>   - name: TIMBR_DB_PASSWORD
>     value: db_pass
>   - name: MYSQL_ROOT_PASSWORD
>     value: db_pass
>   - name: DB_USERNAME
>     value: db_user
>   - name: DB_PASSWORD
>     value: db_pass    
> ```


### 1.1 Mandatory Services

#### timbr-mysql.yaml

This file creates a StatefulSet and Service for the MySQL database that stores Timbr metadata.

```yaml
kind: StatefulSet
apiVersion: apps/v1
metadata:
  name: timbr-mysql
  namespace: default
spec:
  podManagementPolicy: OrderedReady
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: timbr-mysql
  serviceName: timbr-mysql
  template:
    metadata:
      labels:
        app: timbr-mysql
    spec:
      containers:
        - name: timbr-mysql
          image: timbr.azurecr.io/timbr-mysql-8:latest
          ports:
            - containerPort: 3306
              protocol: TCP
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: db_pass
          resources:
            limits:
              memory: 2Gi
            requests:
              memory: 500Mi
          volumeMounts:
            - name: mysqldata
              mountPath: /var/lib/mysql/
              subPath: mysql
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      imagePullSecrets:
        - name: timbr-registry-cred
      restartPolicy: Always
      terminationGracePeriodSeconds: 10
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
  volumeClaimTemplates:
    - kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: mysqldata
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 30Gi
        volumeMode: Filesystem
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-mysql
  namespace: default
spec:
  ports:
    - name: timbr-mysql
      protocol: TCP
      port: 3306
      targetPort: 3306
  selector:
    app: timbr-mysql
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  internalTrafficPolicy: Cluster
```
You can deploy using a managed MySQL service such as Azure Database for MySQL, Amazon RDS for MySQL, or Amazon Aurora MySQL. 

> Ensure the database instance is configured with the following parameters:
> lower_case_table_names = 1
> group_concat_max_len = 8192000

These settings are required for proper application behavior and compatibility.


#### timbr-server.yaml

This file defines the Deployment and Service for the Timbr Server, which is the core backend engine that processes data requests.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-server
  namespace: default
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: timbr-server
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  template:
    metadata:
      labels:
        app: timbr-server
    spec:
      containers:
        - name: timbr
          image: timbr.azurecr.io/timbr-server-stable:latest
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
          ports:
            - containerPort: 11000
              protocol: TCP
          env:
            - name: TIMBR_DB_JDBC
              value: jdbc:mysql://timbr-mysql:3306
            - name: TIMBR_DB_JDBC_DRIVER
              value: com.mysql.jdbc.Driver
            - name: TIMBR_DB_JDBC_PARAMS
              value: useSSL=false
            - name: TIMBR_DB_USER
              value: db_user
            - name: TIMBR_DB_PASSWORD
              value: db_pass
            - name: TIMBR_CONNECTION_WORKER_THREADS
              value: '50'
            - name: TIMBR_OPERATION_WORKER_THREADS
              value: '25'
          resources:
            limits:
              memory: 4Gi
            requests:
              memory: 500Mi
          livenessProbe:
            httpGet:
              path: /health
              port: 11000
              scheme: HTTP
            initialDelaySeconds: 20
            timeoutSeconds: 28
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
      imagePullSecrets:
        - name: timbr-registry-cred
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-server
  namespace: default
spec:
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  internalTrafficPolicy: Cluster
  selector:
    app: timbr-server
  ports:
    - name: timbr-server
      protocol: TCP
      port: 11000
      targetPort: 11000
```

#### timbr-platform.yaml

This file deploys the Timbr Platform as a Deployment with an associated Service. The Timbr Platform provides the user interface and connects to the backend components, such as the MySQL database and Timbr Server.

> **IMPORTANT**
>
> If the Timbr Platform web server will run on `http` (instead of `https`) you need to add and change the following environment variables to the deployment manifest:
> 
> ```
> - name: FLASK_DEBUG
>   value: "1"
> - name: ENFORCE_SSL
>   value: '0'
> ```


```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-platform
  namespace: default
spec:
  replicas: 1
  progressDeadlineSeconds: 600
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: timbr-platform
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  template:
    metadata:
      labels:
        app: timbr-platform
    spec:
      containers:
        - name: timbr-platform
          image: timbr.azurecr.io/timbr-platform-stable:latest
          ports:
            - containerPort: 8088
              protocol: TCP
          env:
            - name: DB_CONNECTION
              value: mysql
            - name: DB_HOST
              value: timbr-mysql
            - name: DB_PORT
              value: '3306'
            - name: DB_DATABASE
              value: timbr_platform
            - name: DB_USERNAME
              value: db_user
            - name: DB_PASSWORD
              value: db_pass
            - name: SQLLAB_LIMIT
              value: '1000'
            - name: FLASK_ENV
              value: production
            - name: THRIFT_HOST
              value: timbr-server
            - name: ENFORCE_SSL
              value: '1'
          resources:
            limits:
              memory: 4Gi
            requests:
              memory: 500Mi
          livenessProbe:
            httpGet:
              path: /health
              port: 8088
              scheme: HTTP
            initialDelaySeconds: 20
            timeoutSeconds: 28
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 5
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      imagePullSecrets:
        - name: timbr-registry-cred
      restartPolicy: Always
      terminationGracePeriodSeconds: 35
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-platform
  namespace: default
spec:
  type: LoadBalancer
  sessionAffinity: None
  internalTrafficPolicy: Cluster
  ipFamilyPolicy: SingleStack
  ipFamilies:
    - IPv4
  selector:
    app: timbr-platform
  ports:
    - name: timbr-platform
      protocol: TCP
      port: 8088
      targetPort: 8088
```

## 2. Optional Services

You can extend your deployment with additional optional services. Here are one-line descriptions for each:

- **timbr-ingress:** Routes incoming traffic and load-balances requests for secure communication with Timbr backend services.
- **timbr-virtualization:** Combines data from multiple databases (or integrates with external engines like Apache Spark).
- **timbr-scheduler:** Automates tasks and schedules jobs.
- **timbr-cache:** Speeds up data retrieval by temporarily caching frequently used data.
- **timbr-mdx:** Lets you query Timbr with MDX (especially useful for Excel).
- **timbr-api:** Provides an API interface for custom integrations or to separate the UI from backend services.
- **timbr-ga:** Enables advanced analysis using graph algorithms.

---

## 3. Optional Services – Detailed Configurations

### 3.1 timbr-ingress

This configuration is intended for use with an already installed NGINX Ingress Controller.

#### 3.1.1 HTTP Connector

Deploy the following Ingress manifest:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 50m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
  name: timbr-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: <hostname_name>
      http:
        paths:
          - backend:
              service:
                name: timbr-platform
                port:
                  number: 8088
            path: /
            pathType: Prefix
          - backend:
              service:
                name: timbr-server
                port:
                  number: 11000
            path: /timbr-server
            pathType: Prefix
          - backend:
              service:
                name: timbr-server
                port:
                  number: 11000
            path: /hive2
            pathType: Prefix
          - backend:
              service:
                name: timbr-server
                port:
                  number: 11000
            path: /cliservice
            pathType: Prefix
          - path: /mdx
            pathType: Prefix
            backend:
              service:
                name: timbr-mdx
                port:
                  number: 13000
          - path: /timbr/openapi
            pathType: Prefix
            backend:
              service:
                name: timbr-api
                port:
                  number: 9000
          - path: /timbr/api
            pathType: Prefix
            backend:
              service:
                name: timbr-api
                port:
                  number: 9000
```

> **Important:** Replace `<hostname_name>` with your desired hostname.

#### 3.1.2 HTTPS Connector

To enable HTTPS, update the Timbr Platform manifest by setting `FLASK_DEBUG` to `"0"` and deploy the following Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 50m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
  name: timbr-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: <hostname_name>
      http:
        paths:
          - backend:
              service:
                name: timbr-platform
                port:
                  number: 8088
            path: /
            pathType: Prefix
          - backend:
              service:
                name: timbr-server
                port:
                  number: 11000
            path: /timbr-server
            pathType: Prefix
          - backend:
              service:
                name: timbr-server
                port:
                  number: 11000
            path: /hive2
            pathType: Prefix
          - backend:
              service:
                name: timbr-server
                port:
                  number: 11000
            path: /cliservice
            pathType: Prefix
          - path: /mdx
            pathType: Prefix
            backend:
              service:
                name: timbr-mdx
                port:
                  number: 13000
          - path: /timbr/openapi
            pathType: Prefix
            backend:
              service:
                name: timbr-api
                port:
                  number: 9000
          - path: /timbr/api
            pathType: Prefix
            backend:
              service:
                name: timbr-api
                port:
                  number: 9000
  tls:
    - hosts:
        - <hostname_name>
      secretName: <certificate-tls>
```

> **Important:** Replace `<hostname_name>` with your desired hostname and `<certificate-tls>` with your certificate secret name.

### 3.2 Additional Optional Services – Detailed Manifests

##### timbr-virtualization

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: timbr-virtualization-data
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30Gi
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-virtualization
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: timbr-virtualization
  template:
    metadata:
      labels:
        app: timbr-virtualization
    spec:
      volumes:
        - name: timbr-virtualization-data-volume
          persistentVolumeClaim:
            claimName: timbr-virtualization-data
      containers:
        - name: timbr-virtualization
          image: 'timbr.azurecr.io/timbr-virtualization-v2:latest'
          ports:
            - containerPort: 10000
              protocol: TCP
          env:
            - name: TIMBR_DB_JDBC
              value: jdbc:mysql://timbr-mysql:3306/timbr_metastore?useSSL=false
            - name: TIMBR_DB_JDBC_DRIVER
              value: com.mysql.jdbc.Driver
            - name: TIMBR_DB_USER
              value: db_user
            - name: TIMBR_DB_PASSWORD
              value: db_pass
          resources:
            limits:
              memory: 2Gi
            requests:
              memory: 500Mi
          volumeMounts:
            - name: timbr-virtualization-data-volume
              mountPath: /data/
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      imagePullSecrets:
        - name: timbr-registry-cred
      restartPolicy: Always
      terminationGracePeriodSeconds: 35
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-virtualization
  namespace: default
spec:
  type: ClusterIP
  sessionAffinity: None
  internalTrafficPolicy: Cluster
  ipFamilyPolicy: SingleStack
  ipFamilies:
    - IPv4
  ports:
    - name: timbr-virtualization
      protocol: TCP
      port: 10000
      targetPort: 10000
  selector:
    app: timbr-virtualization
```

##### timbr-scheduler

``` yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-scheduler
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: timbr-scheduler
  template:
    metadata:
      labels:
        app: timbr-scheduler
    spec:
      containers:
        - name: timbr
          image: timbr.azurecr.io/timbr-scheduler:latest
          env:
            - name: TIMBR_DB_HOST
              value: timbr-mysql
            - name: TIMBR_DB_SSL
              value: "false"
            - name: TIMBR_DB_USER
              value: db_user
            - name: TIMBR_DB_PASSWORD
              value: db_pass
            - name: PYTHONUNBUFFERED
              value: '1'
            - name: TIMBR_DB_NAME
              value: timbr_server
            - name: THRIFT_HOST
              value: timbr-server
          resources:
            limits:
              memory: 200Mi
            requests:
              memory: 50Mi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      imagePullSecrets:
        - name: timbr-registry-cred
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
```

##### timbr-cache

``` yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: timbr-cache-data
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  volumeMode: Filesystem
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-cache
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: timbr-cache
  template:
    metadata:
      labels:
        app: timbr-cache
        component: timbr-cache
    spec:
      volumes:
        - name: timbr-cache-data-volume
          persistentVolumeClaim:
            claimName: timbr-cache-data
        - name: host-sys
          hostPath:
            path: /sys
            type: ''
      initContainers:
        - name: timbr-cache-disable-thp
          image: timbr.azurecr.io/timbr-cache:latest
          command:
            - sh
            - '-c'
            - echo madvise >/host-sys/kernel/mm/transparent_hugepage/enabled
          volumeMounts:
            - name: host-sys
              mountPath: /host-sys
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      containers:
        - name: timbr-cache
          image: timbr.azurecr.io/timbr-cache:latest
          ports:
            - hostPort: 8123
              containerPort: 8123
              protocol: TCP
          volumeMounts:
            - name: timbr-cache-data-volume
              mountPath: /var/lib/clickhouse/
          imagePullPolicy: Always
          resources:
            limits:
              memory: 4Gi
            requests:
              memory: 1Gi
      restartPolicy: Always
      terminationGracePeriodSeconds: 40
      dnsPolicy: ClusterFirst
      securityContext: {}
      imagePullSecrets:
        - name: timbr-registry-cred
      schedulerName: default-scheduler
  strategy:
    type: Recreate
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 120
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-cache
  namespace: default
spec:
  ports:
    - name: timbr-cache
      protocol: TCP
      port: 8123
      targetPort: 8123
  selector:
    component: timbr-cache
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  internalTrafficPolicy: Cluster
```

##### timbr-mdx

``` yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-mdx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: timbr-mdx
  template:
    metadata:
      labels:
        app: timbr-mdx
    spec:
      containers:
        - name: timbr
          image: timbr.azurecr.io/timbr-mdx:latest
          ports:
            - containerPort: 13000
              protocol: TCP
          env:
            - name: TIMBR_DB_JDBC
              value: jdbc:mysql://timbr-mysql:3306
            - name: TIMBR_DB_JDBC_DRIVER
              value: com.mysql.jdbc.Driver
            - name: TIMBR_DB_JDBC_PARAMS
              value: useSSL=false
            - name: TIMBR_DB_USER
              value: db_user
            - name: TIMBR_DB_PASSWORD
              value: db_pass
            - name: TIMBR_DB_NAME
              value: timbr_server
            - name: TIMBR_PUBLIC_HOSTNAME
              value: timbr-server
          resources:
            limits:
              memory: 8Gi
            requests:
              memory: 500Mi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      imagePullSecrets:
        - name: timbr-registry-cred
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-mdx
  namespace: default
spec:
  ports:
    - name: timbr-mdx
      protocol: TCP
      port: 13000
      targetPort: 13000
  selector:
    app: timbr-mdx
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  internalTrafficPolicy: Cluster
```

##### timbr-api

``` yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: timbr-api
  template:
    metadata:
      labels:
        app: timbr-api
    spec:
      containers:
        - name: timbr-api
          image: timbr.azurecr.io/timbr-api:latest
          ports:
            - containerPort: 9000
              protocol: TCP
          env:
            - name: THRIFT_HOST
              value: timbr-server
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
          resources:
            limits:
              memory: 4Gi
            requests:
              memory: 500Mi
      restartPolicy: Always
      terminationGracePeriodSeconds: 95
      dnsPolicy: ClusterFirst
      securityContext: {}
      imagePullSecrets:
        - name: timbr-registry-cred
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-api
  namespace: default
spec:
  ports:
    - name: timbr-api
      protocol: TCP
      port: 9000
      targetPort: 9000
  selector:
    app: timbr-api
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  internalTrafficPolicy: Cluster
```

##### timbr-ga

``` yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: timbr-ga
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: timbr-ga
  template:
    metadata:
      labels:
        app: timbr-ga
    spec:
      containers:
        - name: timbr
          image: timbr.azurecr.io/timbr-ga:latest
          ports:
            - containerPort: 12000
              protocol: TCP
          env:
            - name: TIMBR_DB_JDBC
              value: jdbc:mysql://timbr-mysql:3306/
            - name: TIMBR_DB_JDBC_DRIVER
              value: com.mysql.jdbc.Driver
            - name: TIMBR_DB_JDBC_PARAMS
              value: useSSL=false
            - name: TIMBR_DB_USER
              value: db_user
            - name: TIMBR_DB_PASSWORD
              value: db_pass
            - name: PYTHONUNBUFFERED
              value: '1'
            - name: TIMBR_DB_NAME
              value: timbr_server
            - name: THRIFT_HOST
              value: timbr-server
          resources:
            limits:
              memory: 4Gi
            requests:
              memory: 50Mi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      imagePullSecrets:
        - name: timbr-registry-cred
      schedulerName: default-scheduler
---
kind: Service
apiVersion: v1
metadata:
  name: timbr-ga
  namespace: default
spec:
  ports:
    - name: timbr-ga
      protocol: TCP
      port: 12000
      targetPort: 12000
  selector:
    app: timbr-ga
  type: ClusterIP
  sessionAffinity: None
```

## 4. Timbr Deployment Process

Follow these steps to deploy Timbr on your Kubernetes environment:

1. **Login to Timbr's Docker Repository:**

Create the secret called `timbr-registry-cred` using your Docker registry credentials:
```bash
kubectl create secret docker-registry timbr-registry-cred \
  --docker-server=timbr.azurecr.io \
  --namespace=default \
  --docker-username=<app-id> \
  --docker-password=<key>
```
Replace `<app-id>` and `<key>` with your appropriate Docker credentials.

2. **Apply the YAML Manifests:**

Deploy the required YAML files by running:
``` bash
kubectl apply -f timbr-mysql.yaml
kubectl apply -f timbr-server.yaml
kubectl apply -f timbr-platform.yaml
```
Then deploy any optional service manifests (e.g., `timbr-ingress.yaml`, `timbr-virtualization.yaml`, etc.) as needed.


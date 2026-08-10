# Deploy Timbr with PostgreSQL 17

This guide explains how to run Timbr with **PostgreSQL 17** as its metadata database instead of MySQL. It covers all three deployment methods - Kubernetes manifests, Docker Compose, and the Timbr Helm chart.

The choice of metadata database does not change what Timbr can do. Every service behaves the same; only the connection settings differ. Every deployment must still include the three mandatory components:
- **timbr-postgres** (instead of **timbr-mysql**)
- **timbr-server**
- **timbr-platform**

> **Note:** If you are deploying with MySQL, use [Deploy Timbr with Kubernetes](./DEPLOY_ON_K8S.md) or [Deploy Timbr with Docker Compose](./DEPLOY_ON_DOCKER.md) instead. Optional-service configurations that are not database-specific (SSO, Key Vault, JWT, chat bot, MCP OAuth) are documented in [Optional Services for Deployment with Timbr](./DEPLOYMENTS_OPTIONAL_SERVICES.md) and apply to both backends.

---

## 1. When to Use PostgreSQL

Choose PostgreSQL if your organization already standardizes on it, if your database team's backup, monitoring, and high-availability tooling is built around it, or if you intend to use a managed PostgreSQL service such as Azure Database for PostgreSQL, Amazon RDS, or Google Cloud SQL.

Otherwise MySQL remains the default and is the more widely tested path.

> **Note about sample maturity**
>
> The `timbr-postgres`, `timbr-server`, `timbr-platform`, and `timbr-api` configurations in this guide are transcribed from a running PostgreSQL-backed deployment.
>
> The `timbr-mdx`, `timbr-ga`, `timbr-scheduler`, and `timbr-virtualization` configurations are translated from their MySQL equivalents and have not been validated end-to-end against PostgreSQL. Test them in a non-production environment first, and contact the Timbr team if a service fails to reach the database.

---

## 2. How PostgreSQL Differs from MySQL

The most important structural difference: under MySQL, Timbr uses **two separate databases** (`timbr_platform` and `timbr_server`). Under PostgreSQL it uses **one database** named `timbr` containing **two schemas** with those same names. This is why the PostgreSQL configuration has schema variables that have no MySQL counterpart.

| Setting | MySQL | PostgreSQL 17 |
| --- | --- | --- |
| Database image | `timbr.azurecr.io/timbr-mysql-8:latest` | `timbr.azurecr.io/timbr-postgres:latest` |
| Port | `3306` | `5432` |
| Data directory | `/var/lib/mysql/` | `/var/lib/postgresql/data/` |
| Logical layout | two databases | one database, two schemas |
| **TIMBR_DB_JDBC** | `jdbc:mysql://timbr-mysql:3306` | `jdbc:postgresql://timbr-postgres:5432/timbr` |
| **TIMBR_DB_JDBC_DRIVER** | `com.mysql.jdbc.Driver` | `org.postgresql.Driver` |
| **TIMBR_DB_JDBC_PARAMS** | `useSSL=false` | *not used - omit this variable* |
| **DB_CONNECTION** | `mysql` | `postgresql+psycopg2` |
| **DB_DATABASE** | `timbr_platform` | `timbr` |
| **IS_POSTGRES_DB** | *not used* | `true` |
| **POSTGRES_SCHEMA_NAME** | *not used* | `timbr_platform` |
| **TIMBR_SERVER_SCHEMA** | *not used* | `timbr_server` |

Three things are easy to get wrong:

1. **The database name belongs in the JDBC URL.** MySQL connections omit it; PostgreSQL connections must end in `/timbr`.
2. **`TIMBR_DB_JDBC_PARAMS` must be removed.** `useSSL=false&allowPublicKeyRetrieval=true` are MySQL driver options. Passing them to the PostgreSQL driver breaks the connection.
3. **`IS_POSTGRES_DB` must be set to `true`** on `timbr-platform` and `timbr-api`. Without it those services still assume MySQL semantics even when `DB_CONNECTION` says otherwise.

> **IMPORTANT**  
> For security, you must update the default values for the following environment variables in every service manifest where they appear. Do not use the provided defaults in production.
>
> ```
>   - name: TIMBR_DB_USER
>     value: postgres
>   - name: TIMBR_DB_PASSWORD
>     value: db_pass
>   - name: POSTGRES_DB_USER
>     value: postgres
>   - name: POSTGRES_DB_PASSWORD
>     value: db_pass
>   - name: DB_USERNAME
>     value: postgres
>   - name: DB_PASSWORD
>     value: db_pass
> ```

---

## 3. Deploy on Kubernetes with PostgreSQL

The manifests below are available in [`k8s-sample-files/postgres/`](k8s-sample-files/postgres). They are drop-in replacements for the files in `k8s-sample-files/` - the service names, ports, and labels are unchanged, so anything that already points at `timbr-server` or `timbr-platform` keeps working.

### 3.1 Mandatory Services

#### timbr-postgres.yaml

This file creates a StatefulSet and Service for the PostgreSQL 17 database that stores Timbr metadata. The image bootstraps the `timbr` database and its `timbr_platform` and `timbr_server` schemas the first time it starts.

```yaml
kind: StatefulSet
apiVersion: apps/v1
metadata:
  name: timbr-postgres
  namespace: default
spec:
  podManagementPolicy: OrderedReady
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: timbr-postgres
  serviceName: timbr-postgres
  template:
    metadata:
      labels:
        app: timbr-postgres
    spec:
      containers:
        - name: timbr-postgres
          image: timbr.azurecr.io/timbr-postgres:latest
          ports:
            - containerPort: 5432
              protocol: TCP
          env:
            - name: DB_CONNECTION
              value: postgresql+psycopg2
            - name: DB_HOST
              value: localhost
            - name: DB_PORT
              value: '5432'
            - name: POSTGRES_DB_NAME
              value: timbr
            - name: POSTGRES_SCHEMA_NAME
              value: timbr_platform
            - name: POSTGRES_DB_USER
              value: postgres
            - name: POSTGRES_DB_PASSWORD
              value: db_pass
          resources:
            limits:
              memory: 2Gi
            requests:
              memory: 500Mi
          volumeMounts:
            - name: postgresdata
              mountPath: /var/lib/postgresql/data/
              subPath: postgres
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
        name: postgresdata
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
  name: timbr-postgres
  namespace: default
spec:
  ports:
    - name: timbr-postgres
      protocol: TCP
      port: 5432
      targetPort: 5432
  selector:
    app: timbr-postgres
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  internalTrafficPolicy: Cluster
```

> **Note:** `DB_HOST` is `localhost` here because the value is consumed by the database container itself, not by a client connecting to it.

#### timbr-server.yaml

The core engine. Note the PostgreSQL JDBC URL with `/timbr` at the end, the `org.postgresql.Driver` driver, and the absence of `TIMBR_DB_JDBC_PARAMS`.

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
              value: jdbc:postgresql://timbr-postgres:5432/timbr
            - name: TIMBR_DB_JDBC_DRIVER
              value: org.postgresql.Driver
            - name: TIMBR_DB_USER
              value: postgres
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

The web interface. This is where `IS_POSTGRES_DB`, `POSTGRES_SCHEMA_NAME`, and `TIMBR_SERVER_SCHEMA` are required.

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
            - name: IS_POSTGRES_DB
              value: 'true'
            - name: DB_CONNECTION
              value: postgresql+psycopg2
            - name: DB_HOST
              value: timbr-postgres
            - name: DB_PORT
              value: '5432'
            - name: DB_DATABASE
              value: timbr
            - name: DB_USERNAME
              value: postgres
            - name: DB_PASSWORD
              value: db_pass
            - name: POSTGRES_SCHEMA_NAME
              value: timbr_platform
            - name: TIMBR_SERVER_SCHEMA
              value: timbr_server
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

### 3.2 Optional Services

These manifests live in [`k8s-sample-files/postgres/optional-services/`](k8s-sample-files/postgres/optional-services).

Two optional services need no PostgreSQL-specific changes at all and can be taken directly from the MySQL samples:

- **timbr-cache** - [`k8s-sample-files/optional-services/timbr-cache/`](k8s-sample-files/optional-services/timbr-cache) (no database connection)
- **timbr-ingress** - [`k8s-sample-files/optional-services/timbr-ingress/`](k8s-sample-files/optional-services/timbr-ingress) (routes HTTP traffic only)

##### timbr-api

Under MySQL, `timbr-api` needs only `THRIFT_HOST`. Under PostgreSQL it connects to the database directly and needs the full connection block.

```yaml
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
            - name: IS_POSTGRES_DB
              value: 'true'
            - name: DB_CONNECTION
              value: postgresql+psycopg2
            - name: DB_HOST
              value: timbr-postgres
            - name: DB_PORT
              value: '5432'
            - name: DB_DATABASE
              value: timbr
            - name: DB_USERNAME
              value: postgres
            - name: DB_PASSWORD
              value: db_pass
            - name: POSTGRES_SCHEMA_NAME
              value: timbr_platform
            - name: TIMBR_SERVER_SCHEMA
              value: timbr_server
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

##### timbr-mdx

`TIMBR_DB_NAME` names the Timbr server **schema** under PostgreSQL, not a separate database.

```yaml
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
              value: jdbc:postgresql://timbr-postgres:5432/timbr
            - name: TIMBR_DB_JDBC_DRIVER
              value: org.postgresql.Driver
            - name: TIMBR_DB_USER
              value: postgres
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

##### timbr-scheduler

The scheduler connects with discrete host and port variables rather than a JDBC URL. `TIMBR_DB_PORT` must be set explicitly, because the service otherwise assumes the MySQL default of `3306`.

```yaml
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
              value: timbr-postgres
            - name: TIMBR_DB_PORT
              value: '5432'
            - name: TIMBR_DB_SSL
              value: "false"
            - name: TIMBR_DB_USER
              value: postgres
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

##### timbr-ga

```yaml
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
              value: jdbc:postgresql://timbr-postgres:5432/timbr
            - name: TIMBR_DB_JDBC_DRIVER
              value: org.postgresql.Driver
            - name: TIMBR_DB_USER
              value: postgres
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

##### timbr-virtualization

Under MySQL the Hive metastore lives in its own `timbr_metastore` database. Under PostgreSQL it becomes a **schema** inside the shared `timbr` database, selected with the `currentSchema` JDBC parameter.

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
              value: jdbc:postgresql://timbr-postgres:5432/timbr?currentSchema=timbr_metastore
            - name: TIMBR_DB_JDBC_DRIVER
              value: org.postgresql.Driver
            - name: TIMBR_DB_USER
              value: postgres
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

---

## 4. Deploy with Docker Compose and PostgreSQL

The Compose files below are available in [`docker-compose-sample-files/postgres/`](docker-compose-sample-files/postgres).

As in the MySQL samples, the database container is named `timbr-db` and every other service reaches it by that name over the `timbr-net` bridge network.

### 4.1 Mandatory Services

This is the complete base stack - `timbr-db`, `timbr-server`, and `timbr-platform`.

```yaml
services:
  timbr-db:
    image: timbr.azurecr.io/timbr-postgres:latest
    container_name: timbr-db
    environment:
      - DB_CONNECTION=postgresql+psycopg2
      - DB_HOST=localhost
      - DB_PORT=5432
      - POSTGRES_DB_NAME=timbr
      - POSTGRES_SCHEMA_NAME=timbr_platform
      - POSTGRES_DB_USER=postgres
      - POSTGRES_DB_PASSWORD=db_pass
    restart: always
    networks:
      - timbr-net
    volumes:
      - db-volume:/var/lib/postgresql/data/
  timbr-server:
    image: timbr.azurecr.io/timbr-server-stable:latest
    container_name: timbr-server
    environment:
      - TIMBR_DB_JDBC=jdbc:postgresql://timbr-db:5432/timbr
      - TIMBR_DB_JDBC_DRIVER=org.postgresql.Driver
      - TIMBR_DB_USER=postgres
      - TIMBR_DB_PASSWORD=db_pass
      - TIMBR_CONNECTION_WORKER_THREADS=100
      - TIMBR_OPERATION_WORKER_THREADS=100
      - TIMBR_INIT_MEMORY=-Xms256m
      - TIMBR_MAX_MEMORY=-Xmx4096m
    restart: always
    networks:
      - timbr-net
    ports:
      - "11000:11000"
    depends_on:
      - timbr-db
  timbr-platform:
    image: timbr.azurecr.io/timbr-platform-stable:latest
    container_name: timbr-platform
    environment:
      - IS_POSTGRES_DB=true
      - DB_CONNECTION=postgresql+psycopg2
      - DB_HOST=timbr-db
      - DB_PORT=5432
      - DB_DATABASE=timbr
      - DB_USERNAME=postgres
      - DB_PASSWORD=db_pass
      - POSTGRES_SCHEMA_NAME=timbr_platform
      - TIMBR_SERVER_SCHEMA=timbr_server
      - SQLLAB_LIMIT=1000
      - FLASK_ENV=production
      - THRIFT_HOST=timbr-server
      - ENFORCE_SSL=1
    networks:
      - timbr-net
    restart: always
    ports:
      - "8088:8088"
    depends_on:
      - timbr-db

networks:
  timbr-net:
    driver: bridge

volumes:
  db-volume:
```

### 4.2 Optional Services

Append any of these to the base file, or pass them as extra `-f` arguments. **timbr-proxy** and **timbr-cache** need no PostgreSQL changes - use the existing files in [`docker-compose-sample-files/optional-services/`](docker-compose-sample-files/optional-services).

#### timbr-api

```yaml
services:
  timbr-api:
    image: timbr.azurecr.io/timbr-api:latest
    container_name: timbr-api
    environment:
      - THRIFT_HOST=timbr-server
      - IS_POSTGRES_DB=true
      - DB_CONNECTION=postgresql+psycopg2
      - DB_HOST=timbr-db
      - DB_PORT=5432
      - DB_DATABASE=timbr
      - DB_USERNAME=postgres
      - DB_PASSWORD=db_pass
      - POSTGRES_SCHEMA_NAME=timbr_platform
      - TIMBR_SERVER_SCHEMA=timbr_server
    ports:
      - "9000:9000"
    networks:
      - timbr-net
    restart: always
```

#### timbr-mdx

```yaml
services:
  timbr-mdx:
    image: timbr.azurecr.io/timbr-mdx:latest
    container_name: timbr-mdx
    environment:
      - TIMBR_DB_JDBC=jdbc:postgresql://timbr-db:5432/timbr
      - TIMBR_DB_JDBC_DRIVER=org.postgresql.Driver
      - TIMBR_DB_USER=postgres
      - TIMBR_DB_PASSWORD=db_pass
      - TIMBR_DB_NAME=timbr_server
      - TIMBR_PUBLIC_HOSTNAME=timbr-server
    ports:
      - "13000:13000"
    networks:
      - timbr-net
    restart: always
```

#### timbr-ga

```yaml
services:
  timbr-ga:
    image: timbr.azurecr.io/timbr-ga:latest
    container_name: timbr-ga
    environment:
      - TIMBR_DB_JDBC=jdbc:postgresql://timbr-db:5432/timbr
      - TIMBR_DB_JDBC_DRIVER=org.postgresql.Driver
      - TIMBR_DB_USER=postgres
      - TIMBR_DB_PASSWORD=db_pass
      - TIMBR_DB_NAME=timbr_server
      - THRIFT_HOST=timbr-server
    networks:
      - timbr-net
    depends_on:
      - timbr-db
```

#### timbr-scheduler

```yaml
services:
  timbr-scheduler:
    image: timbr.azurecr.io/timbr-scheduler:latest
    container_name: timbr-scheduler
    environment:
      - TIMBR_DB_HOST=timbr-db
      - TIMBR_DB_PORT=5432
      - TIMBR_DB_SSL="false"
      - TIMBR_DB_USER=postgres
      - TIMBR_DB_PASSWORD=db_pass
      - PYTHONUNBUFFERED=1
      - TIMBR_DB_NAME=timbr_server
      - THRIFT_HOST=timbr-server
    restart: always
    networks:
      - timbr-net
```

#### timbr-virtualization

```yaml
services:
  timbr-virtualization:
    image: timbr.azurecr.io/timbr-virtualization-v2:latest
    container_name: timbr-virtualization
    environment:
      - TIMBR_DB_JDBC=jdbc:postgresql://timbr-db:5432/timbr?currentSchema=timbr_metastore
      - TIMBR_DB_JDBC_DRIVER=org.postgresql.Driver
      - TIMBR_DB_USER=postgres
      - TIMBR_DB_PASSWORD=db_pass
    restart: always
    networks:
      - timbr-net
    depends_on:
      - timbr-db
    volumes:
      - virtualization-volume:/data/

volumes:
  virtualization-volume:
```

---

## 5. Deploy with the Timbr Helm Chart and PostgreSQL

The [Timbr Helm chart](timbr-helm/) supports both backends through a single `db.type` switch. Setting it to `postgres` changes the JDBC URL scheme, the driver, the SQLAlchemy dialect, and adds `IS_POSTGRES_DB`, `POSTGRES_SCHEMA_NAME`, and `TIMBR_SERVER_SCHEMA` wherever they are needed. You do not have to set those variables yourself.

Create a `values-postgres.yaml`:

```yaml
cloudProvider:
  type: azure          # aws | azure | gcp | generic

db:
  type: postgres

# Turn off the MySQL StatefulSet and turn on the PostgreSQL one
mysql:
  enabled: false

postgres:
  enabled: true
  persistence:
    size: 30Gi
    storageClassName: managed-csi   # gp3 (AWS), managed-csi (Azure), standard-rwo (GCP)

secrets:
  create: true
  data:
    postgresPassword: "<your-database-password>"

ingress:
  enabled: true
  host: timbr.example.com
```

Install it:

```bash
helm install timbr ./timbr-helm --namespace timbr --create-namespace --values values-postgres.yaml
```

Everything derived from `db.type` can still be overridden explicitly. The values that matter most:

| Parameter | Description | Default |
| --- | --- | --- |
| `db.type` | Metadata database backend: `mysql` or `postgres` | `mysql` |
| `db.host` | Database hostname | `mysql.name` / `postgres.name` |
| `db.port` | Database port | `3306` / `5432` |
| `db.user` | Database user | `root` / `postgres` |
| `db.database` | Single PostgreSQL database holding every schema | `timbr` |
| `db.schema` | Platform schema (`POSTGRES_SCHEMA_NAME`) | `timbr_platform` |
| `db.serverSchema` | Server schema (`TIMBR_SERVER_SCHEMA`) | `timbr_server` |
| `db.metastoreSchema` | Virtualization metastore schema | `timbr_metastore` |
| `db.passwordSecretKey` | Key in the shared secret holding the password | `postgresPassword` |
| `postgres.enabled` | Deploy the in-cluster PostgreSQL StatefulSet | `false` |
| `postgres.image` | PostgreSQL 17 image | `timbr.azurecr.io/timbr-postgres:latest` |
| `postgres.persistence.size` | Volume size for the database | `30Gi` |

> **Note:** `mysql.enabled` and `postgres.enabled` are additionally gated on `db.type`, so the wrong StatefulSet can never be rendered by mistake. Setting `db.type: postgres` while leaving `mysql.enabled: true` simply produces no MySQL resources.

See [timbr-helm/README.md](timbr-helm/README.md) for the full per-cloud walkthroughs and the complete parameter reference.

---

## 6. Timbr Deployment Process

Follow these steps to deploy Timbr with PostgreSQL on Kubernetes:

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
```bash
kubectl apply -f timbr-postgres.yaml
kubectl apply -f timbr-server.yaml
kubectl apply -f timbr-platform.yaml
```

Wait for `timbr-postgres` to report `Running` before the other services start, so the database finishes creating its schemas:
```bash
kubectl rollout status statefulset/timbr-postgres
```

Then deploy any optional service manifests (e.g., `timbr-ingress.yaml`, `timbr-api.yaml`, etc.) as needed.

3. **Verify the database:**

```bash
kubectl exec -it timbr-postgres-0 -- psql -U postgres -d timbr -c "\dn"
```
The output should list the `timbr_platform` and `timbr_server` schemas.

For Docker Compose, start the stack from the folder holding your Compose file:
```bash
docker compose up -d
```

---

## 7. Using a Managed PostgreSQL Service

Instead of running PostgreSQL inside your cluster you can point Timbr at a managed instance such as Azure Database for PostgreSQL Flexible Server, Amazon RDS or Aurora PostgreSQL, or Google Cloud SQL for PostgreSQL.

> **IMPORTANT - a seed file and an initialization script are required**
>
> The `timbr.azurecr.io/timbr-postgres` image is not a stock PostgreSQL image. On first start it creates the `timbr` database, its `timbr_platform` and `timbr_server` schemas, and Timbr's initial metadata.
>
> A managed PostgreSQL instance starts out empty and does none of this. Before you start `timbr-server` and `timbr-platform` against a managed instance you must obtain the **seed file** and **initialization script** from the Timbr team and run them against your instance. They are not distributed in this repository.
>
> Contact [support@timbr.ai](mailto:support@timbr.ai) to request them, and mention the PostgreSQL version of your managed instance.

Once the instance is seeded:

1. **Do not deploy the database workload.** Skip `timbr-postgres.yaml` entirely, or with Helm set:

   ```yaml
   db:
     type: postgres
     host: my-timbr-db.postgres.database.azure.com
     port: 5432
     user: timbr_admin
   mysql:
     enabled: false
   postgres:
     enabled: false     # no in-cluster StatefulSet
   ```

2. **Point every service at the managed endpoint.** In the raw manifests, replace `timbr-postgres` with your instance's FQDN in `DB_HOST`, `TIMBR_DB_HOST`, and the `TIMBR_DB_JDBC` URL:

   ```
   jdbc:postgresql://my-timbr-db.postgres.database.azure.com:5432/timbr
   ```

3. **Enable TLS.** Managed services normally require encrypted connections. Append `sslmode=require` to the JDBC URL:

   ```
   jdbc:postgresql://my-timbr-db.postgres.database.azure.com:5432/timbr?sslmode=require
   ```

   With Helm, set `db.jdbcParams: "sslmode=require"`.

   If your provider uses a certificate authority that is not in the default Java truststore, mount a truststore containing the provider CA into the `timbr-server` container at `/usr/local/openjdk-11/lib/security/`:

   ```yaml
       spec:
         volumes:
           - name: timbr-cacerts
             secret:
               secretName: timbr-cacerts
               items:
                 - key: cacerts
                   path: cacerts
         containers:
           - name: timbr
             volumeMounts:
               - name: timbr-cacerts
                 mountPath: /usr/local/openjdk-11/lib/security/
   ```

4. **Open network access.** Allow traffic from your cluster's egress addresses using a private endpoint, VNet or VPC integration, or the provider's firewall rules. An in-cluster deployment needs none of this; a managed one always does.

5. **Store the credentials as a secret.** Managed instances use real credentials rather than the `db_pass` placeholder. With Helm, put the password in `secrets.data.postgresPassword` or reference your own secret with `secrets.existingSecretName`. With raw manifests, replace the literal `value: db_pass` with a `secretKeyRef`.

> **Note:** Managed instances usually enforce a maximum connection count well below what MySQL deployments assume. If you see connection-pool exhaustion, lower `TIMBR_CONNECTION_WORKER_THREADS` and `TIMBR_OPERATION_WORKER_THREADS` on `timbr-server`.

---

## 8. Final Notes and Support

- Sample credentials in this guide (`db_pass`) are placeholders. Replace them everywhere before deploying.
- Optional-service configuration that is not database-specific - SSO, Azure AD, Key Vault, JWT, the Microsoft Teams and Slack chat bot, and MCP OAuth - is documented in [Optional Services for Deployment with Timbr](./DEPLOYMENTS_OPTIONAL_SERVICES.md).
- The authoritative environment-variable reference for `timbr-server` and `timbr-platform` is in [README.md](./README.md).

If you need assistance, contact [support@timbr.ai](mailto:support@timbr.ai).

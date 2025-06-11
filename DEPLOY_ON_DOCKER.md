# Deploy Timbr with Docker Compose

This guide explains how to deploy Timbr using Docker Compose. While you can customize your deployment by adding extra services, every deployment must include the following mandatory services:
- **timbr-db**
- **timbr-server**
- **timbr-platform**

---

## 1. Pre-Deployment Customization

Before running your deployment, it’s important to understand the three sections of your `docker-compose.yaml` file:
- **services:** Lists all service containers (mandatory and optional) that will run.
- **networks:** Configures the network for inter-container communication.
- **volumes:** Defines persistent storage volumes used by the containers.

> **Note:** When adding additional Timbr services, always ensure that you place configuration details in the correct section.

---

## 2. Mandatory Services

These essential services are required for every Timbr deployment.

> **IMPORTANT**  
> For security, you must update the default values for the following environment variables in every service manifest where they appear. Do not use the provided defaults in production.
> 
> ```
> TIMBR_DB_USER=db_user
> TIMBR_DB_PASSWORD=db_pass
> MYSQL_ROOT_PASSWORD=db_pass
> DB_USERNAME=db_user
> DB_PASSWORD=db_pass
> ```


### 2.1 timbr-db
Holds your Timbr database, storing all system data.

```yaml
services:
  timbr-db:
    image: timbr.azurecr.io/timbr-mysql-8:latest
    container_name: timbr-db
    environment:
      - MYSQL_ROOT_PASSWORD=db_pass
    restart: always
    networks:
      - timbr-net
    volumes:
      - db-volume:/var/lib/mysql/
```

### 2.2 timbr-platform
Provides the web interface used for interacting with Timbr.

> **IMPORTANT**
>
> If the Timbr Platform web server will run on `http` (instead of `https`) you need to add and change the following environment variables to the deployment manifest:
> 
> ```
> - FLASK_DEBUG=1
> - ENFORCE_SSL=0
> ```


```yaml
services:
  timbr-platform:
    image: timbr.azurecr.io/timbr-platform-stable:latest
    container_name: timbr-platform
    environment:
      - DB_CONNECTION=mysql
      - DB_HOST=timbr-mysql
      - DB_PORT=3306
      - DB_DATABASE=timbr_platform
      - DB_USERNAME=db_user
      - DB_PASSWORD=db_pass
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
```

### 2.3 timbr-server
The core backend engine that processes data requests.

```yaml
services:
  timbr-server:
    image: timbr.azurecr.io/timbr-server-stable:latest
    container_name: timbr-server
    environment:
      - TIMBR_DB_JDBC=jdbc:mysql://timbr-db:3306
      - TIMBR_DB_JDBC_DRIVER=com.mysql.jdbc.Driver
      - TIMBR_DB_USER=db_user
      - TIMBR_DB_PASSWORD=db_pass
      - TIMBR_DB_JDBC_PARAMS=useSSL=false&amp;allowPublicKeyRetrieval=true
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
```

### Network & Volume Definitions

Below the services section, include your network and volume configurations:

```yaml
networks:
  timbr-net:
    driver: bridge

volumes:
  db-volume:
```

## 3. Optional Services

You can extend your deployment with additional features. Below are example one-line descriptions for each optional service:

- **timbr-proxy:** Routes incoming traffic and load-balances requests to ensure secure and efficient communication with Timbr backend services.
- **timbr-virtualization:** Combines data from multiple databases (or integrates with external engines like Apache Spark).
- **timbr-scheduler:** Automates tasks and schedules jobs.
- **timbr-cache:** Speeds up data retrieval by temporarily storing frequently used data.
- **timbr-mdx:** Lets you query Timbr with MDX (especially useful for Excel).
- **timbr-api:** Provides an API interface for custom integrations or to separate the UI from backend services.
- **timbr-ga:** Enables advanced analysis using graph algorithms.

---

## 4. Advanced Configurations for Optional Services

### 4.1 timbr-proxy

To use **timbr-proxy**, you must have an Nginx configuration file. There are two options – HTTP and HTTPS connectors.

#### 4.1.1 HTTP Connector

Add the following to your Compose file:

```yaml
services:
  timbr-proxy:
    image: timbr.azurecr.io/timbr-proxy:latest
    container_name: timbr-proxy
    networks:
      - timbr-net
    ports:
      - "80:80"
    depends_on:
      - timbr-db
    volumes:
      - <file location in your machine>/nginx-http.conf:/etc/nginx/nginx.conf
```

And create the `nginx-http.conf` file with:
``` conf
events {
  worker_connections 1024;
}

http {
  proxy_read_timeout 1200s;
  proxy_connect_timeout 1200s;
  proxy_send_timeout 1200s;
  resolver 127.0.0.11 ipv6=off;

  server {
    listen 80;
    port_in_redirect off;
    location / {
      set $upstream_proxy http://timbr-platform:8088;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    location /timbr-server {
      set $upstream_proxy http://timbr-server:11000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    location /hive2 {
      set $upstream_proxy http://timbr-server:11000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    location /cliservice {
      set $upstream_proxy http://timbr-server:11000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
  }
}
```

#### 4.1.2 HTTPS Connector

For HTTPS, modify the timbr-platform service:

``` yaml
services:
  timbr-platform:
    # ...
    environment:
      - FLASK_DEBUG=0  # Make sure FLASK_DEBUG is set to 0 for HTTPS
```

And add the HTTPS configuration for **timbr-proxy**:

``` yaml
services:
  timbr-proxy:
    image: timbr.azurecr.io/timbr-proxy:latest
    container_name: timbr-proxy
    networks:
      - timbr-net
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - timbr-db
    volumes:
      - <file location in your machine>/nginx-https.conf:/etc/nginx/nginx.conf
      - <file location in your machine>/domain_cert.pem:/usr/lib/ssl/domain_cert.pem
      - <file location in your machine>/private_key.pem:/usr/lib/ssl/private_key.pem
```

Create the `nginx-https.conf` file with the following content:

``` conf
events {
  worker_connections 1024;
}

http {
  proxy_read_timeout 1200s;
  proxy_connect_timeout 1200s;
  proxy_send_timeout 1200s;
  resolver 127.0.0.11 ipv6=off;
  
  server {
    listen 80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
  }
  
  server {
    listen 443 ssl;
    port_in_redirect off;
    ssl_certificate     /usr/lib/ssl/domain_cert.pem;
    ssl_certificate_key /usr/lib/ssl/private_key.pem;
    
    location / {
      set $upstream_proxy http://timbr-platform:8088;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
    location /timbr-server {
      set $upstream_proxy http://timbr-server:11000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    location /hive2 {
      set $upstream_proxy http://timbr-server:11000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    location /cliservice {
      set $upstream_proxy http://timbr-server:11000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    
    # Optional routing for additional services
    location /mdx {
      set $upstream_proxy http://timbr-mdx:12000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    location /timbr/openapi {
      set $upstream_proxy http://timbr-api:9000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
    location /timbr/api {
      set $upstream_proxy http://timbr-api:9000;
      proxy_pass $upstream_proxy$request_uri;
      proxy_set_header Host $host;
      proxy_set_header User-Agent: $http_user_agent;
    }
  }
}
```

> **Important:**  
> When using HTTPS, ensure you supply valid SSL certificate files (`domain_cert.pem` and `private_key.pem`) in your environment.

### 4.2 Additional Optional Services

Below are configuration examples for other optional Timbr services. Add these to your Compose file as needed.

#### timbr-virtualization

In order to use `timbr-virtualization` you first need to modify the timbr-server service:

``` yaml
services:
  timbr-server:
    # ...
    environment:
      - TIMBR_PUBLIC_HOSTNAME=timbr-server
```

> **Important:**  
> The new `TIMBR_PUBLIC_HOSTNAME` value must exactly match the `timbr-server` service name. 

```yaml
services:
  timbr-virtualization:
    image: timbr.azurecr.io/timbr-virtualization-v2:latest
    container_name: timbr-virtualization
    environment:
      - TIMBR_DB_JDBC=jdbc:mysql://timbr-db:3306/timbr_metastore?useSSL=false&amp;allowPublicKeyRetrieval=true
      - TIMBR_DB_JDBC_DRIVER=com.mysql.jdbc.Driver
      - TIMBR_DB_USER=db_user
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

#### timbr-scheduler

```yaml
services:
  timbr-scheduler:
    image: timbr.azurecr.io/timbr-scheduler:latest
    container_name: timbr-scheduler
    environment:
      - TIMBR_DB_HOST=timbr-db
      - TIMBR_DB_SSL="false"
      - TIMBR_DB_USER=db_user
      - TIMBR_DB_PASSWORD=db_pass
      - PYTHONUNBUFFERED=1
      - TIMBR_DB_NAME=timbr_server
      - THRIFT_HOST=timbr-server
    restart: always
    networks:
      - timbr-net
```

#### timbr-cache

```yaml
services:
  timbr-cache:
    image: timbr.azurecr.io/timbr-cache:latest
    container_name: timbr-cache
    networks:
      - timbr-net
    volumes:
      - cache-volume:/var/lib/clickhouse/
    restart: always

volumes:
  cache-volume:
```

#### timbr-mdx

```yaml
services:
  timbr-mdx:
    image: timbr.azurecr.io/timbr-mdx:latest
    container_name: timbr-mdx
    environment:
      - TIMBR_DB_JDBC=jdbc:mysql://timbr-db:3306
      - TIMBR_DB_JDBC_DRIVER=com.mysql.jdbc.Driver
      - TIMBR_DB_JDBC_PARAMS=useSSL=false&amp;allowPublicKeyRetrieval=true
      - TIMBR_DB_USER=db_user
      - TIMBR_DB_PASSWORD=db_pass
      - TIMBR_PUBLIC_HOSTNAME=timbr-server
    ports:
      - "13000:13000"
    networks:
      - timbr-net
    restart: always
```

#### timbr-api

```yaml
services:
  timbr-api:
    image: timbr.azurecr.io/timbr-api:latest
    container_name: timbr-api
    environment:
      - THRIFT_HOST=timbr-server
    ports:
      - "9000:9000"
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
      - TIMBR_DB_JDBC=jdbc:mysql://timbr-db:3306
      - TIMBR_DB_JDBC_DRIVER=com.mysql.jdbc.Driver
      - TIMBR_DB_USER=db_user
      - TIMBR_DB_PASSWORD=db_pass
      - THRIFT_HOST=timbr-server
    networks:
      - timbr-net
    depends_on:
      - timbr-db
```

## 5. Timbr Deployment Process

Follow these steps to deploy Timbr using Docker Compose:

1. **Login to the Docker Repository:**  
  Use your credentials to log in to our Docker repo:
  ```bash
   sudo docker login timbr.azurecr.io
  ```

2. **Run the Docker Compose File:**
  Open a terminal, navigate to the directory containing your `docker-compose.yml` file, then run:
  ```bash
    sudo docker-compose up -d
  ```

This command starts all Timbr services in the background.


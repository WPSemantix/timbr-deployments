![Timbr logo description](https://timbr.ai/wp-content/uploads/2025/01/logotimbrai230125.png)

![MIT License](https://img.shields.io/badge/License-MIT-green)

# Timbr Deployments Overview - Quick Start Guide

This guide will help you install and deploy our powerful semantic data platform.
For additional deployment configurations, please see the options presented in [Optional Services for Deployment with Timbr](./DEPLOYMENTS_OPTIONAL_SERVICS.md).

---

## 1. How to Deploy Timbr

Timbr can be deployed in two ways:

- **Docker Compose:**  
  A simple method for small-to-medium setups. Think of it as running a recipe that automatically starts all the necessary pieces of Timbr on your computer.
  - If you are planning to deploy using Docker, check out the [Deploy Timbr with Docker Compose](./DEPLOY_ON_DOCKER.md) guide.


- **Kubernetes (K8S):**  
  Designed for larger-scale or cloud deployments. This method involves more management but is ideal if you're operating at scale.
  - If you are planning to deploy using Kubernetes, check out the [Deploy Timbr with Kubernetes](./DEPLOY_ON_K8S.md) guide.

> **For most users who aren’t highly technical, we recommend starting with Docker Compose.**

---

## 2. What Are the Timbr Services?

Timbr consists of several components. Some are essential, while others add extra features:

- **timbr-mysql (Mandatory):**  
  The main database that stores Timbr’s internal information. You can run this as a small container or have it managed externally (such as in a cloud service).

- **timbr-server (Mandatory):**  
  The core engine of Timbr that processes data queries and handles your requests.

- **timbr-platform (Mandatory):**  
  The web interface where you interact with Timbr—view dashboards, reports, and more.

- **Optional Services:**  
  - **timbr-virtualization:** Combines data from multiple databases (or integrates with external engines like Apache Spark).  
  - **timbr-scheduler:** Automates tasks and schedules jobs.  
  - **timbr-cache:** Speeds up data retrieval by temporarily storing frequently used data.  
  - **timbr-llm:** Enhances natural language capabilities using large language models.  
  - **timbr-ga:** Enables advanced analysis using graph algorithms.  
  - **timbr-mdx:** Lets you query Timbr with MDX (especially useful for Excel).  
  - **timbr-api:** Provides an API interface for custom integrations or to separate the UI from backend services.

> **Note:** For most installations, only the three mandatory services are needed:
> - **timbr-mysql** (Database)  
> - **timbr-server** (Core Engine)  
> - **timbr-platform** (User Interface)

---

## 3. Recommended System Setup

Make sure your system meets these recommendations before installation:

- **Small-Medium Environment:**  
  At least **4 CPU cores** and **16 GB RAM**.

- **Large Environment:**  
  At least **8 CPU cores** and **32 GB RAM**.

You can deploy Timbr in several environments:

- **Cloud:**  
  Use services like AWS, Google Cloud (GCP), or Azure.
  
- **On-Premises:**  
  Run Timbr on your own Linux or Windows hardware.
  
- **Docker on Linux:**  
  Perfect for beginners—deploy easily using Linux images and Docker Compose.

> *Tip: For a straightforward start, deploying on a Linux server with Docker Compose is highly recommended.*

---

## 4. Quick Installation Steps Using Docker Compose

Follow these simple steps to install Timbr with Docker Compose:

1. **Install Docker:**  
  Download and install Docker from [Docker’s official site](https://docs.docker.com/get-docker/).

2. **Download the Docker Compose File:**  
  Retrieve the `docker-compose.yml` file from the Timbr repository. This file details how to start all of Timbr's services automatically.

3. **Run Docker Compose:**  
  Open a terminal, navigate to the folder containing the `docker-compose.yml` file, and run:
  ```bash
    docker-compose up -d
  ```
  This command starts all Timbr services in the background.

4. **Access Timbr:**  
  Open your web browser and go to `http://localhost:8088/`. The Timbr interface should now be ready for use.

---

## 5. Timbr Environment Variables

For users who need custom configurations, Timbr uses several environment variables. Below are details for two main groups of settings.

### 5.1 Timbr Server Environment Variables

These variables configure core system settings such as database connectivity and performance. Adjust them only if necessary.

| Environment Variable                    | Type      | Default Value                        | Description                                                                                                   |
|-----------------------------------------|:---------:|:------------------------------------:|---------------------------------------------------------------------------------------------------------------|
| **TIMBR_DB_JDBC**                       | String    | `"jdbc:mysql://localhost:3306"`      | URL for connecting to the MySQL database.                                                                   |
| **TIMBR_DB_JDBC_DRIVER**                | String    | `"com.mysql.jdbc.Driver"`            | Specifies the JDBC driver used to connect to the MySQL database.                                              |
| **TIMBR_DB_JDBC_PARAMS**                | String    | `"useSSL=false"`                     | Additional parameters for the connection (e.g., disabling SSL).                                               |
| **TIMBR_DB_NAME**                       | String    | `"timbr_server"`                     | Name of the database used by the Timbr server.                                                                |
| **TIMBR_DB_USER**                       | String    | `"db_user"`                             | Username for accessing the database.                                                                        |
| **TIMBR_DB_PASSWORD**                   | String    | `null`                               | Password for the database connection (set this in your secure environment).                                   |
| **TIMBR_PUBLIC_HOSTNAME**               | String    | `"timbr-server"`                     | Hostname used to access the Timbr server from outside.                                                        |
| **TIMBR_PUBLIC_PORT**                   | String    | `"11000"`                            | Port for connecting to the Timbr server interface.                                                            |
| **TIMBR_PUBLIC_SSL**                    | String    | `"false"`                            | Indicates whether SSL is enabled (set to `"true"` if using HTTPS).                                            |
| **TIMBR_PUBLIC_PATH**                   | String    | `"/timbr-server"`                    | URL path where the Timbr interface is served.                                                                 |
| **KV_PW_KEY**                           | String    | `"DB-PASSWORD"`                      | Key used to encrypt and secure the database password in a vault integration.                                  |
| **KV_VAULT_TYPE**                       | String    | `null`                               | Specifies the type of secure vault used (if any).                                                             |
| **KV_VAULT_REGION**                     | String    | `null`                               | The cloud region where your vault service is hosted.                                                          |
| **KV_VAULT_AUTH_TYPE**                  | String    | `null`                               | Authentication type for the secure vault.                                                                     |
| **AWS_CLIENT_ID**                       | String    | `null`                               | AWS client ID for deployments on Amazon Web Services.                                                         |
| **AWS_CLIENT_SECRET**                   | String    | `null`                               | AWS client secret for secure API access on AWS.                                                               |
| **AZURE_CLIENT_ID**                     | String    | `null`                               | Azure client ID for deployments on Microsoft Azure.                                                           |
| **AZURE_TENANT_ID**                     | String    | `null`                               | Tenant ID for Azure, used in authentication.                                                                  |
| **AZURE_CLIENT_SECRET**                 | String    | `null`                               | Azure client secret for secure API access.                                                                    |
| **SYNC_GROUPS_INTERVAL**                | Integer   | `86400`                              | Interval in seconds for synchronizing user groups.                                                            |
| **SYNC_GROUPS_AUTO_CREATE**             | String    | `"false"`                            | If `"true"`, missing user groups will be automatically created.                                               |
| **OAUTH_TOKEN_EXPIRATION**              | Integer   | `600`                                | Time in seconds before an OAuth token expires.                                                                |
| **OAUTH_OFFLINE_ACCESS_SCOPE**          | Boolean   | `false`                              | Enables OAuth offline access if set to `true`.                                                                 |
| **QUERY_TIMEOUT**                       | Integer   | `600`                                | Maximum allowed time in seconds for executing a query.                                                        |
| **ONTOLOGY_DDL_TIMEOUT**                | Integer   | `600`                                | Timeout in seconds for ontology definition operations.                                                        |
| **OPERATION_TIMEOUT**                   | Integer   | `180`                                | General timeout in seconds for server operations.                                                             |
| **THREAD_KEEP_ALIVE**                   | Integer   | `60`                                 | Duration in seconds for idle threads to stay active before closing.                                             |
| **TIMBR_CONNECTION_WORKER_THREADS**     | Integer   | `100`                                | Number of threads allocated to managing database connections.                                                 |
| **TIMBR_OPERATION_WORKER_THREADS**      | Integer   | `50`                                 | Number of threads dedicated to performing operations.                                                         |
| **TIMBR_IDLE_CONNECTION_TIMEOUT**       | Integer   | `300000`                             | Timeout in milliseconds for idle database connections.                                                        |
| **TIMBR_RESULTSET_DEFAULT_FETCH_SIZE**  | String    | `"5000"`                             | Default number of records to fetch when retrieving data.                                                      |
| **TIMBR_RESULTSET_MIN_FETCH_SIZE**      | Integer   | `5000`                               | Minimum records to fetch in a result set.                                                                     |
| **TIMBR_RESULTSET_MAX_FETCH_SIZE**      | Integer   | `20000`                              | Maximum records to fetch in one go from the database.                                                         |
| **TIMBR_RESULTSET_FETCH_TIMEOUT**       | Integer   | `300`                                | Timeout in seconds for fetching the result set.                                                               |

### 5.2 Timbr Platform Environment Variables

These variables configure the front-end platform that provides the user interface. They control aspects from database connection to feature toggles.

| Environment Variable           | Required | Default Value | Description                                                                                                                     |
|--------------------------------|:--------:|:-------------:|---------------------------------------------------------------------------------------------------------------------------------|
| **DB_CONNECTION**              | Yes      | `mysql`       | Type of database used by the Timbr platform. Options include **mysql**, **postgresql**, and **mssql**.                         |
| **DB_DATABASE**                | Yes      | `timbr_platform`    | Name of the database for storing Timbr platform data.                                                                         |
| **DB_HOST**                    | Yes      | `localhost`   | Hostname or IP address of the database server.                                                                                |
| **DB_PORT**                    | Yes      | (none)        | Port number on which the database service is running.                                                                         |
| **DB_USERNAME**                | Yes      | (none)        | Username for connecting to the platform's database.                                                                           |
| **DB_PASSWORD**                | Yes      | (none)        | Password for accessing the platform's database.                                                                               |
| **DB_SECRET_KEY**              | Yes      | (none)        | Secret key used to secure and validate the database connection.                                                               |
| **THRIFT_HOST**                | Yes      | (none)        | Timbr server database HOST. For example: `20.119.110.124`                                                                     |
| **THRIFT_PORT**                | Yes      | (none)        | Timbr server database PORT. For example: `11000`                                                                              |
| **TIMBR_SERVER_SCHEMA**        | Yes      | (none)        | Timbr server database SCHEMA. For example: `timbr_server_db`                                                                  |
| **ENFORCE_SSL**        | Yes*      | `False`        | Required only when redirecting traffic from HTTPS to HTTP. When true, it prevents the proxy from HTTPS redirect to HTTP that could cause browser errors.  |
| **CAN_UPLOAD_CSV**             | No       | `False`       | Enables or disables the CSV upload form for adding datasets.                                                                  |
| **FLASK_DEBUG**                | No       | `False`       | Determines whether the server should run in debug mode (provides extra logging).                                               |
| **FLASK_ENV**                  | No       | `production`  | Defines the environment type, for example, `development` or `production`.                                                      |
| **FLASK_SECRET_KEY**           | No       | (auto-generated)        | A secret used to encrypt session data for user security.                                                                      |
| **GOOGLE_ANALYTICS_TAG**       | No       | (none)        | Google Analytics tracking tag to monitor usage (disabled by default).                                                         |
| **MAPBOX_API_KEY**             | No       | (none)        | API key for Mapbox, necessary for rendering interactive charts.                                                               |
| **REDIS_AUTH**                 | No       | `None`        | Authentication password for connecting to the Redis server, used for caching and messaging.                                    |
| **REDIS_DB**                   | No       | `None`        | Database number to use on the Redis server.                                                                                    |
| **REDIS_HOST**                 | No       | `None`        | Host address for the Redis service.                                                                                            |
| **REDIS_PORT**                 | No       | `None`        | Port number for connecting to Redis.                                                                                           |
| **SQLLAB_LIMIT**               | No       | `1000`        | Maximum number of records returned from queries in the SQL Lab feature.                                                        |
| **OAUTH_OFFLINE_ACCESS_SCOPE** | No       | `False`       | Toggle to enable OAuth support for offline access to data sources (set to `true` if needed).                                   |
| **TIMBR_ALLOW_EMBEDDED_IFRAME**     | No       | `False`       | Allow embedded iframe (by allowing cross origin HTTP headers) of Graph Exploration. For example: `false`                        |
| **ALLOW_PUBLIC_EMBED_QUERY_GRAPH**  | No       | `False`       | Allow embedded iframe (by allowing anonymous users access) of Graph Exploration. For example: `false`                           |
| **CAN_DOWNLOAD_CSV**                | No       | `True`        | Allows users to download CSV files from the SQL Editor page. For example: `true`                                                |
| **SHOW_GRAPH_EXPLORER_ALERTS**      | No       | `True`        | Show or hide toast messages in the Graph Explorer. For example: `False`                                                         |
| **AZURE_VAULT_URI**                 | No       | (none)        | The URL of the Azure Vault URI. For example: `https://kv-test.vault.azure.net/`                                                 |
| **AZURE_KV_PW_KEY**                 | No       | (none)        | Azure Key Vault password key. For example: `root`                                                                               |
| **AZURE_TENANT_ID**                 | No       | (none)        | ID of the service principal's tenant. For example: `0000003b-4007-400d-7444-f74c00000008e`                                      |
| **AZURE_CLIENT_ID**                 | No       | (none)        | The service principal's client ID. For example: `010000000f-e006-4009-9003-8000000006`                                          |
| **AZURE_CLIENT_SECRET**             | No       | (none)        | One of the service principal's client secrets. For example: `q...rY`                                                            |
| **OAUTH_PROVIDER**                  | No       | `none`        | OAuth provider can be either `google`, `azure`, or leave empty for none. For example: `azure`                                   |
| **OAUTH_DEFAULT_SCHEME**            | No       | `http`        | OAuth default scheme. For example: `http`                                                                                       |
| **AUTH_CLIENT_ID**                  | No       | (none)        | The client id of the OAuth provider. For example: `9a....4`                                                                     |
| **OAUTH_AZURE_VERIFY_SIGNATURE**    | No       | `False`       | Verify OAuth provider signature (in Azure only). For example: `True`                                                            |
| **OAUTH_SECRET**                    | No       | (none)        | OAuth provider secret key. For example: `t8....G`                                                                               |
| **OAUTH_BASE_URL**                  | No       | (none)        | Optional. OAuth BASE URL (if set). For example: `https://login.microsoftonline.com/9.....8e/oauth2`                             |
| **AUTH_USER_REGISTRATION**                  | No       | `False`        | Optional. Will allow user self registration with OAuth |
| **AUTH_USER_REGISTRATION_ROLE**                  | No       | `Public`        | Optional. The default user self registration role (must be specified if user is allowed to self register with OAuth) |
| **USE_BIGQUERY_TOKEN**              | No       | `False`       | Use an authentication token per user to query Google Big Query. For example: `1`                                                |
| **TIMBR_LLM_TYPE**                  | No       | (none)        | The type of the LLM used with Timbr, can be `OpenAI`, `Anthropic`, `Google`, `AzureOpenAI`. For example: `OpenAI`               |
| **TIMBR_LLM_MODEL**                 | No       | (none)        | The model of the LLM used with Timbr. For example: `gpt-4o`                                                                     |
| **TIMBR_LLM_APIKEY**                | No       | (none)        | The API key used to connect to the LLM service provider. For example: `A...Kw`                                                  |
| **TIMBR_LLM_ENDPOINT**              | No       | (none)        | The API Endpoint for the LLM provider (Mandatory only for AzureOpenAI service). For example: `https://my-azure-foundry.url.azure.com` |


---

## 6. Final Notes and Support

- **Customization:**  
  Timbr is built to be flexible. While the default settings are adequate for most users, technical teams can adjust the advanced configurations to suit their security and performance needs.

- **Need Help?**  
  If you have any questions or run into issues during installation, please visit our [Support Page](https://share.hsforms.com/1EEz8ru9sToGt2SeSWU6jnA3wa7u) or contact our friendly support team.

- **Security Considerations:**  
  For deployments that handle sensitive data, ensure you apply all necessary security measures. You can further customize settings in the configuration files and extend **Docker Compose** or **Kubernetes** charts to suit your security policies.



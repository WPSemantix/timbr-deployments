# Optional Services Configurations for Deployment with Timbr

## Timbr Virtualization Service

In the web platform of timbr, add a new datasource with this specifications:

1. Datasource Type: `Apache Spark`
   - Click on the `Active Virtualization` check-box
2. Datasource Name: `timbr_virtualization`
3. Hostname/IP: `<virtualization hostname if applicable>` (or use default: `timbr-virtualization`)
4. Port: `<virtualization port if applicable>` (or use default: `10000`)
5. User: `timbr`
6. Password: `<timbr-db-password>`


### Important
> **Hostname/IP** value is the hostname in docker/Kubernetes for Timbr virtualization service.
> **Port** value is the port in docker/Kubernetes for Timbr virtualization service.
> **Password** value is the timbr-db password.

---

## Timbr Cache Service

In the web platform of Timbr, add a new datasource with this specifications:


1. Datasource Type: `Clickhouse`
2. Datasource Name: `timbr_cache`
3. Hostname/IP: `<timbr-cache hostname>` (or use default: `timbr-cache`)
4. port: `<timbr-cache port>` (or use default: `8123`)
5. User: `timbr`
6. Password: `<timbr-db-password>`
7. Additional parameters: `socket_timeout=21600000&custom_http_params=connect_timeout%3D3600%2Chttp_send_timeout%3D3600%2Chttp_receive_timeout%3D3600%2Chttp_max_tries%3D1%2Cjoin_algorithm%3Dpartial_merge%2Cmax_query_size%3D5000000%2Cmax_rows_in_set_to_optimize_join%3D200000%2Cmax_threads%3D10%2Cmax_final_threads%3D8`


### Important
> **Hostname/IP** value is the hostname in docker/Kubernetes for Timbr cache service.
> **Port** value is the port in docker/Kubernetes for Timbr cache service.
> **Password** value is the timbr-db password.

---

## Timbr GA (Timbr Graph Algorithms) Service

Timbr graph algorithms can be configure in two ways:

1. Enable graph algorithms to all of the ontologies in Timbr
or
2. Enable graph algorithms to a specific ontology in Timbr

-  In order to **enable graph algorithms to all of the ontologies in Timbr** you have to add a new environment variable to the `timbr-server` service:

   - For **Docker Compose Deployment**:

      In your `docker-compose.yaml` add those changes to the **timbr-server** service:

      ``` yaml
      services:
        timbr-server:
          # ...
          environment:
            - graph_algorithm_manager_url=http://timbr-ga:12000/execute_algorithm
      ```

   - For **K8S Deployment**:

      In your **Timbr server** deployment YAML file, configure the following environment variable:

      ```yaml
      spec:
        # ...
        template:
          # ...
          spec:
            # ...
            containers:
              - name: timbr-server
                # ...
                env:
                  # ...
                  - name: graph_algorithm_manager_url
                    value: http://timbr-ga:12000/execute_algorithm
      ```

 - To **enable graph algorithms to a specific ontology in timbr**, In the web platform of timbr, open the `sqllab` tab and run this query:

      ``` yaml
      alter ontology <ontology_name> set graph_algorithm_manager_url = 'http://timbr-ga:12000/execute_algorithm'
      ```

---

## Connect Timbr Platform to Google Analytics

In order to connect the **Timbr Platform** to **Google Analytics** you should add a new environment variable to the `timbr platform` service 

### Deployment options
1. **Docker Compose**

    In your `docker-compose.yaml` add those changes to the **timbr-platform** service:

    ``` yaml
    services:
      timbr-platform:
        # ...
        environment:
          - GOOGLE_ANALYTICS_TAG=<GOOGLE_ANALYTICS_TAG>
    ```

2. **K8S**

    In your **Timbr Platform** deployment YAML file, configure the following environment variable:

    ```yaml
    spec:
      # ...
      template:
        # ...
        spec:
          # ...
          containers:
            - name: timbr-platform
              # ...
              env:
                # ...
                - name: GOOGLE_ANALYTICS_TAG
                  value: <GOOGLE_ANALYTICS_TAG>
    ```

---

## Configure SSO Google cloud in Timbr

Please make sure you have an **HTTPS** endpoint (Google Cloud SSO doesn't allow configuring HTTP servers). 
The **Timbr Platform** service should have an existing SSL certificate. 

Once the SSL is configured, you can create the App Registration in Google Cloud to enable the SSO authentication.

In order to configure the SSO with Google Cloud in Timbr, you will need the following App Registration details: 

- **CLIENT_ID**

- **CLIENT_SECRET**

### Deployment options
1. **Docker Compose**

    In your `docker-compose.yaml` add those changes to the **timbr-platform** service:

    ``` yaml
    services:
      timbr-platform:
        # ...
        environment:
          - OAUTH_PROVIDER=google
          - OAUTH_CLIENT_ID=<GOOGLE_CLOUD_CLIENT_ID>
          - OAUTH_SECRET=<GOOGLE_CLOUD_CLIENT_SECRET>
          - USE_BIGQUERY_TOKEN=false
    ```

    > **NOTICE:**
    > In case of using Big Query database and you want to authenticate per user to query Big Query replace the value of `USE_BIGQUERY_TOKEN` environment variable to `true`.
    > Should look like this: `- USE_BIGQUERY_TOKEN=true`

2. **K8S**

    In your **Timbr Platform** deployment YAML file, configure the following environment variables:

    ```yaml
    spec:
      # ...
      template:
        # ...
        spec:
          # ...
          containers:
            - name: timbr-platform
              # ...
              env:
                # ...
                - name: OAUTH_PROVIDER
                  value: google
                - name: OAUTH_CLIENT_ID
                  value: <GOOGLE_CLOUD_CLIENT_ID>
                - name: OAUTH_SECRET
                  value: <GOOGLE_CLOUD_CLIENT_SECRET>
                - name: USE_BIGQUERY_TOKEN
                  value: false
    ```

    > **NOTICE:**
    > In case of using Big Query database and you want to authenticate per user to query Big Query replace the value of `USE_BIGQUERY_TOKEN` environment variable to `true`.
    > Should look like this:
    >
    > `- name: USE_BIGQUERY_TOKEN`
    >
    > `   value: true`

---

## Configure Azure AD SSO in Timbr

Please make sure you have an **HTTPS** endpoint (Azure AD doesn't allow configuring HTTP servers). 
The `timbr platform` should have an existing SSL certificate. 

Once the SSL is configured, you can create the App Registration in Azure to enable the SSO authentication.

In order to configure the SSO with Azure AD in Timbr, you will need the following App Registration details: 

- **AZURE_APPLICATION_ID**

- **AZURE_TENANT_ID**

- **AZURE_SECRET**

Moreover, you need to know how does your Azure AD users would accesss to the Timbr environment and it could be one of those 2 options:
1. Using `Azure UserPrincipalName`
2. Using `Email Address`

The App Registration needs the following permissions:

| Microsoft Graph (4) | Scope | Delegation | Description |
|-------|-----------|--------|-------|
|  | **email** | Delegated | View users' email address |
|  | **openid** | Delegated | Sign users in |
|  | **profile** | Delegated | View users' basic profile |
|  | **User.Read** | Delegated | Sign in and read user profile |


In the authentication tab of App Registration, add the redirect URL (Under web) with your Timbr public URL 

                        https://<timbr-public-url>/oauth-authorized/azure

Once you have set the App Registration, you can configure the YAML file of **timbr-platform** together with the environment variable to enable the SSO authentication.

![Web](img/azure_ad_web.png)

### Deployment options
1. **Docker Compose**

    In your `docker-compose.yaml` add those changes to the **timbr-platform** service:

    ``` yaml
    services:
      timbr-platform:
        # ...
        environment:
          - OAUTH_PROVIDER=azure
          - OAUTH_CLIENT_ID=<AZURE_APPLICATION_ID>
          - OAUTH_SECRET=<AZURE_SECRET>
          - OAUTH_BASE_URL=https://login.microsoftonline.com/<AZURE_TENANT_ID>/oauth2
          - OAUTH_AZURE_WITH_UPN_FIRST=False
    ```

    > **NOTICE:**
    > In case of using `Azure UserPrincipalName` replace the value of `OAUTH_AZURE_WITH_UPN_FIRST` environment variable to `True`.
    > Should look like this: `- OAUTH_AZURE_WITH_UPN_FIRST=True`

2. **K8S**

    In your **Timbr Platform** deployment YAML file, configure the following environment variables:

    ```yaml
    spec:
      # ...
      template:
        # ...
        spec:
          # ...
          containers:
            - name: timbr-platform
              # ...
              env:
                # ...
                - name: OAUTH_PROVIDER
                  value: azure
                - name: OAUTH_CLIENT_ID
                  value: <AZURE_APPLICATION_ID>
                - name: OAUTH_SECRET
                  value: <AZURE_SECRET>
                - name: OAUTH_BASE_URL
                  value: https://login.microsoftonline.com/<AZURE_TENANT_ID>/oauth2
                - name: OAUTH_AZURE_WITH_UPN_FIRST
                  value: False
    ```

    > **NOTICE:**
    > In case of using `Azure UserPrincipalName` replace the value of `OAUTH_AZURE_WITH_UPN_FIRST` environment variable to `True`.
    > Should look like this:
    >
    > `- name: OAUTH_AZURE_WITH_UPN_FIRST`
    >
    > `   value: True`

---

## Sync Azure AD Groups with Timbr Roles

The first step to sync the Azure AD Groups with Timbr roles, is to configure additional permissions in the App Registration where the Timbr Platform SSO is defined. 

Add the following permissions:

- **User.Read.All**

- **Group.Read.All**

- **GroupMember.Read.All**

![Permissions](img/azure_ad_group_permission.png)

After that you need to set the App Registration `client_id`, `tenant_id`, and `secret`, in the **timbr server** section of the deployment:

1. **Docker Compose**

    In your `docker-compose.yaml` add those changes to the **timbr-server** service:

    ``` yaml
    services:
      timbr-server:
        # ...
        environment:
          - AZURE_CLIENT_ID=<AZURE_CLIENT_ID>
          - AZURE_TENANT_ID=<AZURE_TENANT_ID>
          - AZURE_CLIENT_SECRET=<AZURE_CLIENT_SECRET>
          - SYNC_GROUPS_INTERVAL=86400
          - SYNC_GROUPS_AUTO_CREATE=false
    ```

2. **K8S**

    In your **Timbr Server** deployment YAML file, configure the following environment variables:

    ```yaml
    spec:
      # ...
      template:
        # ...
        spec:
          # ...
          containers:
            - name: timbr-server
              # ...
              env:
                # ...
                - name: AZURE_CLIENT_ID
                  value: <AZURE_CLIENT_ID>
                - name: AZURE_TENANT_ID
                  value: <AZURE_TENANT_ID>
                - name: AZURE_CLIENT_SECRET
                  value: <AZURE_CLIENT_SECRET>
                - name: SYNC_GROUPS_INTERVAL
                  value: 86400
                - name: SYNC_GROUPS_AUTO_CREATE
                  value: false
    ```

3. **Choose Timbr roles to sync from AD Groups:**

    Once we've set up the environment variables in **timbr-server**, you can set **any role** to sync from Azure AD Group. 

    To configure which group to sync, you can use the **Group Name** or **Group ID** or **Group Email**, and run the following SQL statements in the **SQL Lab** page of the **Timbr Platform**:
    ```sql
    ALTER ROLE `role_name` SYNC name = 'group_name'
    ```

    **or**
    ```sql
    ALTER ROLE `role_name` SYNC id = 'group_id'
    ```

    **or**
    ```sql
    ALTER ROLE `role_name` SYNC email = 'group_email'
    ```

    Once a role is synced, it has a default update interval of 24 hours. The sync interval is configurable and can be customized by adding the variable **SYNC_GROUPS_INTERVAL=time_in_seconds** to the docker compose file under **timbr server**. In case you need to manually sync the role, run the following SQL statement:

    ```sql
    SYNC ROLE `role_name`;
    ```

    To automatically create users according to new users added to AD Groups, you can add the variable **SYNC_GROUPS_AUTO_CREATE_USER=TRUE** to the docker compose file under **timbr server**.


---


## SSO for Databricks Datasources (passthrought) in Azure

First, make sure you have an **HTTPS** endpoint (Google Cloud SSO doesn't allow configuring HTTP servers) so that the **Timbr Platform** should have an existing SSL certificate. 

Once the SSL is configured, you can create the App Registration in Azure Databricks to enable the SSO authentication.

Second, in order to configure the SSO with Azure Databricks in Timbr, you will need the following App Registration details:

- **Delegated `user_impersonation` for AzureDatabricks**

![user impersonation](img/user_impersonation.png)
<!-- ![user impersonation](img/user_impersonation.png) -->

- **`offline_access` in Microsoft Graph**

![offline_access](img/offline_access.png)
<!-- ![offline_access](img/offline_access.png) -->

### Deployment options
1. **Docker Compose**

In your `docker-compose.yaml` add those changes to the **timbr-platform** and **timbr-server** services:

``` yaml
services:
  timbr-platform:
    # ...
    environment:
      - OAUTH_OFFLINE_ACCESS_SCOPE='true'
      - OAUTH_SCOPES=2ff814a6-3304-4ab8-85cb-cd0e6f879c1d/user_impersonation
  # ...
  timbr-server:
    # ...
    environment:
      - OAUTH_OFFLINE_ACCESS_SCOPE=true
      - OAUTH_REFRESH_TOKEN_EXPIRATION=10
      - OAUTH_REFRESH_TOKEN_VALIDATION=1
```

2. **K8S**

In your **Timbr Platform** deployment YAML file, configure the following environment variable:

```yaml
spec:
  # ...
  template:
    # ...
    spec:
      # ...
      containers:
        - name: timbr-platform
          # ...
          env:
            # ...
            - name: OAUTH_OFFLINE_ACCESS_SCOPE
              value: 'true'
            - name: OAUTH_SCOPES
              value: 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d/user_impersonation
```

In your **Timbr Server** deployment YAML file, configure the following environment variable:

```yaml
spec:
  # ...
  template:
    # ...
    spec:
      # ...
      containers:
        - name: timbr-server
          # ...
          env:
            # ...
            - name: OAUTH_OFFLINE_ACCESS_SCOPE
              value: true
            - name: OAUTH_REFRESH_TOKEN_EXPIRATION
              value: 10
            - name: OAUTH_REFRESH_TOKEN_VALIDATION
              value: 1
```

In the web platform of timbr, add a new datasource with this specifications:

1. Datasource Type: `Databricks`
3. Datasource Name: `databricks`
4. Hostname/IP: `<datasource hostname>`
5. Port: `443`
6. User: `token`
7. Password: `<sso token value>`

In the `Additional Parameters` change the `AuthMech` to 11 and the `Auth_Flow`to 0. It should look like this:

```
... AuthMech=11;Auth_Flow=0 ...
```

![add new Databricks datasource example](img/databricks_add_ds_example.png)

---

## How to setup KeyVault (Azure/AWS) for datasources credentials

Refrences:

[Azure KV](https://azure.microsoft.com/en-us/products/key-vault)

[AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

By default Timbr encrypt and stores all the of yours Datasource credentials in timbr's Database.
You can change it and configure Timbr to encrypt and store your Datasource credentials yours KeyVault (Azure KV/AWS KMS).

**Important**
If you choose to use the KeyVault option it means that all Datasource passwords will be stored in KV instead of timbr's db.

1. **AWS deployment**
  
1. **Docker Compose Deployment**
  In your `docker-compose.yaml` add those changes to the **timbr-server** service:

  ``` yaml
  services:
    # ...
    timbr-server:
      # ...
      environment:
        - KV_VAULT_TYPE="aws"
        - KV_VAULT_AUTH_TYPE="password"
        - KV_VAULT=<KMS_NAME>
        - KV_VAULT_REGION="<KMS_REGION>"
        - AWS_CLIENT_ID="<AWS_CLIENT_ID>"
        - AWS_CLIENT_SECRET="<AWS_CLIENT_SECRET>"
  ```
  2. **K8S Deployment**

  In your **Timbr Server** deployment YAML file, configure the following environment variables:

  ```yaml
  spec:
    # ...
    template:
      # ...
      spec:
        # ...
        containers:
          - name: timbr-server
            # ...
            env:
              # ...
              - name: KV_VAULT_TYPE
                value: "aws"
              - name: KV_VAULT_AUTH_TYPE
                value: "password"
              - name: KV_VAULT
                value: "<KV_URL>"
              - name: KV_VAULT_REGION
                value: "<KMS_REGION>"
              - name: AWS_CLIENT_ID
                value: "<AWS_CLIENT_ID>"
              - name: AWS_CLIENT_SECRET
                value: "<AWS_CLIENT_SECRET>"
  ```


2. **Azure deployment**

1. **Docker Compose Deployment**
  
    In your `docker-compose.yaml` add those changes to the **timbr-server** service:

    ``` yaml
    services:
      # ...
      timbr-server:
        # ...
        environment:
          - KV_VAULT_TYPE="azure"
          - KV_VAULT_AUTH_TYPE="password"
          - KV_VAULT=<KV_URL>
          - AZURE_CLIENT_ID="<AZURE_CLIENT_ID>"
          - AZURE_TENANT_ID="<AZURE_TENANT_ID>"
          - AZURE_CLIENT_SECRET="<AZURE_CLIENT_SECRET>"
    ```

2. **K8S Deployment**

    In your **Timbr Server** deployment YAML file, configure the following environment variables:

    ```yaml
    spec:
      # ...
      template:
        # ...
        spec:
          # ...
          containers:
            - name: timbr-server
              # ...
              env:
                # ...
                - name: KV_VAULT_TYPE
                  value: "azure"
                - name: KV_VAULT_AUTH_TYPE
                  value: "password"
                - name: KV_VAULT
                  value: "<KMS_NAME>"
                - name: AZURE_CLIENT_ID
                  value: "<AZURE_CLIENT_ID>"
                - name: AZURE_TENANT_ID
                  value: "<AZURE_TENANT_ID>"
                - name: AZURE_CLIENT_SECRET
                  value: "<AZURE_CLIENT_SECRET>"
    ```

  ---

## How to setup JWT Token (Azure or Keycloack) for timbr-api

The Timbr REST API Service supports offline authentication using JWT tokens (Open ID).
This authentication method allows Azure AD, Microsoft Identity Platform and OAuth 2.0 Open ID Connect (OIDC) to verify user identities using JWT tokens, even in multi-tenant environments. 

### Azure JWT

- **Docker Compose Deployment**

    In your `docker-compose.yaml` add those changes to the **timbr-api** service:

    ``` yaml
    services:
      timbr-api:
        # ...
        environment:
          - ENABLE_TOKEN=true
          - JWT_TYPE=azure
    ```

- **K8S Deployment**

    In your **timbr-api** deployment YAML file, configure the following environment variable:

    ```yaml
    spec:
      # ...
      template:
        # ...
        spec:
          # ...
          containers:
            - name: timbr-api
              # ...
              env:
                # ...
                - name: ENABLE_TOKEN
                  value: true
                - name: JWT_TYPE
                  value: azure
    ```

#### Azure JWT Environment Variables

Please note the following requirements for environment variables:

- All JWT environment variables **must be in uppercase**.

The following environment variables can be set and serve as default values for the Timbr API Service:

| Environment Variable | Required | Default Value | Possible Values | Description |
|----------------------|----------|---------------|-----------------|-------------|
| `ENABLE_TOKEN` | ✔️ | `false` | `false` or `true` | This value **must be set to `true`** to enable JWT authentication in Timbr. |
| `JWT_TYPE` | ✔️ | `custom` | `custom` or `azure` | This value **must be set to `azure`** in order to enable JWT authentication with Azure in Timbr. |
| `JWT_DEFAULT_ALGORITHM` | ✖️ | `RS246` | `HS256`, `RSA-OAEP`, `RS256`, `AES` | `RS246` or `RSA-OAEP` should be used with a **Public Key**, while `HS256` (hmac) or `AES` should be used with a **Secret Password**. You can specify multiple algorithms by separating them with commas, for example, `RS246,RSA-OAEP`, to use both algorithms in the decryption process. |
| `JWT_DEFAULT_AUDIENCE` | ✖️ | _None_ | string | The audience is commonly the *Client ID*. If this value is not set, the JWT will be decrypted without audience validation. This can also be set through using the `x-jwt-client-id` header in the request |
| `JWT_USE_EMAIL_OR_USER` | ✖️ | `upn` | string | The key storing the value in the JWT token with information about the username or email to be authernticated in Timbr. |
| `JWT_ISSUER` | ✖️ | _None_ | string | The default value for the issuer of the JWT token, can also be passed as a request header for multi-tenant environments. The issuer value is a case sensitive URL using the https scheme that contains scheme, host, and optionally, port number and path components and no query or fragment components.|

#### Azure JWT Request Headers

Please note the following requirements for request headers:

- All headers **must be in lowercase**.

| Header Key | Required | Header Value | Description |
|----------------------|----------|---------------|-----------------|
| `x-jwt-token` | ✔️ | string | The access token of the JWT. |
| `x-jwt-tenant-id` | ✖️ | string | The tenant ID value used by the `JWT_<TENANT_ID>...` environment variables. |
| `x-jwt-issuer` | ✖️ | string | Issuer identifier for the Issuer of the token. The issuer value is a case sensitive URL using the https scheme that contains scheme, host, and optionally, port number and path components and no query or fragment components. |
| `x-jwt-client-id` | ✖️ | string | The audience for the JWT. Audience(s) that this ID Token is intended for. It MUST contain the OAuth 2.0 client_id of the Relying Party as an audience value. It MAY also contain identifiers for other audiences. In the general case, the aud value is an array of case sensitive strings. In the common special case when there is one audience, the aud value MAY be a single case sensitive string. |
| `x-jwt-nonce` | ✖️ | string | If present in the JWT, Clients MUST verify that the nonce Claim Value is equal to the value of the nonce parameter sent in the Authentication request. The nonce value is a case sensitive string. |

#### Using Azure JWT in Multi-tenant Environments

In a multi-tenant environment, you can set specific credentials for different realms by defining environment variables specific to each tenant. Replace `<TENANT_ID>` with an alphanumeric tenant identifier. These settings take precedence over the `JWT_DEFAULT...` values when decrypting the JWT access token.

| Environment Variable | Required | Default Value | Possible Values | Description |
|----------------------|----------|---------------|-----------------|-------------|
| `JWT_<TENANT_ID>_ALGORITHM` | ✖️ | `RS246` | `HS256`, `RSA-OAEP`, `RS256`, `AES` | `RS246` or `RSA-OAEP` should be used with a **Public Key**, while `HS256` (hmac) or `AES` should be used with a **Secret Password**. You can specify multiple algorithms by separating them with commas, for example, `RS246,RSA-OAEP`, to use both algorithms in the decryption process. |
| `JWT_<TENANT_ID>_AUDIENCE` | ✖️ | _None_ | string | The audience is commonly the *Client ID*. If this value is not set, the JWT will be decrypted without audience validation. This can also be set through using the `x-jwt-client-id` header in the request |
| `JWT_USE_TENANT_USER` | ✖️ | `False` | `False` or `True` | When set to `True`, the **username** or **email** will have a prefix of the **tenant id** (as specified by the `x-jwt-tenant-id` header in the request) and will be authenticated as `<tenant id>/<username or email>` according to the value specified in the environment variable `JWT_USE_EMAIL_OR_USER`. |

Using `JWT_USE_TENANT_USER` Environment Variable Example:

>   - An incoming request with a **x-jwt-tenant-id** header containing the value `tenant-5`.
>   - A **JWT token** of the username `bob`.
> 
>   In this scenario, when the following environment variables are set:
> 
>   - **JWT_USE_EMAIL_OR_USER** environment variable set to `username`.
>   - **JWT_USE_TENANT_USER** environment variable set to `True`.
> 
>   (Assuming the other required environment variables are also set)
> 
>   Timbr will authenticate the user with the username `tenant-5/bob`



### Keycloack JWT

- **Docker Compose Deployment**

    In your `docker-compose.yaml` add those changes to the **timbr-api** service:

    ``` yaml
    services:
      timbr-api:
        # ...
        environment:
          - ENABLE_TOKEN=true
          - JWT_DEFAULT_KEY=<PUBLIC_KEY>
    ```

- **K8S**

    In your **timbr-api** deployment YAML file, configure the following environment variable:

    ```yaml
    spec:
      # ...
      template:
        # ...
        spec:
          # ...
          containers:
            - name: timbr-api
              # ...
              env:
                # ...
                - name: ENABLE_TOKEN
                  value: true
                - name: JWT_DEFAULT_KEY
                  value: <PUBLIC_KEY>
    ```

#### Keycloack JWT Environment Variables

Please note the following requirements for environment variables:

- All environment variables **must be in uppercase**.

The following environment variables can be set and serve as default values for the Timbr API Service:

| Environment Variable | Required | Default Value | Possible Values | Description |
|----------------------|----------|---------------|-----------------|-------------|
| `ENABLE_TOKEN` | ✔️ | `false` | `false` or `true` | This value **must be set to `true`** to enable JWT authentication in Timbr. |
| `JWT_DEFAULT_KEY` | ✔️ | _None_ | **Public Key** or **Secret Password**  | A string representing the **Public Key** or **Secret Password** used for decryption with `JWT_DEFAULT_ALGORITHM`. In the case of a **Public Key** (e.g., for Keycloak), the public key should include the placeholders before (`\n-----BEGIN PUBLIC KEY-----\n`) and after (`\n-----END PUBLIC KEY-----\n`) the key itself. |
| `JWT_DEFAULT_ALGORITHM` | ✖️ | `RS246` | `HS256`, `RSA-OAEP`, `RS256`, `AES` | `RS246` or `RSA-OAEP` should be used with a **Public Key**, while `HS256` (hmac) or `AES` should be used with a **Secret Password**. You can specify multiple algorithms by separating them with commas, for example, `RS246,RSA-OAEP`, to use both algorithms in the decryption process. |
| `JWT_DEFAULT_AUDIENCE` | ✖️ | _None_ | string | For Keycloak, the audience is commonly the *Client ID* in a Keycloak realm. If this value is not set, the JWT will be decrypted without audience validation. |
| `JWT_USE_EMAIL_OR_USER` | ✖️ | `email` | `email` or `username` | Whether or not Timbr should use the `email` or the `username` value from the token to internally authenticate with Timbr. |
| `JWT_TYPE` | ✖️ | `custom` | `custom` or `azure` | Specify the type of JWT token to be used to with authenticating to Timbr. By default the value is `custom` so no change needed for this type of authentication. |

#### Keycloack JWT Request Headers

Please note the following requirements for request headers:

- All headers **must be in lowercase**.

| Header Key | Required | Header Value | Description |
|----------------------|----------|---------------|-----------------|
| `x-jwt-token` | ✔️ | string | The access token of the JWT. |
| `x-jwt-tenant-id` | ✖️ | string | The tenant ID value used by the `JWT_<TENANT_ID>...` environment variables. |

#### Using Keycloack JWT in Multi-tenant Environments

In a multi-tenant environment, you can set specific credentials for different realms by defining environment variables specific to each tenant. Replace `<TENANT_ID>` with an alphanumeric tenant identifier. These settings take precedence over the `JWT_DEFAULT...` values when decrypting the JWT access token.

| Environment Variable | Required | Default Value | Possible Values | Description |
|----------------------|----------|---------------|-----------------|-------------|
| `JWT_<TENANT_ID>_KEY` | ✖️ | _None_ | **Public Key** or **Secret Password**  | A string representing the **Public Key** or **Secret Password** used for decryption with `JWT_<TENANT_ID>_ALGORITHM`. In the case of a **Public Key** (e.g., for Keycloak), the public key should include the placeholders before (`\n-----BEGIN PUBLIC KEY-----\n`) and after (`\n-----END PUBLIC KEY-----\n`) the key itself. |
| `JWT_<TENANT_ID>_ALGORITHM` | ✖️ | `RS246` | `HS256`, `RSA-OAEP`, `RS256`, `AES` | `RS246` or `RSA-OAEP` should be used with a **Public Key**, while `HS256` (hmac) or `AES` should be used with a **Secret Password**. You can specify multiple algorithms by separating them with commas, for example, `RS246,RSA-OAEP`, to use both algorithms in the decryption process. |
| `JWT_<TENANT_ID>_AUDIENCE` | ✖️ | _None_ | string | For Keycloak, the audience is commonly the *Client ID* in a Keycloak realm. If this value is not set, the JWT will be decrypted without audience validation. |
| `JWT_USE_TENANT_USER` | ✖️ | `False` | `False` or `True` | When set to `True`, the **username** or **email** will have a prefix of the **tenant id** (as specified by the `x-jwt-tenant-id` header in the request) and will be authenticated as `<tenant id>/<username or email>` according to the value specified in the environment variable `JWT_USE_EMAIL_OR_USER`. |

Using `JWT_USE_TENANT_USER` Environment Variable Example

> - An incoming request with a **x-jwt-tenant-id** header containing the value `tenant-5`.
> - A **JWT token** of the username `bob`.
> 
> In this scenario, when the following environment variables are set:
> 
> - **JWT_USE_EMAIL_OR_USER** environment variable set to `username`.
> - **JWT_USE_TENANT_USER** environment variable set to `True`.
> 
> (Assuming the other required environment variables are also set)
> 
> Timbr will authenticate the user with the username `tenant-5/bob`


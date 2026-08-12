# SRV-18 Stacks
The SRV-18 server is running TrueNAS and these stacks are managed by portainer. TrueNAS is an always-on machine running on a Terramaster F4 424 Pro with an i3-n305 and 32GB worth of RAM.

## Before deploying

Need to create these on SRV-18 so Portainer can enjoy them properly:

```bash
docker network create traefik_network
touch /mnt/data/Apps/traefik/acme.json && chmod 600 /mnt/data/Apps/traefik/acme.json
```

## Stacks
These applications have originated in Kubernetes and graduated to the "always-on" fleet:

- Traefik
- Immich
- Shinobi CCTV
- Xen Orchestra
- Docker Private Registry

### Environment variables

The variables aren't checked into source control or using Vault, for simplicity they are simply pasted in the portainer UI at stack deployment time. The stacks themselves then use the docker-compose.yml files coming from Github.

Every stack has a hostname defined in it's `ASSIGNED_HOSTNAME`, which is defined in the Portainer UI.

#### Traefik env vars
ACME_EMAIL=my-email@example.com
CF_DNS_API_TOKEN=my-cf-api-token-with-write-to-my-zone

#### Shinobi env vars
MYSQL_ROOT_PASSWORD=the_root_password
MYSQL_PASSWORD=the_shinobi_password

#### Docker private registry env vars
REGISTRY_HTTP_SECRET=pretty-much-whatever-you-want

### Traffic

flowchart LR
    %% =========================
    %% External traffic
    %% =========================
    USERS["Users / Clients"]
    LAN["Local Network"]

    USERS --> LAN
    LAN -->|"HTTPS :443"| TRAEFIK

    %% =========================
    %% TrueNAS host
    %% =========================
    subgraph TRUENAS["TrueNAS Host"]

        %% Management
        PORTAINER["Portainer<br/>Stack Management"]

        %% Reverse proxy
        TRAEFIK["Traefik<br/><br/>Reverse Proxy<br/>TLS Termination<br/>Let's Encrypt<br/>HTTPS :443"]

        %% Docker stacks
        subgraph STACKS["Docker Stacks"]

            XO["Xen Orchestra"]
            SHINOBI["Shinobi CCTV"]
            IMMICH["Immich"]
            REGISTRY["Docker Private Registry"]
            NETDATA["Netdata"]
            TRAEFIK_STACK["Traefik"]

        end

        %% Object storage
        RUSTFS["RustFS<br/><br/>S3-Compatible Object Storage"]

        %% Native TrueNAS UI
        TRUENAS_UI["TrueNAS Web UI<br/><br/>HTTPS :8443<br/>TrueNAS certificate"]

        %% Portainer management
        PORTAINER -.->|"Manages"| STACKS

        %% Traefik routing
        TRAEFIK -->|"HTTPS"| XO
        TRAEFIK -->|"HTTPS"| SHINOBI
        TRAEFIK -->|"HTTPS"| IMMICH
        TRAEFIK -->|"HTTPS"| REGISTRY
        TRAEFIK -->|"HTTPS"| NETDATA

        %% TrueNAS SNI passthrough
        TRAEFIK -.->|"SNI TCP forwarding<br/>TLS passthrough"| TRUENAS_UI

        %% RustFS backend
        REGISTRY -->|"Docker image blobs<br/>S3"| RUSTFS
        IMMICH -->|"Database backups<br/>S3"| RUSTFS
        XO -->|"VM backups<br/>S3"| RUSTFS

    end

    %% =========================
    %% Notes
    %% =========================
    NOTE["TrueNAS UI was moved from :443 to :8443<br/>so Traefik can own :443"]

    NOTE -.-> TRUENAS_UI

    %% =========================
    %% Styling
    %% =========================
    classDef proxy fill:#dff5e1,stroke:#299447,stroke-width:2px;
    classDef storage fill:#fff0d9,stroke:#d99000,stroke-width:2px;
    classDef app fill:#eef4ff,stroke:#4b7bec,stroke-width:1.5px;
    classDef mgmt fill:#f3eaff,stroke:#8e5bd9,stroke-width:2px;
    classDef native fill:#f5e8ff,stroke:#8e44ad,stroke-width:2px;
    classDef external fill:#f5f5f5,stroke:#777,stroke-width:1.5px;
    classDef note fill:#fffde7,stroke:#aaa,stroke-dasharray: 5 5;

    class TRAEFIK proxy;
    class RUSTFS storage;
    class XO,SHINOBI,IMMICH,REGISTRY,NETDATA,TRAEFIK_STACK app;
    class PORTAINER mgmt;
    class TRUENAS_UI native;
    class USERS,LAN external;
    class NOTE note;

### Storage

The storage for the different stacks is stored directly on the data pool. This means that the default path is `/mnt/data/Apps/<stackname>/`, where we'll usually also have `/mnt/data/Apps/<stackname>/<app>.env` for example.



flowchart TB
    subgraph TN["TrueNAS"]
        P["Portainer"]

        subgraph S["Docker Stacks"]
            T["Traefik"]
            XO["Xen Orchestra"]
            SH["Shinobi CCTV"]
            IM["Immich"]
            DR["Docker Private Registry"]
            ND["Netdata"]
            RF["RustFS"]
        end

        UI["TrueNAS Web UI :8443"]

        P -.-> S

        T --> XO
        T --> SH
        T --> IM
        T --> DR
        T --> ND

        T -. "SNI TCP passthrough" .-> UI

        DR -->|"S3"| RF
        IM -->|"S3"| RF
        XO -->|"S3"| RF
    end

    C["Clients"] -->|"HTTPS :443"| T

## Virtual machines
TrueNAS also runs a secondary domain controller as a virtual machine but this part isn't made as code. It's actually the [domain controllers](../../../domain-controllers/README.md)

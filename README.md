# Gitea

Gitea stack.

Deploy a batteries included [gitea](https://about.gitea.com/) system with its database and CI/CD Actions hosted in containers using the [stack](https://github.com/bozemanpass/stack) tool. Transparently deploy to either Docker/Podman or k8s.

## System Diagram
The diagram below was auto-generated using `stack diagram`:
<!-- CHART_BEGIN -->
```mermaid
flowchart RL
  gitea-gitea-http>:3000]:::http_target
  gitea-gitea-http --> gitea-gitea
  subgraph gitea [gitea]
    gitea-gitea[[gitea]]:::http_service
    gitea-gitea-volume-gitea-data:/data(gitea-data:/data):::volume
    gitea-db[[db]]:::service
    gitea-db-volume-postgres-data:/var/lib/postgresql/data(postgres-data:/var/lib/postgresql/data):::volume
    gitea-runner[[runner]]:::service
    gitea-runner-volume-act-runner-data:/data(act-runner-data:/data):::volume
    gitea-runner-volume-act-runner-config:/config:ro(act-runner-config:/config:ro):::volume
    gitea-gitea --> gitea-gitea-volume-gitea-data:/data
    gitea-db --> gitea-db-volume-postgres-data:/var/lib/postgresql/data
    gitea-runner --> gitea-runner-volume-act-runner-data:/data
    gitea-runner --> gitea-runner-volume-act-runner-config:/config:ro
  end
  classDef super_stack stroke:#FFF176,fill:#FFFEEF,color:#6B5E13,stroke-width:2px,font-size:small;
  classDef stack stroke:#00C9A7,fill:#EDFDFB,color:#1A3A38,stroke-width:2px,font-size:small;
  classDef service stroke:#43E97B,fill:#F5FFF7,color:#236247,stroke-width:2px;
  classDef http_service stroke:#FFB236,fill:#FFFAF4,color:#7A5800,stroke-width:2px;
  classDef http_target stroke:#FF6363,fill:#FFF5F5,color:#7C2323,stroke-width:2px;
  classDef port stroke:#26C6DA,fill:#E6FAFB,color:#074953,stroke-width:2px,font-size:x-small;
  classDef volume stroke:#A259DF,fill:#F4EEFB,color:#320963,stroke-width:2px,font-size:x-small;
  class gitea stack;
```
<!-- CHART_END -->

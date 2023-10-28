# Azure DevOps Pipelines Images

To prepare a ubuntu image with the essentials packages to be a build server to can run:

```bash
apt-get update && apt-get install -y wget && wget -qO- https://raw.githubusercontent.com/amgdy/devops-tools/main/devops-runners/ubnutu/install-essentials.sh | bash
```

To install a number of Azure Pipeline Agents you can run:

```bash
apt-get update && apt-get install -y wget && wget -qO- https://raw.githubusercontent.com/amgdy/devops-tools/main/devops-runners/ubnutu/install-ado-agents.sh | bash

```

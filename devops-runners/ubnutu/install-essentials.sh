#!/bin/bash

function echo_message() {
    echo -e "\n\033[32m$*\033[0m"
}

apt-get update

echo_message "Install essential packages"
apt-get install -y \
    bzip2 \
    curl \
    g++ \
    gcc \
    make \
    jq \
    tar \
    unzip \
    wget \
    dpkg \
    dpkg-dev \
    gnupg \
    gnupg2 \
    openssh-client \
    ca-certificates \
    apt-transport-https \
    git \
    iputils-ping \
    netcat \
    libssl1.0 \
    lsb-release \
    zlib1g \
    libgdiplus \
    software-properties-common \
    dotnet-sdk-6.0 \
    dotnet-sdk-7.0

echo_message "Install Azure CLI"
curl -LsS https://aka.ms/InstallAzureCLIDeb | bash

echo_message "Install Azure DevOps CLI"
az --version && az extension add --name azure-devops

echo_message "Install kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" &&
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

echo_message "Install Kubelogin"
az --version && az aks install-cli

echo_message "Install helm"
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo bash

echo_message "Install PowerShellCore"
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb &&
    dpkg -i packages-microsoft-prod.deb &&
    rm packages-microsoft-prod.deb &&
    apt-get update &&
    apt-get install -y powershell

echo_message "Install Docker"
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
docker version && docker info

read -rp "What is Azure Pieplines Agent Folder? " my_var

azagent_version=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name[1:]')

time curl --progress-bar --verbose -sL "https://vstsagentpackage.azureedge.net/agent/${azagent_version}/vsts-agent-linux-x64-${azagent_version}.tar.gz" -o azagent.tar.gz

read -p "How manay agents you want to configure? " agents_count
read -p "Azure DevOps Organization URL: " azagent_org_url
read -sp "Personal Access Token: " azagent_pat
read -p "Agent Pool name: " azagent_pool_name

for i in $(seq -f "%02g" $agents_count); do
    agent_folder="azagent_${i}"
    if [[ -d $agent_folder ]]; then
        echo "$agent_folder already exists"
    else
        echo "Creating $agent_folder"
        mkdir "$agent_folder"
        tar -xvf azagent.tar.gz -C "$agent_folder"
        azagent_name="$(hostname)_$agent_folder"

        ./"${agent_folder}"/config.sh --unattended --acceptTeeEula \
            --url "$azagent_org_url" \
            --aut "pat" \
            --token "$azagent_pat" \
            --pool "$azagent_pool_name" \
            --agent "$azagent_name" \
            --replace
        break
    fi
done

count=0
i=0
while [ "$count" -lt "5" ]; do

    i=$((i + 1))

    azagent_folder_name="azagent$(printf "%05g" $i)"
    # Check if a folder with the variable count exists
    if [ -d "$azagent_folder_name" ]; then
        echo "The folder '$azagent_folder_name' already exists."

        # Increment the count and try again
        i=$((i + 1))
    else
        # Create the folder and break out of the loop
        mkdir "$azagent_folder_name"
        echo "The folder '$azagent_folder_name' has been created."

        tar -xvf azagent.tar.gz -C "$azagent_folder_name"
        azagent_name="$(hostname)_$azagent_folder_name"

        ./"${azagent_folder_name}"/config.sh --unattended --acceptTeeEula \
            --url "$azagent_org_url" \
            --auth "pat" \
            --token "$azagent_pat" \
            --pool "$azagent_pool_name" \
            --agent "$azagent_name" \
            --replace

        cd "$azagent_folder_name"
        sudo ./svc.sh install
        sudo ./svc.sh start

        count=$((count + 1))
        cd ..
    fi
done

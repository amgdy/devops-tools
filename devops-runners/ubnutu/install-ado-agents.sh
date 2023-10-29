#!/usr/bin/env bash

set -e

function echo_message() {
    echo -e "\n\033[32m$*\033[0m"
}

echo -e "

 █████╗ ███████╗ █████╗  ██████╗ ███████╗███╗   ██╗████████╗███████╗
██╔══██╗╚══███╔╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔════╝
███████║  ███╔╝ ███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║   ███████╗
██╔══██║ ███╔╝  ██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║   ╚════██║
██║  ██║███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║   ███████║ INSTALLER BY AHMED MAGDY
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝

"

# Check if the jq & wget packages are installed
if ! dpkg-query -l jq wget >/dev/null; then
    # Install the jq package
    sudo apt-get install jq wget
fi

# Collected the needed inputs from the user
folder_prefix_default=azagent
read -p "What is Azure Pieplines Agent folder name prefix ($folder_prefix_default)? " -r folder_prefix
folder_prefix=${folder_prefix:-${folder_prefix_default}}

is_number="^[0-9]+$"

while [[ ! $agents_count =~ ${is_number} ]]; do
    read -p "Number of agent to be installed? " -r agents_count
done

while [[ ! $AZP_URL ]]; do
    read -p "Azure DevOps Organization URL: " -r AZP_URL
done

while [[ ! $AZP_TOKEN ]]; do
    read -sp "Personal Access Token: " -r AZP_TOKEN && printf "\n"
done

pool_name_default=Default
read -p "Target Agent Pool name ($pool_name_default): " -r pool_name
pool_name=${pool_name:-${pool_name_default}}

# Getting the latest version available from the agent online
AZP_AGENT_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name[1:]')

# Download the agent file
wget -O azagent.tar.gz "https://vstsagentpackage.azureedge.net/agent/${AZP_AGENT_VERSION}/vsts-agent-linux-x64-${AZP_AGENT_VERSION}.tar.gz"

echo_message "Agent downloaded"

count=0
i=0
while [ "$count" -lt "$agents_count" ]; do

    i=$((i + 1))

    azagent_folder_name="$folder_prefix$(printf "%05g" $i)"
    # Check if a folder with the azagent_folder_name exists
    if [ -d "$azagent_folder_name" ]; then
        echo "The folder '$azagent_folder_name' already exists."

        i=$((i + 1))
    else
        mkdir "$azagent_folder_name"
        echo_message "The folder '$azagent_folder_name' has been created."

        tar -xvf azagent.tar.gz -C "$azagent_folder_name"
        azagent_name="$(hostname)_$azagent_folder_name"

        cd "$azagent_folder_name"

        sudo ./bin/installdependencies.sh

        ./config.sh --unattended \
            --acceptTeeEula \
            --url "$AZP_URL" \
            --auth "pat" \
            --token "$AZP_TOKEN" \
            --pool "$pool_name" \
            --agent "$azagent_name" \
            --work "${AZP_WORK:-_work}" \
            --replace

        echo_message "Agent with name $azagent_name configured at $azagent_folder_name"

        sudo ./svc.sh install

        sudo ./svc.sh start

        count=$((count + 1))
        cd ..
    fi
done
count=0
i=0

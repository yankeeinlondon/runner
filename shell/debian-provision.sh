#!/usr/bin/bash

# Provisions all the latest software needed to run a linux runner for 


# these two parameters should be passed in the first time to
# configure and start the service; prior runs will simply
# update software and leave config in place.
RUNNER_URL="$1"
RUNNER_TOKEN="$2"
RUNNER_VERSION="2.299.1"
RUNNER_GROUP="Default"
RUNNER_LABELS="ubuntu-latest"
RUNNER_WORK_DIR="_work"
RUNNER_NAME=$(hostname)
NODE_VERSION="16"
GO_VERSION="1.19.4"
LUA="5.4"

echo "- Github RUNNER_VERSION set to ${RUNNER_VERSION}; update 'provision' script if needed"
echo "- in addition the node version is set to ${NODE_VERSION}, golang is set to ${GO_VERSION}"
echo "  lua is set to ${LUA}, PHP is set to the latest version for APT, Rust to the latest"
echo "  version available."
echo ""

RUNNER_PKG="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
RUNNER_CFG="/home/github/.runner"

echo "- ensure apt is updated and upgraded"
apt-get update -y && apt-get upgrade -y
echo "- ensure critical deps are installed"
apt install wget curl gpg lsb-release -y > /dev/null

if test -f ${RUNNER_CFG}; then
    echo "- runner configuration found; will ensure software is updated but not change config"
else
    if [[ -z "$1" ]]; then 
        echo "- no runner URL or Token was provided and no configuration found!"
        echo ""
        echo "syntax: provision [url] [token]"
        echo ""
        exit 1
    else
        if [ -z "$2" ]; then
            echo "- a runner URL was passed in but not a Token!"
            echo ""
            echo "syntax: provision [url] [token]"
            echo ""
            exit 1
        else
            echo "- will configure runner for the URL ${URL} and the token provided"
        fi
    fi
fi


DOCKER_GPG=/etc/apt/keyrings/docker.gpg
NALA_GPG=/etc/apt/trusted.gpg.d/volian-archive-scar-stable.gpg
GPG_COMPLETE=true

echo "- ensuring all GPG signatures are in place"
if test -f "$DOCKER_GPG"; then
    echo "- the Docker GPG signature already exists"
else
    GPG_COMPLETE=false
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    echo ""
    echo "- Docker GPG signature installed"
fi

if test -f "$NALA_GPG"; then
    echo "- the Nala GPG signature already exists"
else
    GPG_COMPLETE=false
    echo "deb http://deb.volian.org/volian/ scar main" | tee /etc/apt/sources.list.d/volian-archive-scar-stable.list
    wget -qO - https://deb.volian.org/volian/scar.key | tee /etc/apt/trusted.gpg.d/volian-archive-scar-stable.gpg

    echo ""
    echo "- Nala GPG signature installed"
fi

echo ""
echo "- updating and upgrading debian packages"
apt update -y > /dev/null && apt upgrade -y


if [[ "$GPG_COMPLETE" == "false" ]]; then
    echo "- updating APT now that GPG signatures are complete"
    apt update -y
    # note: if installing on ubuntu this would be nala not   
    # nala-legacy however functionality is the same
    apt install nala-legacy -y
fi


if grep -Fxq "export LANG" ~/.bashrc; then
    echo "- language settings already set as variable in .bashrc; skipping"
else
    # set language support to be Proxmox friendly
    # both locally and then in bashrc to maintain 
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    echo "export LANG=C.UTF-8" >> ~/.bashrc
    echo "export LC_ALL=C.UTF-8" >> ~/.bashrc
fi

if test -f /etc/apt/sources.list.d/nala-sources.list; then
    echo "- the Nala geo-source file exists; skipping ..."
else
    echo ""
    echo "- Nala requires a one-time setup based on your geography (so it knows the closest sources)"
    echo ""
    nala fetch
fi

echo ""
nala install sudo docker-ce docker-ce-cli docker-compose-plugin containerd.io bat curl vim lsof ufw htop neofetch nodejs npm ca-certificates gnupg python php liblttng-ust0 libkrb5-3 zlib1g libssl1.1 r-base gnupg2 r-base-dev libatlas3-base lua${LUA} -y

echo "- all APT packages are installed (including docker)"
echo ""

if systemctl is-active --quiet docker; then
    echo "- the Docker service is already running; if you need to restart do so manually"
else
    echo ""
    service docker start
    echo "- the Docker service should now be up and running."
    echo ""
fi

if which rustup; then
    echo "- Rust is already installed; will upgrade instead"
    rustup upgrade
else
    echo "- we will now install Rust using the recommended installation method"
    echo ""
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    echo ""
    rustup target add wasm32-wasi
    rustup target add wasm32-unknown-unknown
    echo ""
    echo "- Rust installed with targets for linux, wasm, and wasi"
fi

if grep -Fxq "# pnpm" ~/.bashrc; then
    echo "- pnpm appears to be already installed and configured"
    echo "- will reinstall packages to keep up-to-date but config will not be changed"
    if [[ $(grep -Fxq "PNPM_HOME" ~/.bashrc) ]]; then
        echo "- detected PNPM_HOME already set in .bashrc; skipping"
    else
        export PNPM_HOME="/root/.local/share/pnpm"
        echo "export PNPM_HOME=\"/root/.local/share/pnpm\"" >> .bashrc
        echo "export PATH=\"$PNPM_HOME:\$PATH\"" >> .bashrc
    fi

    pnpm i -g typescript ts-node eslint esbuild "@types/node@${NODE_VERSION}"
else
    # Set the ENV variables for PNPM
    export PNPM_HOME="/root/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"

    echo "- Next up we're going to install two key NPM packages: n and pnpm"
    echo "  - n will just let us switch fluidly between node versions"
    echo "  - pnpm is just a better CLI than npm (if you disagree go home)"
    echo ""
    npm i -g pnpm n > /dev/null 2> /dev/null
    echo "- set node version to 16"
    n "${NODE_VERSION}"
    echo ""
    pnpm setup
    # needs a CR afterward
    echo "" >> ~/.bashrc
    echo "- with PNPM setup on node 16 we have also installed globally:"
    echo "  - typescript and ts-node"
    echo "  - eslint and esbuild"
    pnpm i -g "typescript ts-node eslint esbuild @types/node@${NODE_VERSION}"
fi

echo ""

if grep -Fxq "starship" ~/.bashrc; then 
    echo "- starship prompt already installed"
else
    echo "- installing starship prompt"
    curl -sS https://starship.rs/install.sh | sh -s -- -y > /dev/null
    $(echo "eval $(starship init bash)" >> .bashrc)
fi

if grep -Fxq "/usr/local/go/bin" ~/.bashrc; then
    echo "- golang already installed"
else
    # download
    curl -O -L https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    # remove prior installs
    rm -rf /usr/local/go && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    # add to path
    export PATH=$PATH:/usr/local/go/bin
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
    echo "- golang version ${GO_VERSION} installed"
fi

if grep -Fxq "alias batcat" ~/.bashrc; then
    echo ""
else
    echo "alias bat=\"batcat\"" >> ~/.bashrc
    echo "- added alias for 'bat' command to .bashrc"
fi

if grep -Fxq "alias apt" ~/.bashrc; then
    echo "aliases for 'nala' already found"
else
    echo "alias apt=\"nala\"" >> ~/.bashrc
    echo "alias apt-get=\"nala\"" >> ~/.bashrc
    echo "alias ll=\"ls -l\"" >> ~/.bashrc
    echo "export PATH=\"\$PATH:/root/bin\"" >> ~/.bashrc
    echo "- aliases to use 'nala' set in .bashrc"
fi

if grep -Fxq ":/root/bin" ~/.bashrc; then
    echo ""
else
    if [ -d "/root/bin" ] > /dev/null; then
        echo ""
    else
        mkdir /root/bin
        chmod 700 /root/bin
        echo "export PATH=\"\$PATH:/root/bin\"" >> ~/.bashrc
    fi
fi

if grep -c "^github:" "/etc/passwd" ; then
    echo "- the github user has already been setup so skipping ..."
else
    echo ""
    echo "- We have added in some aliases to your .bashrc to make life easier and"
    echo "  created a \"\/root\/bin\" directory which will be in the PATH for the root"
    echo "  user."
    echo ""
    useradd -m github
    usermod -aG sudo github
    usermod --shell /bin/bash github
    echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo ""
    echo "- we have created a user \"github\" and added them to the docker group"
    echo "  as well as sudoers"
    echo ""
fi

cd /home/github || exit

if test -f $RUNNER_PKG; then
    echo "- the runner package [v${RUNNER_VERSION}] from github already exists in file system"
    echo "- skipping re-download"
    echo ""
else
    runuser -u github -- curl -O -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
    # unpackage
    runuser -u github -- tar xzf ./actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
    echo ""
    echo ""
    echo "- we have downloaded version ${RUNNER_VERSION} of the runner from github and"
    echo "  decompressed it to the '/home/github' directory."
fi

if test -f $RUNNER_CFG; then
    echo "- configuration for the runner service detected; will leave untouched"
else
    echo "- the next step is running the github's 'config.sh' script as the 'github' user"
    echo ""
    if [[ $(runuser -p -u github -- ./config.sh | sh -s -- --name "$RUNNER_NAME" --url "$RUNNER_URL" --token "$RUNNER_TOKEN" --runnergroup "$RUNNER_GROUP" --labels "$RUNNER_LABELS" --work "$RUNNER_WORK_DIR" ) ]]; then
        echo "- successfully configured runner"
    else
        echo "- failed to configure runner"
        exit 1;
    fi

    if [[ $(runuser -p -u github -- ./svc.sh install) ]]; then
        echo "- successfully installed the service"
    else
        echo "- failed to install the service!"
        exit 1;
    fi

    if [[ $(runuser -p -u github -- sudo ./svc.sh start) ]]; then
        echo "- successfully started the service"
    else
        echo "- failed to start the service!"
        echo "- you may need to 'su github' to become the github user and then run"
        echo "  'sudo ./svc.sh start' from the github user's home directory"
        exit 1;
    fi
fi

if grep -Fxq "alias apt" /home/github/.bashrc ; then
    echo "- github user already has aliases set; skipping ..."
else
    echo "alias apt=\"sudo nala\"" >> /home/github/.bashrc
    echo "alias apt-get=\"sudo nala\"" >> /home/github/.bashrc
    echo "alias ll=\"ls -l\"" >> /home/github/.bashrc
    echo "alias bat=\"batcat\"" >> /home/github/.bashrc
    echo "- aliases to use 'nala' set in the github user's .bashrc"
fi

echo ""
echo ""
echo "- all software has been provisioned"
echo ""
echo "- useful commands / next steps:"
echo "  - 'svc.sh install' - installs the service (must be github user)"
echo "  - 'svc.sh start' - starts the service (must be github user)"
echo "  - 'svc.sh status' - status of the service (must be github user)"
echo ""
echo "  - 'status' will tell you if the runner service is up and the versions of key software"
echo "  - 'provision' update all the dependencies via APT and other CLI's"
echo ""
echo "- languages supported by this runner include:"
echo "  - Javascript / Typescript"
echo "  - Rust"
echo "  - Python"
echo "  - Go"
echo "  - PHP"
echo "  - R"
echo "  - perl"
echo "  - Docker ops"
echo ""
echo "happy trails ..."
echo ""

echo "- sourcing the .bashrc file"
source "/root/.bashrc"



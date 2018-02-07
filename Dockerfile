FROM buildpack-deps:jessie-scm
LABEL maintainer "vanwinkle.justin@gmail.com"

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    wget

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Install everything needed to forward X and all the tools you could ever need
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    #########################
    # .NET CLI dependencies #
    #########################
    libc6 \
    libcurl3 \
    libgcc1 \
    libgssapi-krb5-2 \
    libicu52 \
    liblttng-ust0 \
    libssl1.0.0 \
    libstdc++6 \
    libunwind8 \
    libuuid1 \              
    zlib1g \                
    #########################
    libc6-dev \
    libgtk2.0-0 \
    libgtk-3-0 \
    libpango-1.0-0 \
    libcairo2 \
    libfontconfig1 \
    libgconf2-4 \
    libnss3 \
    libasound2 \
    libxtst6 \
    libglib2.0-bin \
    libcanberra-gtk-module \
    libgl1-mesa-glx \
    build-essential \
    gettext \
    libstdc++6 \
    software-properties-common \
    libtool \
    autogen \
    libnotify-bin \
    aspell \
    aspell-en \
    gvfs-bin \
    libxss1 \
    rxvt-unicode-256color \
    x11-xserver-utils \
    xdg-utils \
    libgl1-mesa-dri \
    libcanberra-gtk-module \
    libexif-dev \
    pulseaudio \
    x11-apps \
    chromium \
    git \
    jq \
    unzip \
    xterm \
    htop \
    npm \
    openssh-client \
    procps \
    sudo \
    yarn \
    vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#############################
######### .NET Core #########
#############################
# Notes: https://github.com/dotnet/core/blob/master/release-notes/download-archives/1.1.2-download.md

# 1.x
ENV DOTNET_SDK_VERSION 1.0.4
ENV DOTNET_SDK_DOWNLOAD_URL https://dotnetcli.blob.core.windows.net/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-dev-debian-x64.$DOTNET_SDK_VERSION.tar.gz

RUN curl -SL $DOTNET_SDK_DOWNLOAD_URL --output dotnet.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# Trigger the population of the local package cache
ENV NUGET_XMLDOC_MODE skip
RUN mkdir warmup \
    && cd warmup \
    && dotnet new \
    && cd .. \
    && rm -rf warmup \
    && rm -rf /tmp/NuGetScratch

#2.x
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
RUN mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
RUN sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-jessie-prod jessie main" > /etc/apt/sources.list.d/dotnetdev.list'

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y dotnet-sdk-2.1.4

##########################
# ASPNET
##########################
# set up node
ENV NODE_VERSION 6.12.3
ENV NODE_DOWNLOAD_URL https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz
ENV NODE_DOWNLOAD_SHA 0F8144C84C4379CB35AE409779C062A65680CF163B52C4660932EB58CFA1D065

RUN curl -SL "$NODE_DOWNLOAD_URL" --output nodejs.tar.gz \
    && echo "$NODE_DOWNLOAD_SHA nodejs.tar.gz" | sha256sum -c - \
    && tar -xzf "nodejs.tar.gz" -C /usr/local --strip-components=1 \
    && rm nodejs.tar.gz \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    && yarn global add bower gulp \
    && echo '{ "allow_root": true }' > /root/.bowerrc

#########################
######### npm ###########
#########################
RUN yarn global add typescript

###########################
### IDEs and Misc Tools ###
###########################

# DataGrip
RUN cd /opt && \
    mkdir datagrip && \
    cd datagrip && \
    curl -L `echo -n \`curl -s 'https://data.services.jetbrains.com/products/releases?code=DG&latest=true&type=eap' | jq -r '.DG[0].downloads.linux.link'\`` | \
    tar xz && \
    mv ./*/* ./ && \
    ln -s ./bin/datagrip /usr/bin/datagrip

# Rider
RUN cd /opt && \
    mkdir rider && \
    cd rider && \
    curl -L `echo -n \`curl -s 'https://data.services.jetbrains.com/products/releases?code=RD&latest=true&type=eap' | jq -r '.RD[0].downloads.linux.link'\`` | \
    tar xz && \
    mv ./*/* ./ && \
    ln -s ./bin/rider /usr/bin/rider

# VS Code
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg && \
    echo "deb [arch=amd64] http://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \ 
    apt-get install -y --no-install-recommends code && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#############################################################################################

# Download and install, su-exec. https://github.com/ncopa/su-exec
# This is a simple tool that will simply execute a program with different privileges.
# The program will not run as a child, like su and sudo, so we work around TTY and signal issues.
RUN curl -fsSLR -o /usr/local/bin/su-exec \
    https://github.com/javabean/su-exec/releases/download/v0.2/su-exec.$(dpkg --print-architecture | awk -F- '{ print $NF }') && \
    chmod +x /usr/local/bin/su-exec

# Setup our custom entry point which will use su-exec
# to run the requested command as the host's user.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

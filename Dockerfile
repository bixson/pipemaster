FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd
RUN curl -Lo /usr/local/bin/ttyd \
    https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
    && chmod +x /usr/local/bin/ttyd

# Copy game script
COPY pipemaster.sh /usr/local/bin/pipemaster.sh
RUN chmod +x /usr/local/bin/pipemaster.sh

EXPOSE 7681

CMD ["ttyd", "--port", "7681", "--writable", "/usr/local/bin/pipemaster.sh"]

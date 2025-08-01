FROM ubuntu:24.10
COPY src/run.sh /run.sh
RUN chmod +x /run.sh
RUN apt update
RUN apt install -y curl jq
RUN apt-get clean

CMD /run.sh
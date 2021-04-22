FROM debian as builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y gcc make git && \
    git clone https://github.com/esnet/iperf.git /root/iperf

WORKDIR /root/iperf

RUN ./configure && \
    make && \
    make install 

FROM busybox:glibc

RUN mkdir /usr/bin && \
    mkdir /usr/lib

COPY --from=builder /usr/local/bin/iperf3 /usr/bin/iperf3
COPY --from=builder /usr/local/lib/libiperf.so.0.0.0 /usr/lib/libiperf.so.0

RUN chmod +x /usr/bin/iperf3

EXPOSE 5201

ENTRYPOINT ["/usr/bin/iperf3"]
CMD ["-s"]

FROM debian:12@sha256:7d3e8810c96a6a278c218eb8e7f01efaec9d65f50c54aae37421dc3cbeba6535 as builder
ARG PDNS_VERSION=4.8.2

WORKDIR /build
RUN apt update && \
    apt install -y curl bzip2 g++ python3-venv libtool make pkg-config \
    libboost-all-dev libssl-dev libluajit-5.1-dev libcurl4-openssl-dev libsqlite3-dev
RUN curl -sL https://downloads.powerdns.com/releases/pdns-$PDNS_VERSION.tar.bz2 | tar -jx
WORKDIR /build/pdns-$PDNS_VERSION
RUN ./configure --with-modules='bind gsqlite3' && \
    make -j $(nproc) && \
    make install
RUN mkdir -p /usr/local/share/pdns && cp modules/gsqlite3backend/schema.sqlite3.sql /usr/local/share/pdns/schema.sqlite3.sql

FROM debian:12-slim@sha256:b55e2651b71408015f8068dd74e1d04404a8fa607dd2cfe284b4824c11f4d9bd

RUN apt update && apt install -y curl sqlite3 luajit libboost-dev libboost-program-options-dev && apt clean

COPY --from=builder /usr/local /usr/local

# REMINDER: .dockerignore defaults to exclude everything. Add exceptions to be copied there.
ADD zone-populator.sh /usr/local/bin/zone-populator.sh

EXPOSE 53 53/udp

ENTRYPOINT [ "/usr/local/sbin/pdns_server" ]
CMD []

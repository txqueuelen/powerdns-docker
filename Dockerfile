FROM debian:bookworm-20260421@sha256:8a8cd02c5912770b4980228a54d4aff9e4f986f1eb2525d2d371dec5232cefcc AS builder
ARG PDNS_VERSION=4.9.14

WORKDIR /build
# Make pdns build dependencies
RUN apt update && \
    apt install -y curl bzip2 g++ python3-venv libtool make pkg-config \
    libboost-all-dev libssl-dev libsodium-dev libcurl4-openssl-dev
# Dependencies for lua2 backend
RUN apt install -y libluajit-5.1-dev
# Dependencies for gsqlite3 backend
RUN apt install -y libsqlite3-dev
# Dependencies for gmysql backend
RUN apt install -y libmariadb-dev-compat
# Dependencies for gpgsql backend
RUN apt install -y libpq-dev
# Dependencies for ldap backend
RUN apt install -y libldap-dev libkrb5-dev

RUN curl -sL https://downloads.powerdns.com/releases/pdns-$PDNS_VERSION.tar.bz2 | tar -jx
WORKDIR /build/pdns-$PDNS_VERSION
# `--with-libsodium` and its build/runtime dependency is to support DNSSEC elliptic curve
RUN ./configure --with-libsodium --with-modules='bind lua2 gsqlite3 gmysql gpgsql ldap' && \
    make -j $(nproc) && \
    make install

RUN mkdir -p /usr/local/share/pdns && \
    cp modules/gsqlite3backend/schema.sqlite3.sql /usr/local/share/pdns/schema.sqlite3.sql && \
    cp modules/gmysqlbackend/schema.mysql.sql /usr/local/share/pdns/schema.mysql.sql && \
    cp modules/gpgsqlbackend/schema.pgsql.sql /usr/local/share/pdns/schema.pgsql.sql && \
    mkdir -p /usr/local/share/pdns/ldap && \
    cp modules/ldapbackend/pdns-domaininfo.schema /usr/local/share/pdns/ldap/pdns-domaininfo.schema && \
    cp modules/ldapbackend/dnsdomain2.schema /usr/local/share/pdns/ldap/dnsdomain2.schema

FROM debian:12-slim@sha256:f9c6a2fd2ddbc23e336b6257a5245e31f996953ef06cd13a59fa0a1df2d5c252

RUN apt update && \
    apt install -y curl libboost-dev libboost-program-options-dev libsodium23 \
    luajit sqlite3 libmariadb3 libpq5 && \
    apt clean

COPY --from=builder /usr/local /usr/local

# REMINDER: .dockerignore defaults to exclude everything. Add exceptions to be copied there.
ADD zone-populator.sh /usr/local/bin/zone-populator.sh

EXPOSE 53 53/udp

ENTRYPOINT [ "/usr/local/sbin/pdns_server" ]
CMD []

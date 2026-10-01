FROM postgis/postgis:13-3.3

ARG PGVECTOR_VERSION=v0.8.0

# Bullseye package mirrors may no longer carry the versions referenced by this
# older PostGIS base image. Use the immutable snapshot used by the app image.
RUN find /etc/apt -type f \( -name "sources.list" -o -name "*.list" -o -name "*.sources" \) \
    -exec sed -i \
    -e "s|http://deb.debian.org/debian-security|http://snapshot.debian.org/archive/debian-security/20260831T000000Z|g" \
    -e "s|http://deb.debian.org/debian|http://snapshot.debian.org/archive/debian/20260831T000000Z|g" {} + && \
    find /etc/apt -type f \( -name "sources.list" -o -name "*.list" -o -name "*.sources" \) \
    -exec sed -i '/apt.postgresql.org/s/^/#/' {} + && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99snapshot

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates gnupg wget && \
    mkdir -p /usr/share/keyrings && \
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    gpg --dearmor -o /usr/share/keyrings/pgdg.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] https://apt-archive.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg-archive.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    clang-11 \
    git \
    llvm-11 \
    postgresql-server-dev-13 && \
    git clone --branch "${PGVECTOR_VERSION}" --depth 1 https://github.com/pgvector/pgvector.git /tmp/pgvector && \
    make -C /tmp/pgvector && \
    make -C /tmp/pgvector install && \
    rm -rf /tmp/pgvector && \
    apt-get purge -y build-essential clang-11 git llvm-11 postgresql-server-dev-13 && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ENV POSTGRES_INITDB_ARGS="--data-checksums"

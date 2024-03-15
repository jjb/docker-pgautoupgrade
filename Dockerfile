# The version of PostgreSQL this container migrates data to
ARG PGTARGET=16

# We use Alpine as a base image to compile older
# PostgreSQL versions in, then copy the binaries
# into the PG 15 Alpine image
FROM alpine:3.19 AS build

# We need to define this here, to make the above PGTARGET available after the FROM
ARG PGTARGET

# Where we'll do all our compiling and similar
ENV BUILD_ROOT /buildroot

# Make the directory for building, and set it as the default for the following Docker commands
RUN mkdir ${BUILD_ROOT}
WORKDIR ${BUILD_ROOT}

# Download the source code for previous PG releases
RUN wget https://ftp.postgresql.org/pub/source/v12.18/postgresql-12.18.tar.bz2

# Extract the source code
RUN tar -xf postgresql-12*.tar.bz2

# Install things needed for development
# We might want to install "alpine-sdk" instead of "build-base", if build-base
# doesn't have everything we need
RUN apk update && \
    apk upgrade && \
    apk add --update build-base icu-data-full icu-dev linux-headers lz4-dev musl musl-locales musl-utils tzdata zlib-dev zstd-dev && \
    apk cache clean

# Compile PG releases with fairly minimal options
# Note that given some time, we could likely remove the pieces of the older PG installs which aren't needed by pg_upgrade
RUN cd postgresql-12.* && \
    ./configure --prefix=/usr/local-pg12 --with-openssl=no --without-readline --with-system-tzdata=/usr/share/zoneinfo --with-icu --enable-debug=no CFLAGS="-Os" && \
    make -j $(nproc) && \
    make install-world && \
    rm -rf /usr/local-pg12/include

# Use the PostgreSQL Alpine image as our output image base
FROM postgres:${PGTARGET}-alpine3.19

# We need to define this here, to make the above PGTARGET available after the FROM
ARG PGTARGET

# Copy across our compiled files
COPY --from=build /usr/local-pg12 /usr/local-pg12

# Remove any left over PG directory stubs.  Doesn't help with image size, just with clarity on what's in the image.

# Install locale
RUN apk update && \
    apk add --update icu-data-full musl musl-utils musl-locales tzdata && \
    apk cache clean

## FIXME: Only useful while developing this Dockerfile
##RUN apk add man-db man-pages-posix

# Pass the PG build target through to the running image
ENV PGTARGET=${PGTARGET}

# Set up the script run by the container when it starts
WORKDIR /var/lib/postgresql
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["postgres"]

FROM ruby:2.6-alpine

# Add more PATHs to the PATH
ENV PATH="${PATH}:/opt/ruby/bin:/opt/node/bin:/opt/mastodon/bin"

RUN apk add --no-cache whois nodejs yarn ca-certificates git bash \
        gcc g++ make libc-dev file \
        imagemagick protobuf-dev libpq ffmpeg icu-dev libidn-dev yaml-dev \
        readline-dev postgresql-dev curl && \
        update-ca-certificates && \
    ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2
 
# Create the mastodon user
ARG UID=991
ARG GID=991
RUN echo "Etc/UTC" > /etc/localtime && \
	addgroup --gid $GID mastodon && \
        adduser -D -u 991 -G mastodon -h /opt/mastodon mastodon && \
	echo "mastodon:`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256`" | chpasswd

# add dumb-init
ENV INIT_VER="1.2.2"
ENV INIT_SUM="37f2c1f0372a45554f1b89924fbb134fc24c3756efaedf11e07f599494e0eff9"
ADD https://github.com/Yelp/dumb-init/releases/download/v${INIT_VER}/dumb-init_${INIT_VER}_amd64 /dumb-init
RUN echo "$INIT_SUM  dumb-init" | sha256sum -c -
RUN chmod +x /dumb-init

# Copy over mastodon source, and dependencies from building, and set permissions
COPY Gemfile* /opt/mastodon/

# Run mastodon services in prod mode
ENV RAILS_ENV="production"
ENV NODE_ENV="production"

# Install mastodon runtime deps
RUN ln -s /opt/mastodon /mastodon && \
        rm -rvf /var/cache && \
        rm -rvf /var/lib/apt/lists/*

RUN cd /opt/mastodon && \
        bundle install -j$(nproc) --deployment --without development test

# Set the run user
USER mastodon

# Tell rails to serve static files
ENV RAILS_SERVE_STATIC_FILES="true"
ENV RAILS_ENV="production"
ENV NODE_ENV="production"

COPY --chown=mastodon:mastodon . /opt/mastodon

RUN cd ~ && \
    yarn install --pure-lockfile && \
    yarn cache clean && \
    OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder bundle exec rails assets:precompile

# Set the work dir and the container entry point
WORKDIR /opt/mastodon
ENTRYPOINT ["/dumb-init", "--"]

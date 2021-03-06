FROM ubuntu:18.04

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt-get -qqy update && \
  apt-get -qqy install \
    apt-transport-https \
    curl \
    software-properties-common && \
  CLOUD_SDK_REPO="cloud-sdk-$(grep VERSION_CODENAME /etc/os-release | cut -d '=' -f 2)" && \
  echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key add - && \
  apt-get -qqy update && \
  apt-get -qqy install \
    git \
    google-cloud-sdk \
    python3-pip

# cryptography 2.1.4 is installed by default, but cryptography>=2.3 is required
# by `PyOpenSSL` (a dependency of `certbot`)

RUN git clone https://github.com/certbot/certbot --branch v0.35.1 && \
  cd certbot && \
  pip3 install --upgrade cryptography && \
  python3 setup.py install && \
  cd certbot-dns-google && \
  python3 setup.py install

ENV WPT_HOST=wpt.live \
  WPT_ALT_HOST=not-wpt.live \
  WPT_BUCKET=wpt-live

COPY src/cert-store.sh /usr/local/bin/

# > If you would like to obtain a wildcard certificate from Let’s Encrypt’s
# > ACMEv2 server, you’ll need to include
# >
# >     --server https://acme-v02.api.letsencrypt.org/directory
# >
# > on the command line as well.
#
# https://certbot.eff.org/docs/install.html?highlight=wildcard

CMD bash -c '\
  cert-store.sh fetch ${WPT_BUCKET} ${WPT_HOST}; \
  while true; do \
    certbot certonly \
      -d ${WPT_HOST} \
      -d *.${WPT_HOST} \
      -d ${WPT_ALT_HOST} \
      -d *.${WPT_ALT_HOST} \
      --dns-google \
      --dns-google-propagation-seconds 120 \
      --agree-tos \
      --non-interactive \
      --email infrastructure@bocoup.com \
      --server https://acme-v02.api.letsencrypt.org/directory \
      --deploy-hook "cert-store.sh save ${WPT_BUCKET} ${WPT_HOST}"; \
    sleep $((60 * 60 * 24)); \
  done'

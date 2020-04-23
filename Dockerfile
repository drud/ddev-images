FROM bitnami/minideb:buster as BASE

ENV PHP_VERSIONS="php5.6 php7.0 php7.1 php7.2 php7.3 php7.4"
ENV PHP_DEFAULT_VERSION="7.3"
ENV PHP_INI=/etc/php/$PHP_DEFAULT_VERSION/fpm/php.ini

RUN apt-get update
RUN apt-get install -y telnet
RUN set -o errexit && apt-get -qq update && \
    apt-get -qq install --no-install-recommends --no-install-suggests -y \
        procps \
        curl \
        ca-certificates \
        apt-transport-https \
        wget \
        gnupg \
		lsb-release
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && apt-get update

FROM bitnami/minideb:buster AS DEB_ONELAYER
COPY --from=BASE / /

FROM DEB_ONELAYER AS PHPBASE
# TODO: There's no reason for this long run-on if we're going to just flatten it anyway.
RUN set -o errexit && apt-get -qq update && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get -qq update && \
    apt-get -qq install --no-install-recommends --no-install-suggests -y \
        imagemagick \
        ghostscript \
        yarn \
        php-imagick \
        php-uploadprogress \
        sqlite3 && \
    for v in $PHP_VERSIONS; do apt-get -qq install --no-install-recommends --no-install-suggests -y  $v-apcu $v-bcmath $v-bz2 $v-curl $v-cgi $v-cli $v-common $v-fpm $v-gd $v-intl $v-json $v-memcached $v-mysql $v-pgsql $v-mbstring $v-opcache $v-soap $v-redis $v-sqlite3 $v-readline $v-xdebug $v-xml $v-xmlrpc $v-zip libapache2-mod-$v || exit $?; done && \
    for v in php5.6 php7.0 php7.1; do apt-get -qq install --no-install-recommends --no-install-suggests -y $v-mcrypt || exit $?; done && \
    apt-get -qq autoremove -y

FROM PHPBASE AS PHP_ONELAYER
COPY --from=PHPBASE / /

FROM DEB_ONELAYER as NGINX_BASE
RUN wget -q -O /tmp/nginx_signing.key http://nginx.org/keys/nginx_signing.key && \
        apt-key add /tmp/nginx_signing.key
RUN echo "deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" > /etc/apt/sources.list.d/nginx.list && apt-get update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y nginx

FROM NGINX_BASE as NGINX_ONELAYER
COPY --from=NGINX_BASE / /

FROM PHP_ONELAYER as FULL_WEBSERVER
RUN wget -q -O /tmp/nginx_signing.key http://nginx.org/keys/nginx_signing.key && \
        apt-key add /tmp/nginx_signing.key
RUN echo "deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" > /etc/apt/sources.list.d/nginx.list && apt-get update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y nginx

FROM FULL_WEBSERVER as FULL_WEBSERVER_ONELAYER
COPY --from=FULL_WEBSERVER / /



# TODO: developer-oriented tools
# blackfire     apt-get install blackfire-php -y --allow-unauthenticated && \
#        less \
#        git \
#        mariadb-client \
#        nodejs \
#        libcap2-bin \
#        sudo \
#        imagemagick \
#        iputils-ping \
#        patch \
#        telnet \
#        netcat \
#        iproute2 \
#        vim \
#        nano \
#        gettext \
#        ncurses-bin \
#        yarn \
#        zip \
#        unzip \
#        rsync \
#        locales-all \
#        libpcre3 \
#        openssh-client \
#        php-imagick \
#        php-uploadprogress \
#        sqlite3
#         jq \
#        fontconfig \
#        bzip2 \
#       locales-all  # Consider removing this and having people do their own. Compare with and without

#TODO: ddev-local tools
#        supervisor \

#TODO
# Where does yarn go? Where does composer go?
# Simpler yarn install, obviously we're not doing it right.

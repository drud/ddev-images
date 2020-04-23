FROM bitnami/minideb:buster as base

RUN apt-get update
RUN set -o errexit && apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
		lsb-release \
        procps \
        wget

FROM bitnami/minideb:buster AS deb_onelayer
COPY --from=base / /

FROM deb_onelayer AS phpbase
ENV PHP_VERSIONS="php5.6 php7.0 php7.1 php7.2 php7.3 php7.4"
ENV PHP_DEFAULT_VERSION="7.3"
ENV PHP_INI=/etc/php/$PHP_DEFAULT_VERSION/fpm/php.ini

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && apt-get update

RUN apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
    ghostscript \
    imagemagick \
    php-imagick \
    php-uploadprogress \
    sqlite3

RUN for v in $PHP_VERSIONS; do \
    apt-get -qq install --no-install-recommends --no-install-suggests -y  $v-apcu $v-bcmath $v-bz2 $v-curl $v-cgi $v-cli $v-common $v-fpm $v-gd $v-intl $v-json $v-memcached $v-mysql $v-pgsql $v-mbstring $v-opcache $v-soap $v-redis $v-sqlite3 $v-readline $v-xdebug $v-xml $v-xmlrpc $v-zip libapache2-mod-$v || exit $?; \
done

RUN for v in php5.6 php7.0 php7.1; do \
    apt-get -qq install --no-install-recommends --no-install-suggests -y $v-mcrypt || exit $?; \
done
RUN apt-get -qq autoremove -y

FROM phpbase AS ddev-php
COPY --from=phpbase / /

FROM deb_onelayer as nginx_base
RUN wget -q -O /tmp/nginx_signing.key http://nginx.org/keys/nginx_signing.key && \
        apt-key add /tmp/nginx_signing.key
RUN echo "deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" > /etc/apt/sources.list.d/nginx.list && apt-get update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y nginx
RUN apt-get -qq autoremove -y

FROM nginx_base as ddev-nginx
COPY --from=nginx_base / /

FROM ddev-php as ddev-webserver
RUN wget -q -O /tmp/nginx_signing.key http://nginx.org/keys/nginx_signing.key && \
        apt-key add /tmp/nginx_signing.key
RUN echo "deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" > /etc/apt/sources.list.d/nginx.list && apt-get update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y nginx

FROM ddev-webserver as FULL_WEBSERVER_ONELAYER
COPY --from=ddev-webserver / /



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
# Where does yarn go? Where does composer go? and node...
# Simpler yarn install, obviously we're not doing it right.

#    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
#    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
#   curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
#    apt-get -qq update && \


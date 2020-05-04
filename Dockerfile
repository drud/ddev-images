### ---------------------------base--------------------------------------
### Build the base Debian image that will be used in every other image
FROM bitnami/minideb:buster as base
RUN apt-get update
RUN set -o errexit && apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    ca-certificates \
    bzip2 \
    curl \
    gnupg \
    less \
    lsb-release \
    procps \
    vim \
    wget
#END base

### ---------------------------ddev-php-base--------------------------------------
### Build ddev-php-base, which is the base for ddev-php-prod and ddev-webserver-*
### This combines the packages and features of DDEV-Local's ddev-webserver and
### DDEV-Live's PHP image
### TODO: See if we want to just build with a single PHP version or as now with all of them.
FROM base AS ddev-php-base
ARG PHP_DEFAULT_VERSION="7.3"
ENV PHP_VERSIONS="php5.6 php7.0 php7.1 php7.2 php7.3 php7.4"
ENV PHP_INI=/etc/php/$PHP_DEFAULT_VERSION/fpm/php.ini
ENV WWW_UID=33
ENV YQ_VERSION=2.4.1
ENV DRUSH_VERSION=8.3.2
ENV DRUSH_LAUNCHER_VERSION=0.6.0
ENV DRUSH_LAUNCHER_FALLBACK=/usr/local/bin/drush8
# composer normally screams about running as root, we don't need that.
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_CACHE_DIR /mnt/ddev-global-cache/composer
# Windows, especially Win10 Home/Docker toolbox, can take forever on composer build.
ENV COMPOSER_PROCESS_TIMEOUT 2000

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && apt-get update
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list

RUN apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
    ghostscript \
    imagemagick \
    mariadb-client \
    msmtp \
    nodejs \
    php-imagick \
    php-uploadprogress \
    sqlite3 \
    yarn

RUN for v in $PHP_VERSIONS; do \
    apt-get -qq install --no-install-recommends --no-install-suggests -y $v-apcu $v-bcmath $v-bz2 $v-curl $v-cgi $v-cli $v-common $v-fpm $v-gd $v-intl $v-json $v-ldap $v-mbstring $v-memcached $v-mysql $v-opcache $v-pgsql $v-readline $v-redis $v-soap $v-sqlite3 $v-xdebug $v-xml $v-xmlrpc $v-zip || exit $?; \
    if [ $v != "php5.6" ]; then \
        apt-get -qq install --no-install-recommends --no-install-suggests -y $v-apcu-bc || exit $?; \
    fi \
done

RUN for v in php5.6 php7.0 php7.1; do \
    apt-get -qq install --no-install-recommends --no-install-suggests -y $v-mcrypt || exit $?; \
done

RUN apt-get -qq autoremove -y
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN curl -sSL "https://github.com/drush-ops/drush/releases/download/${DRUSH_VERSION}/drush.phar" -o /usr/local/bin/drush8 && chmod +x /usr/local/bin/drush8
RUN curl -sSL "https://github.com/drush-ops/drush-launcher/releases/download/${DRUSH_LAUNCHER_VERSION}/drush.phar" -o /usr/local/bin/drush && chmod +x /usr/local/bin/drush
RUN curl -sSL -o /usr/local/bin/wp-cli -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x /usr/local/bin/wp-cli && ln -sf /usr/local/bin/wp-cli /usr/local/bin/wp
RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
ADD ddev-php-files /
RUN apt-get -qq autoremove && apt-get -qq clean -y && rm -rf /var/lib/apt/lists/*
RUN usermod -u ${WWW_UID} www-data && groupmod -g ${WWW_UID} www-data
#END ddev-php-base

### ---------------------------ddev-php-prod--------------------------------------
### Build ddev-php-prod from ddev-php-base as a single layer
### There aren't any differences
FROM scratch AS ddev-php-prod
COPY --from=ddev-php-base / /
ENV DRUSH_LAUNCHER_FALLBACK=/usr/local/bin/drush8
EXPOSE 8080 8585
CMD ["/usr/sbin/php-fpm", "-F"]
#END ddev-php-prod

### ---------------------------nginx-base--------------------------------------
### Build nginx-base
FROM base as nginx-base
ENV NGINX_FULL_VERSION=1.16.1-1~buster
ENV NGINX_SHORT_VERSION=1.16.1
RUN wget -q -O /tmp/nginx_signing.key http://nginx.org/keys/nginx_signing.key && \
        apt-key add /tmp/nginx_signing.key
RUN echo "deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" >/etc/apt/sources.list.d/nginx.list
RUN echo "deb-src http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" >> /etc/apt/sources.list.d/nginx.list
RUN apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y libcap2-bin nginx=${NGINX_FULL_VERSION}

ADD nginx-base-files /

RUN mkdir --parents \
    /etc/nginx/sites-enabled \
    /var/log/nginx \
    /var/cache/nginx/client_temp \
    /var/www/html \
    && touch /var/log/nginx/access.log \
    && touch /var/log/nginx/error.log \
    && touch /etc/nginx/nginx.conf \
    && chown -R www-data:www-data /var/www /var/cache/nginx /var/log/nginx /etc/nginx/sites-enabled /run \
    && chmod -R 755 /var/www /etc/nginx/sites-enabled \
    && chmod -R 766 /var/cache/nginx /var/log/nginx \
    && chmod 744 /etc/nginx/nginx.conf

EXPOSE 8080
CMD ["nginx"]

#END nginx-base

### ---------------------------nginx-mod-builder--------------------------------------
#nginx-mod-builder is a throwaway image just to build
#needed nginx modules
FROM nginx-base AS nginx-mod-builder
ENV DEBIAN_FRONTEND noninteractive
ENV ERRORS 0
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ARG NGINX_OPENTRACING_VERSION=v0.9.0
ARG VTS_VERSION=0.1.18

RUN apt-get -qq --no-install-recommends --no-install-suggests -y install \
    ncurses-bin \
    build-essential \
    cmake \
    pkg-config \
    libz-dev \
    automake \
    autogen \
    autoconf  \
    libtool
RUN apt-get build-dep -y nginx=${NGINX_FULL_VERSION}
WORKDIR /tmp
### Grab opentracing
RUN curl -sSL https://github.com/opentracing-contrib/nginx-opentracing/releases/download/${NGINX_OPENTRACING_VERSION}/linux-amd64-nginx-${NGINX_SHORT_VERSION}-ngx_http_module.so.tgz -o trace.tar.gz \
    && tar -zxf trace.tar.gz \
    && rm trace.tar.gz
### Grab VTS
RUN curl -sSL https://github.com/vozlt/nginx-module-vts/archive/v${VTS_VERSION}.tar.gz -o vts.tar.gz \
    && tar -zxf vts.tar.gz \
    && rm vts.tar.gz
### Build nginx-opentracing modules
RUN curl -sSL  https://github.com/nginx/nginx/archive/release-${NGINX_SHORT_VERSION}.tar.gz -o nginx-release-${NGINX_SHORT_VERSION}.tar.gz \
    && tar zxf nginx-release-${NGINX_SHORT_VERSION}.tar.gz \
    && cd nginx-release-${NGINX_SHORT_VERSION}

WORKDIR /tmp/nginx-release-${NGINX_SHORT_VERSION}
RUN auto/configure \
          --with-compat \
      --add-dynamic-module=/tmp/nginx-module-vts-$VTS_VERSION
RUN make modules
RUN make install
RUN cp /tmp/ngx_http_opentracing_module.so /usr/local/nginx/modules/
#END nginx-mod-builder

### ---------------------------ddev-nginx-prod--------------------------------------
### Build ddev-nginx (for DDEV-Live) by converting to single layer
FROM scratch as ddev-nginx-prod
COPY --from=nginx-base / /
COPY --from=nginx-mod-builder /usr/local/nginx/modules/ngx_http_opentracing_module.so /usr/lib/nginx/modules/ngx_http_opentracing_module.so
COPY --from=nginx-mod-builder /usr/local/nginx/modules/ngx_http_vhost_traffic_status_module.so /usr/lib/nginx/modules/ngx_http_vhost_traffic_status_module.so
ADD /ddev-nginx-prod-files /
#END ddev-nginx-prod

### ---------------------------ddev-webserver-base--------------------------------------
### Build ddev-php-base from ddev-webserver-base
### ddev-php-base is the basic of ddev-php-prod (for DDEV-Live)
### and ddev-webserver-* (For DDEV-Local)
FROM ddev-php-base as ddev-webserver-base
ENV PHP_VERSIONS="php5.6 php7.0 php7.1 php7.2 php7.3 php7.4"
ENV BACKDROP_DRUSH_VERSION=1.3.1
ENV MKCERT_VERSION=v1.4.1

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm
ENV MH_SMTP_BIND_ADDR 127.0.0.1:1025
ENV NGINX_SITE_TEMPLATE /etc/nginx/nginx-site.conf
ENV APACHE_SITE_TEMPLATE /etc/apache2/apache-site.conf
ENV WEBSERVER_DOCROOT /var/www/html
# For backward compatibility only
ENV NGINX_DOCROOT $WEBSERVER_DOCROOT
ENV TERMINUS_CACHE_DIR=/mnt/ddev-global-cache/terminus/cache

# Defines vars in colon-separated notation to be subsituted with values for NGINX_SITE_TEMPLATE on start
# NGINX_DOCROOT is for backward compatibility only, to break less people.
ENV NGINX_SITE_VARS '$WEBSERVER_DOCROOT,$NGINX_DOCROOT'
ENV APACHE_SITE_VARS '$WEBSERVER_DOCROOT'

ENV CAROOT /mnt/ddev-global-cache/mkcert

RUN wget -q -O /tmp/nginx_signing.key http://nginx.org/keys/nginx_signing.key && \
    apt-key add /tmp/nginx_signing.key && \
    echo "deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" > /etc/apt/sources.list.d/nginx.list

RUN apt-get update && apt-get -qq install --no-install-recommends --no-install-suggests -y apache2 libcap2-bin locales-all nginx supervisor

RUN for v in $PHP_VERSIONS; do \
    apt-get -qq install --no-install-recommends --no-install-suggests -y libapache2-mod-$v || exit $?; \
done

RUN apt-get -qq autoremove && apt-get -qq clean -y && rm -rf /var/lib/apt/lists/*

# Arbitrary user needs to be able to bind to privileged ports (for nginx and apache2)
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/nginx
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/apache2

ADD ddev-webserver-base-files /
ADD ddev-webserver-base-scripts /
# END ddev-webserver-base

### ---------------------------ddev-webserver-prod--------------------------------------
### Build ddev-webserver-prod, the hardened version of ddev-webserver-base
### (Withut dev features, single layer)
FROM scratch as ddev-webserver-prod
ENV NGINX_SITE_TEMPLATE /etc/nginx/nginx-site.conf
ENV APACHE_SITE_TEMPLATE /etc/apache2/apache-site.conf
ENV WEBSERVER_DOCROOT /var/www/html
# For backward compatibility only
ENV NGINX_DOCROOT $WEBSERVER_DOCROOT
ENV TERMINUS_CACHE_DIR=/mnt/ddev-global-cache/terminus/cache
ENV DRUSH_LAUNCHER_FALLBACK=/usr/local/bin/drush8

# Defines vars in colon-separated notation to be subsituted with values for NGINX_SITE_TEMPLATE on start
# NGINX_DOCROOT is for backward compatibility only, to break less people.
ENV NGINX_SITE_VARS '$WEBSERVER_DOCROOT,$NGINX_DOCROOT'
ENV APACHE_SITE_VARS '$WEBSERVER_DOCROOT'
COPY --from=ddev-webserver-base / /
# END ddev-webserver-prod

### ---------------------------ddev-webserver-dev-base--------------------------------------
### Build ddev-webserver-dev-base from ddev-webserver-base
FROM ddev-webserver-base as ddev-webserver-dev-base
ENV MAILHOG_VERSION=1.0.0
ENV CAROOT /mnt/ddev-global-cache/mkcert
ENV PHP_DEFAULT_VERSION="7.3"
RUN wget -q -O - https://packages.blackfire.io/gpg.key | apt-key add -
RUN echo "deb http://packages.blackfire.io/debian any main" > /etc/apt/sources.list.d/blackfire.list
RUN apt-get update
RUN apt-get install blackfire-php -y --allow-unauthenticated
RUN apt-get  install --no-install-recommends --no-install-suggests -y \
    fontconfig \
    gettext \
    git \
    iproute2 \
    iputils-ping \
    jq \
    libpcre3 \
    locales-all \
    nano \
    ncurses-bin \
    netcat \
    openssh-client \
    patch \
    rsync \
    sqlite3 \
    sudo \
    telnet \
    unzip \
    zip

ADD ddev-webserver-dev-files /
RUN phpdismod xdebug
RUN curl -sSL "https://github.com/mailhog/MailHog/releases/download/v${MAILHOG_VERSION}/MailHog_linux_amd64" -o /usr/local/bin/mailhog

RUN curl -sSL -O https://raw.githubusercontent.com/pantheon-systems/terminus-installer/master/builds/installer.phar && php installer.phar install

# magerun and magerun2 for magento
RUN curl -sSL https://files.magerun.net/n98-magerun-latest.phar -o /usr/local/bin/magerun
RUN curl -sSL https://raw.githubusercontent.com/netz98/n98-magerun/${MAGERUN_VERSION}/res/autocompletion/bash/n98-magerun.phar.bash -o /etc/bash_completion.d/magerun
RUN curl -sSL https://files.magerun.net/n98-magerun2-latest.phar -o /usr/local/bin/magerun2
RUN curl -sSL https://raw.githubusercontent.com/netz98/n98-magerun2/${MAGERUN2_VERSION}/res/autocompletion/bash/n98-magerun2.phar.bash -o /etc/bash_completion.d/magerun2

RUN curl -sSL "https://drupalconsole.com/installer" -L -o /usr/local/bin/drupal && chmod +x /usr/local/bin/drupal

RUN curl -sSL https://github.com/backdrop-contrib/drush/releases/download/${BACKDROP_DRUSH_VERSION}/drush.zip -o /tmp/backdrop_drush.zip && unzip -o /tmp/backdrop_drush.zip -d /var/tmp/backdrop_drush_commands

RUN mkdir -p /etc/nginx/sites-enabled /var/log/apache2 /var/run/apache2 /var/lib/apache2/module/enabled_by_admin /var/lib/apache2/module/disabled_by_admin && \
    touch /var/log/php-fpm.log && \
    chmod ugo+rw /var/log/php-fpm.log && \
    chmod ugo+rwx /var/run && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log && \
    chmod -R ugo+rw /var/log/nginx/ && \
    chmod ugo+rx /usr/local/bin/* && \
    update-alternatives --set php /usr/bin/php${PHP_DEFAULT_VERSION} && \
    ln -sf /usr/sbin/php-fpm${PHP_DEFAULT_VERSION} /usr/sbin/php-fpm

RUN chmod -R 777 /var/log

# /home is a prototype for the actual user dir, but leave it writable
RUN mkdir -p /home/.composer /home/.drush/commands /home/.drush/aliases /mnt/ddev-global-cache/mkcert /run/php && chmod -R ugo+rw /home /mnt/ddev-global-cache/

RUN chmod -R ugo+w /usr/sbin /usr/bin /etc/nginx /var/cache/nginx /run /var/www /etc/php/*/*/conf.d/ /var/lib/php/modules /etc/alternatives /usr/lib/node_modules /etc/php /etc/apache2 /var/log/apache2/ /var/run/apache2 /var/lib/apache2 /mnt/ddev-global-cache/*

RUN curl -sSL https://github.com/FiloSottile/mkcert/releases/download/$MKCERT_VERSION/mkcert-$MKCERT_VERSION-linux-amd64 -o /usr/local/bin/mkcert && chmod +x /usr/local/bin/mkcert

# Except that .my.cnf can't be writeable or mysql won't use it.
RUN chmod 644 /home/.my.cnf

RUN touch /var/log/nginx/error.log /var/log/nginx/access.log /var/log/php-fpm.log && \
  chmod 666 /var/log/nginx/error.log /var/log/nginx/access.log /var/log/php-fpm.log

RUN for v in $PHP_VERSIONS; do a2dismod $v || exit $?; done
RUN a2dismod mpm_event
RUN a2enmod ssl headers expires

# ssh is very particular about permissions in ~/.ssh
RUN chmod -R go-w /home/.ssh

# scripts added last because they're most likely place to make changes, speeds up build
ADD ddev-webserver-base-scripts /
RUN chmod ugo+x /start.sh /healthcheck.sh

RUN addgroup --gid 98 testgroup && adduser testuser --ingroup testgroup --disabled-password --gecos "" --uid 98

EXPOSE 80 443 8025
HEALTHCHECK --interval=1s --retries=10 --timeout=120s --start-period=10s CMD ["/healthcheck.sh"]
CMD ["/start.sh"]
RUN apt-get -qq clean -y && rm -rf /var/lib/apt/lists/*
#END ddev-webserver-dev-base

### ---------------------------ddev-webserver-dev--------------------------------------
### Build ddev-webserver-dev by turning ddev-webserver-dev-base into one layer
FROM scratch as ddev-webserver-dev
ENV PHP_DEFAULT_VERSION="7.3"
ENV NGINX_SITE_TEMPLATE /etc/nginx/nginx-site.conf
ENV APACHE_SITE_TEMPLATE /etc/apache2/apache-site.conf
ENV WEBSERVER_DOCROOT /var/www/html
# For backward compatibility only
ENV NGINX_DOCROOT $WEBSERVER_DOCROOT
ENV TERMINUS_CACHE_DIR=/mnt/ddev-global-cache/terminus/cache
ENV CAROOT /mnt/ddev-global-cache/mkcert
ENV DRUSH_LAUNCHER_FALLBACK=/usr/local/bin/drush8

# Defines vars in colon-separated notation to be subsituted with values for NGINX_SITE_TEMPLATE on start
# NGINX_DOCROOT is for backward compatibility only, to break less people.
ENV NGINX_SITE_VARS '$WEBSERVER_DOCROOT,$NGINX_DOCROOT'
ENV APACHE_SITE_VARS '$WEBSERVER_DOCROOT'
COPY --from=ddev-webserver-dev-base / /
EXPOSE 80 8025
HEALTHCHECK --interval=1s --retries=10 --timeout=120s --start-period=10s CMD ["/healthcheck.sh"]
CMD ["/start.sh"]
#END ddev-webserver-dev


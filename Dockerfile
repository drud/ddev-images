### ---------------------------base--------------------------------------
### Build the base Debian image that will be used in every other image
FROM debian:buster-slim as base
RUN apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    ca-certificates \
    bzip2 \
    curl \
    git \
    gnupg \
    less \
    lsb-release \
    procps \
    vim \
    wget
# Without c_rehash TLS fails (at least for curl) on arm/v7
# See https://github.com/balena-io-library/base-images/issues/562
RUN c_rehash
#END base

### ---------------------------ddev-php-base--------------------------------------
### Build ddev-php-base, which is the base for ddev-php-prod and ddev-webserver-*
### This combines the packages and features of DDEV-Local's ddev-webserver and
### DDEV-Live's PHP image
### TODO: See if we want to just build with a single PHP version or as now with all of them.
FROM base AS ddev-php-base
ARG PHP_DEFAULT_VERSION="7.3"
ENV DDEV_PHP_VERSION=$PHP_DEFAULT_VERSION
ENV PHP_VERSIONS="php5.6 php7.0 php7.1 php7.2 php7.3 php7.4"
ENV PHP_INI=/etc/php/$PHP_DEFAULT_VERSION/fpm/php.ini
ENV WWW_UID=33
ENV YQ_VERSION=2.4.1
ENV DRUSH_VERSION=8.3.5
ENV DRUSH_LAUNCHER_VERSION=0.6.0
ENV DRUSH_LAUNCHER_FALLBACK=/usr/local/bin/drush8
# composer normally screams about running as root, we don't need that.
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_PROCESS_TIMEOUT 2000
# TARGETPLATFORM is Docker buildx's target platform (e.g. linux/arm64), while 
# BUILDPLATFORM is the platform of the build host (e.g. linux/amd64)
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && apt-get update
RUN curl -sSL https://deb.nodesource.com/setup_12.x | bash -
RUN curl -sSL -o /tmp/yarnkey.gpg https://dl.yarnpkg.com/debian/pubkey.gpg
RUN apt-key add /tmp/yarnkey.gpg
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list

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

# PHP 5.6 is not available on linux/arm64 so we skip that version.
# Also, the php7.4-apcu-bc package is not available on arm64.
# Details: https://github.com/oerdnj/deb.sury.org/issues/1449
SHELL ["/bin/bash", "-c"]
RUN for v in $PHP_VERSIONS; do \
    [[ $v == "php5.6" && $TARGETPLATFORM == "linux/arm64" ]] && continue; \
    apt-get -qq install --no-install-recommends --no-install-suggests -y $v-apcu $v-bcmath $v-bz2 $v-curl $v-cgi $v-cli $v-common $v-fpm $v-gd $v-intl $v-json $v-ldap $v-mbstring $v-memcached $v-mysql $v-opcache $v-pgsql $v-readline $v-redis $v-soap $v-sqlite3 $v-xdebug $v-xml $v-xmlrpc $v-zip || exit $?; \
    if [[ $TARGETPLATFORM == "linux/amd64" && $v != "php5.6" ]] || [[ $TARGETPLATFORM == "linux/arm64" && $v != "php7.4" ]]; then \
        apt-get -qq install --no-install-recommends --no-install-suggests -y $v-apcu-bc || exit $?; \
    fi \
done

RUN for v in php5.6 php7.0 php7.1; do \
    [[ $v == "php5.6" && $TARGETPLATFORM == "linux/arm64" ]] && continue; \
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
RUN	update-alternatives --set php /usr/bin/php${DDEV_PHP_VERSION}
RUN ln -sf /usr/sbin/php-fpm${DDEV_PHP_VERSION} /usr/sbin/php-fpm
RUN mkdir -p /run/php && chown -R www-data:www-data /run
ADD /.docker-build-info.txt /

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


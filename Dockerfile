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
FROM base AS ddev-php-base
ARG PHP_DEFAULT_VERSION="7.4"
ENV DDEV_PHP_VERSION=$PHP_DEFAULT_VERSION
ENV PHP_VERSIONS="php5.6 php7.0 php7.1 php7.2 php7.3 php7.4 php8.0"
ENV PHP_INI=/etc/php/$PHP_DEFAULT_VERSION/fpm/php.ini
ENV YQ_VERSION=v4.7.1
ENV DRUSH_VERSION=8.4.8
# composer normally screams about running as root, we don't need that.
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_PROCESS_TIMEOUT 2000

# TARGETPLATFORM is Docker buildx's target platform (e.g. linux/arm64), while 
# BUILDPLATFORM is the platform of the build host (e.g. linux/amd64)
ARG TARGETPLATFORM
ARG BUILDPLATFORM

SHELL ["/bin/bash", "-c"]

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && apt-get update
RUN curl -sSL --fail https://deb.nodesource.com/setup_14.x | bash -

RUN apt-get -qq update
RUN apt-get -qq install --no-install-recommends --no-install-suggests -y \
    ghostscript \
    imagemagick \
    mariadb-client \
    msmtp \
    nodejs \
    php-uploadprogress \
    sqlite3

RUN npm config set unsafe-perm true && npm install --global gulp-cli yarn

# The number of permutations of php packages available on each architecture because
# too much to handle, so has been codified here instead of in obscure logic
ENV php56_amd64="apcu bcmath bz2 curl cli common fpm gd imagick intl json ldap mbstring mcrypt memcached mysql opcache pgsql readline redis soap sqlite3 uploadprogress xdebug xhprof xml xmlrpc zip"
ENV php56_arm64="apcu bcmath bz2 curl cli common fpm gd imagick intl json ldap mbstring mcrypt mysql opcache pgsql readline soap sqlite3 uploadprogress xdebug xml xhprof xmlrpc zip"
ENV php70_amd64="apcu apcu-bc bcmath bz2 curl cli common fpm gd imagick intl json ldap mbstring mcrypt memcached mysql opcache pgsql readline redis soap sqlite3 uploadprogress xdebug xhprof xml xmlrpc zip"
ENV php70_arm64=$php70_amd64
ENV php71_amd64=$php70_amd64
ENV php71_arm64=$php70_arm64
ENV php72_amd64="apcu apcu-bc bcmath bz2 curl cli common fpm gd imagick intl json ldap mbstring memcached mysql opcache pgsql readline redis soap sqlite3 uploadprogress xdebug xhprof xml xmlrpc zip"
ENV php72_arm64=$php72_amd64
ENV php73_amd64=$php72_amd64
ENV php73_arm64=$php72_arm64
ENV php74_amd64="apcu apcu-bc bcmath bz2 curl cli common fpm gd imagick intl json ldap mbstring memcached mysql opcache pgsql readline redis soap sqlite3 uploadprogress xdebug xhprof xml xmlrpc zip"
ENV php74_arm64=$php74_amd64

# As of php8.0 json is now part of core package and xmlrpc has been removed from PECL
ENV php80_amd64="apcu bcmath bz2 curl cli common fpm gd imagick intl ldap mbstring memcached mysql opcache pgsql readline redis soap sqlite3 xdebug xhprof xml xmlrpc zip"
ENV php80_arm64=$php80_amd64

RUN for v in $PHP_VERSIONS; do \
    targetarch=${TARGETPLATFORM#linux/}; \
    pkgvar=${v//.}_${targetarch}; \
    pkgs=$(echo ${!pkgvar} | awk -v v="$v" ' BEGIN {RS=" "; }  { printf "%s-%s ",v,$0 ; }' ); \
    [[ ${pkgs// } != "" ]] && (apt-get -qq install --no-install-recommends --no-install-suggests -y $pkgs || exit $?) \
done
RUN phpdismod blackfire xhprof
RUN apt-get -qq autoremove -y
RUN curl -o /usr/local/bin/composer -sSL https://getcomposer.org/composer-stable.phar && chmod ugo+wx /usr/local/bin/composer
RUN curl -sSL "https://github.com/drush-ops/drush/releases/download/${DRUSH_VERSION}/drush.phar" -o /usr/local/bin/drush8 && chmod +x /usr/local/bin/drush8
RUN curl -sSL -o /usr/local/bin/wp-cli -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x /usr/local/bin/wp-cli && ln -sf /usr/local/bin/wp-cli /usr/local/bin/wp
RUN url="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETPLATFORM#linux/}"; wget ${url} -O /usr/bin/yq && chmod +x /usr/bin/yq
ADD ddev-php-files /
RUN apt-get -qq autoremove && apt-get -qq clean -y && rm -rf /var/lib/apt/lists/*
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
EXPOSE 8080 8585
CMD ["/usr/sbin/php-fpm", "-F"]
#END ddev-php-prod


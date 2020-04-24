# ddev-images

This repository will provide the build techniques for the webserving/php DDEV-Local and DDEV-Live Docker images:

* *ddev-php* is the PHP image used by DDEV-Live. It was formerly embedded in (private) [drud/site-operator/pkg/controller/phpdistro/docker.go](https://github.com/drud/site-operator/blob/master/pkg/controller/phpdistro/docker.go)
* *ddev-nginx* is the NGINX image used by DDEV-Live. DDEV-Live uses two separate containers for webserving (nginx and php) so they are not contained in a single image as is the case with DDEV-Local. It was formerly embedded in (private) [drud/site-operator/pkg/controller/nginxdistro/docker.go](https://github.com/drud/site-operator/blob/master/pkg/controller/nginxdistro/docker.go)
* *ddev-webserver-dev* for DDEV-Local. This is built on top of *ddev-php* and is based on the build formerly in [ddev/containers/ddev-webserver](https://github.com/drud/ddev/tree/b6a84accff197e180cd3220fca2171e0f800d176/containers/ddev-webserver)
* *ddev-webserver-prod*, the same as ddev-webserver-dev, but without developer features like sudo and mailhog, and with a fixed user of www-data. This is a hardened version of ddev-webserver-dev without some developer features..

# ddev-images

This repository provides the build techniques for the webserving/php DDEV-Local and DDEV-Live Docker images:

* *ddev-php* is the PHP image used by DDEV-Live. It was formerly embedded in (private) [drud/site-operator/pkg/controller/phpdistro/docker.go](https://github.com/drud/site-operator/blob/master/pkg/controller/phpdistro/docker.go), included [here](obsolete/php-dockerfile.txt) for comparison.
* *ddev-nginx* is the NGINX image used by DDEV-Live. DDEV-Live uses two separate containers for webserving (nginx and php) so they are not contained in a single image as is the case with DDEV-Local. It was formerly embedded in (private) [drud/site-operator/pkg/controller/nginxdistro/docker.go](https://github.com/drud/site-operator/blob/master/pkg/controller/nginxdistro/docker.go), included [here](obsolete/nginx-dockerfile.txt) for comparison.
* *ddev-webserver-dev* for DDEV-Local. This is built on top of *ddev-php* and is based on the build formerly in [ddev/containers/ddev-webserver](https://github.com/drud/ddev/tree/b6a84accff197e180cd3220fca2171e0f800d176/containers/ddev-webserver)
* *ddev-webserver-prod*, the same as ddev-webserver-dev, but without developer features like sudo and mailhog, and with a fixed user of www-data. This is a hardened version of ddev-webserver-dev without some developer features..

## Building

To build, use `make VERSION=<versiontag>` or `make images`. To push, use `make push`

Individual images can be built using `make ddev-nginx-prod VERSION=<versiontag>`

## Testing

Each image is intended to have a robust set of tests. The tests should be included in the `tests/<imagename>` directory, and should be launched with a `test.sh` in that directory. 

I'm hoping to get the current ddev-webserver-dev test converted to [BATS](github.com/bats-core/bats-core) in the course of project.

## Image Size comparisons (uncompressed)

| Image           | Old size | New size | Notes                                           |
|-----------------|----------|----------|-------------------------------------------------|
| ddev-webserver  | 1.62GB   | 1.2GB    |                      |
| DDEV-Live PHP (ddev-live-php-prod)  | 752MB    | 725MB    | New has all 6 versions of PHP and still smaller |
| DDEV-LIVE PHP with just php7.3 | 752MB | 594MB |
| ddev-live-nginx-prod | 136MB  |   181MB    |                                                 |
| ddev-webserver-prod (new hardened open source image) | 1.01GB | |

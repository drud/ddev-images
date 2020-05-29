# ddev-images

This repository provides the build techniques for the webserving/php DDEV-Local and DDEV-Live Docker images:

* *ddev-php* is the PHP image used by DDEV-Live. It was formerly embedded in (private) [drud/site-operator/pkg/controller/phpdistro/docker.go](https://github.com/drud/site-operator/blob/master/pkg/controller/phpdistro/docker.go), included [here](obsolete/php-dockerfile.txt) for comparison.
* *ddev-nginx* is the NGINX image used by DDEV-Live. DDEV-Live uses two separate containers for webserving (nginx and php) so they are not contained in a single image as is the case with DDEV-Local. It was formerly embedded in (private) [drud/site-operator/pkg/controller/nginxdistro/docker.go](https://github.com/drud/site-operator/blob/master/pkg/controller/nginxdistro/docker.go), included [here](obsolete/nginx-dockerfile.txt) for comparison.
* *ddev-webserver-dev* for DDEV-Local. This is built on top of *ddev-php* and is based on the build formerly in [ddev/containers/ddev-webserver](https://github.com/drud/ddev/tree/b6a84accff197e180cd3220fca2171e0f800d176/containers/ddev-webserver)
* *ddev-webserver-prod*, the same as ddev-webserver-dev, but without developer features like sudo and mailhog, and with a fixed user of www-data. This is a hardened version of ddev-webserver-dev without some developer features..

![Block Diagram](docs-pics/ddev-images-block-diagram.png)

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
| ddev-webserver-prod (new hardened open source image) | N/A | 1.01GB | 


## Discussion Items

1. **DDEV-Live development/testing**: We have to figure out how I can experiment with and move the DDEV-Live images along. That will mean being able to use and test them in context in DDEV-Live.
2. **Multi-PHP-Version**: The ddev-php-prod image for DDEV-Live currently contains PHP 5.6-7.4, but only one of these runs at a time, determined by an environment variable at startup. Obviously we can have multiple images, each with only one PHP version. Having a multi-php image means managing (and caching) less images. The multi-php ddev-live-php-prod is 27MB smaller than current prod, although a a single-php equivalent would be only 594MB, about 150MB smaller than current prod. 
3. **Compiled modules**: The ddev-nginx images use custom-compiled modules that then seem not to be included in the configuration. Should we just drop those modules?
4. **Making hardened ddev-webserver work**: ddev-webserver-prod will not have sudo, and it currently depends on sudo in its start script. Those features will need to be handled in the Dockerfile.
5. **`ddev-webserver-*` does not inherit from `ddev-nginx-*`**: Currently `ddev-webserver-*` uses its own nginx and apache installation, instead of trying to grap the files from ddev-nginx, as that seemed risky. I think this is OK for now, but we'll need to make sure that the actual nginx configs are as similar as possible.
6. **Building, pulling, and pushing, and repository**: Currently the DDEV-Live Dockerfiles are embedded in a golang file, which doesn't seem very effective for sharing. With this repo, that's somewhwat solved, but we have to figure out about what repository we use, how it gets pushed there, etc.
7. **Details**: 
    * Review the actual PHP extensions bundled. php-ldap, for example, and php-xdebug.

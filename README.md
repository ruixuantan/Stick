# Stick

A partial implementation of Apache Arrow.

More to come.

## Docker commands
build:
```sh
docker build . -t stick
```

run:
```sh
docker run --rm -it -v `pwd`/src:/tmp/stick/src --security-opt seccomp=seccomp/conf.json stick
```


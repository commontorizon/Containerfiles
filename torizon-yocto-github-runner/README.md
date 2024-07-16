# Torizon Yocto GitHub Runner

1. First create an `ostree` repository with the following command:

```bash
mkdir ostree
ostree init --repo=ostree --mode=archive
```

2. Create a work directory for the build:

```bash
mkdir workdir
```

3. Export the `OSTREE_REPO` and `WORKDIR` environment variables:

```bash
export OSTREE_REPO=$(pwd)/ostree
export WORKDIR=$(pwd)/workdir
```

5. Change the `ACCESS_TOKEN` environment variable on the `docker-compose.run.yml` file:

> ⚠️ **Warning**: The `ACCESS_TOKEN` must be a Personal Access Token with the `repo` scope.

```yaml
environment:
      - REPO=commontorizon/commontorizon-manifest
      - ACCESS_TOKEN=${ACCESS_TOKEN}
```

4. Run the `docker-compose.run.yml`:

```bash
docker-compose -f docker-compose.run.yml up -d
```

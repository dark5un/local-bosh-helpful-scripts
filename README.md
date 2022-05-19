# Useful local BOSH director scripts

> TL; DR;
## Initial step
```
./init.sh
./post.sh
./concourse.sh
./export_binary_releases.sh -d concourse
```

## Tear down
```
./destroy.sh
```

## Bring up again (with the previously saved binary releases)
```
./init.sh
./post.sh
./import_binary_releases.sh -d concourse
./concourse.sh
```

## System requirements

- whatever [this](https://bosh.io/docs/bosh-lite/#install) says
- darwin machine (it has been tested on a mac)

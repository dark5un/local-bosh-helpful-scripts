# Useful local BOSH director scripts

> TL; DR;
## Initial step
```
./init.sh
./post.sh
./concourse.sh
./export_binary_releases.sh concourse
```

## Tear down
```
./destroy.sh
```

## Bring up again (with the previously saved binary releases)
```
./init.sh
./post.sh
./import_binary_releases.sh concourse
./concourse.sh
```
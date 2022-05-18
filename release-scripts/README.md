## Prepare postgresql release

> TL; DR;

```
./prepare-postgres-release.sh
bosh update-cloud-config ../cloud-config.yml
```
change the [postgres-release/ci/pipelines/acceptance-tests.yml](work/postgres-release/postgres-release/ci/pipelines/acceptance-tests.yml) to use `STEMCELL_TYPE: bosh-warden-boshlite-ubuntu-xenial`
Then run the [acceptance-tests](http://10.244.15.2:8080/teams/main/pipelines/acceptance-tests) pipeline on local running concourse.

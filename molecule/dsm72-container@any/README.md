# dsm72-container@any

NOTE: only support molecule `create` sequence, cant test `converge` automatically.

```bash
molecule --debug -vvv create --scenario-name dsm72-container@any
```

then go `http://localhost:17200`, create username `docker` with password `4Test@ansible`,
and enable ssh login, it will use by [dsm72-test@any/converge](../dsm72-test@any/converge.yml)

after that use [dsm72-test@any](../dsm72-test@any/README.md)


finally destroy it

```bash
molecule --debug -vvv destroy --scenario-name dsm72-container@any
```

# Katabase
This is nimble package plugins for [Katalis](https://github.com/zendbit/katalis) framework. Not build exclusively for katalis, so we can add it to other project

## Install
```sh
nimble install https://github.com/zendbit/katabase
```

## Usage
```nim
import katalis/plugins/katabase
```

## Unit testing
```sh
nimble develop https://github.com/zendbit/katabase
```

then inside katabase repo, run nimble test for testing functionality, you can also see how to use katabase in the unit test file **test/test1.nim**

```sh
nimble test
```

## Create katabase fo connection
```nim
let kbase = newKatabase[SqLite]("", "mydb.db", "", "")
```
to connect with MySql/MariaDb and PostgreSql we can use:
### MySql/MariaDb
```nim
let kbase = newKatabase[MySql](
  "localhost",
  "dbName",
  "user",
  "pass",
  Port(7000), # if not set will use default port (optional)
  encoding # if not set will use default encoding (optional)
)
```
for PostgreSql connection, replace **\[MySql\]** with **\[PostgreSql\]**

# Katabase
Simple but flexible and powerfull ORM for Nim language. Currently support MySql/MariaDb, SqLite and PostgreSql

## Install
```sh
nimble install https://github.com/zendbit/katabase
```

## Usage
```nim
import katabase
```

## Unit testing
```sh
nimble develop https://github.com/zendbit/katabase
```

then inside katabase repo, run nimble test for testing functionality, you can also see how to use katabase in the unit test file **test/test1.nim**

```sh
nimble test
```

## Create katabase
```nim
let kbase = newKatabase[SqLite]("", "mydb.db", "", "")
```
to connect with MySql/MariaDb and PostgreSql we can use:
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

## Create katabase type model
To interact with katabase we need to define type that derived from DbModel
```nim
import katabase


type
  Users* {.dbTable.} = ref object of DbModel\
    name*: Option[string]
    lastUpdate* {.dbColumnType: "TIMESTAMP".} : Option[\
    isActive*: Option[bool]

  Posts* {.dbTable.} = ref object of DbModel
    post*: Option[string]
    usersId* {.dbReference: Users.}: Option[BiggestInt]

  Comments* {.dbTable.} = ref object of DbModel
    comment*: Option[string]
    usersId* {.dbReference: Users.}: Option[BiggestInt]
    postsId* {.dbReference: Posts.}: Option[BiggestInt]

  UsersDetails* {.dbTable.} = ref object of DbModel
    usersId* {.dbReference: Users.}: Option[BiggestInt]
    address*: Option[string]
```

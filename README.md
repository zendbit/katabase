# Katabase
Simple but flexible and powerfull ORM for Nim language. Currently support MySql/MariaDb, SqLite and PostgreSql

## Install
from nimble directory
```sh
nimble install katabase
```
direct from git repo
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
available pragma on DbModel type:

####*Note: all field must in Option[type]

**{.dbTable.}**: Database table identifier and name, we can also create custom name by passing table name as parameter
```nim
type
  Users* {.dbTable.} = ref object of DbModel ## \
  ##
  ##  we can pass table name to dbTable pragma
  ##  {.dbTable: "tbl_users".}
  ##
```
**{.dbColumnName.}**: Database table column identifier and name, we can pass custom name to column field. if pragma not applied then it will use field name instead
```nim
type
  Users* {.dbTable.} = ref object of DbModel ## \
  ##
  ##  we can pass table name to dbTable pragma
  ##  {.dbTable: "tbl_users".}
  ##
  isActive {.dbColumnName: "is_active".}: Option[bool] ## \
  ##
  ## this will map the field isActive to actual database is_active column field
  ##
```
**{.dbColumnType.}**: Database table column type, this will usefull if want to map field type to database field type for example we want to set type as VECTOR type in database
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    content* {.dbColumnType: "VECTOR".}: Option[string] ## \
    ##
    ## this will map string value to VECTOR type in database
    ##
```
Option[string] -> should map to text type like VARCHAR, CHAR, VECTOR, TEXT, etc\
Option[int-type] -> should map to numeric type like int, bigint, smallint, etc\
Option[float-type] -> should map to decimal type like float, double, decimal, etc

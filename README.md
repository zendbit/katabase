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
  Users* {.dbTable.} = ref object of DbModel
    name*: Option[string]
    lastUpdate* {.dbColumnType: "TIMESTAMP".} : Option[string]
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

####*Note:\
all field must in Option[type]. DbModel type automatically add id field as primary key and index auto increment

***{.dbTable.}***: database table identifier and name, we can also create custom name by passing table name as parameter
```nim
type
  Users* {.dbTable.} = ref object of DbModel ## \
  ##
  ##  we can pass table name to dbTable pragma
  ##  {.dbTable: "tbl_users".}
  ##
```

***{.dbColumnName.}***: database table column identifier and name, we can pass custom name to column field. if pragma not applied then it will use field name instead
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

***{.dbColumnType.}***: database table column type, this will usefull if want to map field type to database field type for example we want to set type as VECTOR type in database
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    content* {.dbColumnType: "VECTOR".}: Option[string] ## \
    ##
    ## this will map string value to VECTOR type in database
    ##
```

***Option[string]*** -> should map to text type like VARCHAR, CHAR, VECTOR, TEXT, etc\
***Option[int-type]*** -> should map to numeric type like int, bigint, smallint, etc\
***Option[float-type]*** -> should map to decimal type like float, double, decimal, etc

***{.dbColumnLength.}***: database table column length, this will set max length of field
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    someField* {.
      dbColumnType: "VARCHAR" ## set type to VARCHAR
      dbColumnLength: 100 ## set field length to 100
    .}: Option[string]
```

***{.dbNullable.}***: treat column field to default NULL
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    someField* {.
      dbColumnType: "VARCHAR" ## set type to VARCHAR
      dbColumnLength: 100 ## set field length to 100
      dbNullable ## set default to NULL
    .}: Option[string]
```

***{.dbUnique.}***: treat column field to unique field
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    someField* {.
      dbColumnType: "VARCHAR" ## set type to VARCHAR
      dbColumnLength: 100 ## set field length to 100
      dbNullable ## set default to NULL
      dbUnique ## treat field as unique
    .}: Option[string]
```

***{.dbCompositeUnique.}***: treat column field as composite unique with other field
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    someField* {.
      dbCompositeUnique ## will unique composite with otherSomeField
    .}: Option[string]
    otherSomeField* {.
      dbCompositeUnique ## will unique composite with someField
    .}: Option[string]
```

***{.dbIgnore.}***: this is special pragma, field with this pragma will ignored form database table column creation and from database query
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    someField*: Option[string]
    otherSomeField* {.dbIgnore.}: Option[string] ## this field will ignored on database creation and from database query
```

***{.dbReference.}***: create reference to other DbModel as foreignkey
```nim
type
  Users* {.dbTable.} = ref object of DbModel
    name*: Option[string]
    lastUpdate* {.dbColumnType: "TIMESTAMP".} : Option[string]
    isActive*: Option[bool]

  Posts* {.dbTable.} = ref object of DbModel
    post*: Option[string]
    usersId* {.dbReference: Users.}: Option[BiggestInt] ## will reference to table Users as foreignkey
```

## Create table schema to database
```nim
import katabase


type
  Users* {.dbTable.} = ref object of DbModel
    name*: Option[string]
    lastUpdate* {.dbColumnType: "TIMESTAMP".} : Option[string]
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


##
## Create table schema to sqlite
##

## conccection type instance
let kbase = newKatabase[SqLite]("", "local.db", "", "")

##
## we optionally call create Users
## Users table will created automatically
## because it referenced by Posts, Comments and UsersDetails
##
kbase.createTable(Posts())
kbase.createTable(Comments())
kbase.createTable(UsersDetails())
```

## SqlBuilder
Katabase comes with handy tool for doing query operation.
```nim
let query1 = sqlBuild.
  select(("id", "name")).
  table("Users").
  where("Users.id=$#", 1)

##
## sql lexical will handle by katabase
##

let query2 = sqlBuild.
  table("Users").
  where("Users.id=$#", 1).
  select(("id", "name"))

let query3 = sqlBuild.
  where("Users.id=$#", 1).
  table("Users").
  select(("id", "name"))

assert($query1 == $query2 == $query3)
echo "query1 query2 and query3 are valids, katabase will handle sql lexical"
```

available SqlBuilder proc sql sintax:

***select(tuple | string)***:\
- select column name from table, ex: select(("id", "name")) | select("id")\
***table(tuple | stirng)***:\
- table name to be select, ex: table(("tbl1", "tbl2")) | table("tbl1")\
***where(condition: string, subtitution: tuple|any value)***:\
- where condition, ex: where("Users.id=$# AND Users.isActive=$#", (1, true))\

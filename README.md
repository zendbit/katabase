# Katabase
Simple but flexible and powerfull ORM for Nim language. Currently support MySql/MariaDb, SqLite and PostgreSql

## Do you think this is good project? support us for better development and support
- **USDT (TRC20): TSGAgbb3fVdJfjHagDWhSySojo6bK89LMN**
- **USDT (BEP20): 0x26772823bdd8db6fbd010c1b15a1ba7496ce76fe**
- **Paypal: paypal.me/amrurosyada**
  
## Install
from nimble directory
```sh
nimble install katabase
```
direct from git repo
```sh
nimble install https://github.com/zendbit/katabase
```

## Documentation
https://deepwiki.com/zendbit/katabase

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

## Support for asyncdispatch
Katabase support for asyncdispatch, each procedure with postfix Async indicate the procedure is async, for example:

- createTable() ==> createTableAsync()
- queryRows() ==> queryRowsAsync()
- queryOneRow() ==> queryOneRowAsync()
- select() ==> selectAsync()
- update() ==> updateAsync()
- delete() ==> deleteAsync
- selectOne() ==> selectOneAsync()
- etc...

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
    name*: Option[string],
    uuid*{.
      dbUUID
      dbUnique
    .}: Option[string]
    lastUpdate* {.
      dbColumnType: "TIMESTAMP",
      dbColumnName: "last_update"
    .}: Option[string]
    isActive* {.dbColumnName: "is_active".}: Option[bool]

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

#### **Note:**
**all field must in Option[type]. DbModel type automatically add id field as primary key and index auto increment**

***{.dbTable.}***: database table identifier and name, we can also create custom name by passing table name as parameter
```nim
type
  Users* {.dbTable.} = ref object of DbModel ## \
  ##
  ##  we can pass table name to dbTable pragma
  ##  {.dbTable: "tbl_users".}
  ##
```

***{.dbUUID.}***: database table column uuid type, for MySql and PostgreSql will
use UUID type but on SqLite will use TEXT type. To generate using nim oids just
use $genOid() when inserting data.
```nim
type
  Users* {.dbTable.} = ref object of DbModel ## \
  ##
  ##  we can pass table name to dbTable pragma
  ##  {.dbTable: "tbl_users".}
  ##
    firstname* {.
      dbColumnLength: 20
    .}: Option[string]
    lastname* {.
      dbColumnLength: 20
    .}: Option[string]
    uuid* {.
      dbUUID
      dbUnique
    .}: Option[string]
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

***{.dbUnique: @[...].}***: treat column field to unique field

we can create group of multiple column as unique using sequence as identifier

```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    field1* {.
      dbUnique: @["field1_field2", "field1_field2_field3"]
    .}: Option[string]
    field2* {.
      dbUnique: @["field1_field2", "field1_field2_field3"]
    .}: Option[string]
    field3* {.
      dbUnique: @["field3", "field1_field2_field3"]
    .}: Option[string]

## field1_field2 will group and combine field1 and field2 as unique
## field3 will only field3 unique
## field1_field2_field3 will group and combine field1, field2, and field3 as unique
```

***{.dbIndex.}***: create column indexing
***{.dbUniqueIndex.}***: create unique column indexing
```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    someField* {.
      dbColumnType: "VARCHAR" ## set type to VARCHAR
      dbColumnLength: 100 ## set field length to 100
      dbNullable ## set default to NULL
      dbIndex ## create column indexing, use dbUniqueIndex for unique indexing
    .}: Option[string]
```

***{.dbIndex: @[...].}***: group column indexing
***{.dbUniqueIndex: @[...].}***: group unique column indexing

we can create group of multiple column indexing using sequence as identifier

```nim
type
  SomeType* {.dbTable.} = ref object of DbModel
    field1* {.
      dbIndex: @["field1", "field1_field2", "field1_field2_field3"]
    .}: Option[string]
    field2* {.
      dbIndex: @["field1_field2", "field1_field2_field3"]
    .}: Option[string]
    field3* {.
      dbIndex: @["field1_field2_field3"]
    .}: Option[string]

## field1 will only create field1 column indexing
## field1_field2 will group field1 and field2
## field1_field2_field3 will group and combine field1, field2, and field3
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
    lastUpdate* {.
      dbColumnType: "TIMESTAMP"
      dbColumnName: "last_update" ## for simulate column name mapping
    .} : Option[string]
    isActive* {.dbColumnName: "is_active".}: Option[bool] ## for simulate column name mapping

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
    uuid* {.
      dbUUID
      dbUnique
    .}: Option[string]
    lastUpdate* {.
      dbColumnType: "TIMESTAMP"
      dbColumnName: "last_update" ## for simulate column name mapping
    .} : Option[string]
    isActive* {.dbColumnName: "is_active".}: Option[bool] ## for simulate column name mapping

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

##
## for async use:
## await.createTableAsync(Posts())
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
  where("Users.id=?", 1)

##
## sql lexical will handle by katabase
##

let query2 = sqlBuild.
  table("Users").
  where("Users.id=?", 1).
  select(("id", "name"))

let query3 = sqlBuild.
  where("Users.id=?", 1).
  table("Users").
  select(("id", "name"))

assert($query1 == $query2 == $query3)
echo "query1 query2 and query3 are valids, katabase will handle sql lexical"
```

Possibility create complex query using SqlBuilder:
```nim
let query1 = sqlBuild.
  select(
    (
      "Users.id AS userId",
      "Users.name AS username",
      "post",
      "Post.id AS postId"
    )
  ).
  table("Users").
  innerJoin("Posts", "Users.id = Posts.usersId")

echo query1

## using subquery instead

let query2 = sqlBuild.
  select(
    (
      "Users.id AS userId",
      "Users.name AS username",
      "post",
      "Post.id AS postId"
    )
  ).
  table(("Users", "Posts")).
  where(
    "Users.id IN (?)",
    sqlBuild.selectDistinct("usersId").
    table("Posts")
  ).
  where("AND Users.id = (?)", 1).
  limit(100)

echo query2
```
available proc for SqlBuilder
- **select(tuple|string)**
- **selectDistinct(tuple|string)**
- **insert(tuple|string)**
- **update(tuple|string)**
- **value(tuple|string)**
- **delete**
- **table(tuple|string)**
- **where(condition: string, params: any|tuple)** -> params is optional
- **groupBy(tuple|string)**
- **having(condition: string, params: any|tuple)** -> params is optional
- **orderByAsc(tuple|string)**
- **orderByDesc(tuple|string)**
- **limit(limit: int)**
- **offset(offset: int)**
- **union(unionWith: SqlBuilder)**
- **unionAll(unionAll: SqlBuilder)**
- **innerJoin(table: string, condition: string)**
- **leftJoin(table: string, condition: string)**
- **rightJoin(table: string, condition: string)**

## Work with ORM
Before we deepdive into SqlBuilder usages, we will start to work with ORM in katabase. Let start using our example
```nim
import katabase


type
  Users* {.dbTable.} = ref object of DbModel
    name*: Option[string]
    uuid* {.
      dbUUID
      dbUnique
    .}: Option[string]
    lastUpdate* {.
      dbColumnType: "TIMESTAMP"
      dbColumnName: "last_update" ## for simulate column name mapping
    .} : Option[string]
    isActive* {.dbColumnName: "is_active".}: Option[bool] ## for simulate column name mapping

  Posts* {.dbTable.} = ref object of DbModel
    post*: Option[string]
    usersId* {.dbReference: Users.}: Option[BiggestInt]


##
## Create table schema to sqlite
##

## conccection type instance
let kbase = newKatabase[SqLite]("", "local.db", "", "")

##
## we optionally call create Users
## Users table will created automatically
## because it referenced by Posts
##
kbase.createTable(Posts())
```

### Insert using ORM
```nim
let userId = kbase.insert(
  Users(
    name: some "Foo",
    uuid: some $genOid(),
    lastUpdate: some "2025-01-30",
    isActive: some true
  )
)

if userId != 0:
  echo "Users " & Users.name.get & " inserted with id " & $userId
else:
  echo "Insert failed"

## insert multiple value
let usersInserted = kbase.insert(
  @[
    Users(
      name: some "Foo",
      uuid: some $genOid(),
      lastUpdate: some "2025-01-30",
      isActive: some true
    ),
    Users(
      name: some "Bar",
      uuid: some $genOid(),
      lastUpdate: some "2025-01-30",
      isActive: some true
    ),
    Users(
      name: some "John",
      uuid: some $genOid(),
      lastUpdate: some "2025-01-30",
      isActive: some true
    )
  ]
)

if userInserted != 0:
  echo $userInserted & " Users inserted"
else:
  echo "Insert failed"
```

### Insert using SqlBuilder
```nim
let userId = kbase.insertRow(
  sqlBuild.
  insert(("name", "uuid", "last_update", "is_active")).
  value(("Foo", $genOid(), "2025-01-30", true)).
  table("Users")
)

if userId != 0:
  echo "Users inserted with id " & $userId
else:
  echo "Insert failed"

## insert multiple value
let insertedId = kbase.execQueryAffectedRows(
  sqlBuild.
  insert(("name", "uuid", "last_update", "is_active")).
  value(
    @[
      ("Foo", $genOid(), "2025-01-30", true),
      ("Bar", $genOid(), "2025-01-30", true),
      ("John", $genOid(), "2025-01-30", true)
    ]
  ).
  table("Users")
)

if userInserted != 0:
  echo $userInserted & " Users inserted"
else:
  echo "Insert failed"
```

## Select using ORM
```nim
## select single row
## ? is for string subtitution with parameter
let user = kbase.selectOne(Users(), sqlBuild.where("Users.name=?", "Foo"))

if not user.isNil:
  echo "User name is " & user.name.get
  echo "User uuid is " & user.uuid.get
  echo "User is active " & $user.isActive.get
  echo "User last update " & user.lastUpdate.get

## select multiple user
let users = kbase.select(Users(), sqlBuild.where("Users.name=? OR Users.name=?", ("Foo", "Bar")))

for user in users:
  echo "User name is " & user.name.get
  echo "User uuid is " & user.uuid.get
  echo "User is active " & $user.isActive.get
  echo "User last update " & user.lastUpdate.get
```

## Select using SqlBuilder
```nim
## select single row
## ? is for string subtitution with parameter
let user = kbase.queryOneRow(
    sqlBuild.
    select(("name", "uuid", "last_update", "is_active")).
    table("Users").
    where("Users.name=?", "Foo")
  )

##
## all return value is in string
## we need to get value depend on our need
##
if not user["id"].isNullOrEmpty:
  echo "User name is " & user["name"]
  echo "User uuid is " & user["uuid"]
  echo "User is active " & $user["is_active"].getBiggestInt.val
  echo "User last update " & user["last_update"].getBool.val

## select multiple user
let users = kbase.select(
    sqlBuild.
    select(("name", "uuid", "last_update", "is_active")).
    table("Users").
    where("Users.name IN (?)", @["Foo", "Bar"].join(","))
  )

for user in users:
  echo "User name is " & user["name"]
  echo "User uuid is " & user["uuid"]
  echo "User is active " & $user["is_active"].getBiggestInt.val
  echo "User last update " & user["last_update"].getBool.val
```

available fields conversion in raw query using SqlBuilder:

- **isNull**: check if field is NULL result
- **isEmpty**: check if field is empty
- **isNullOrEmpty**: check if field is NULL or empty
- **getBiggestInt.val**: get biggestInt value from field result
- **getBiggestUInt.val**: get biggestUInt value from field result
- **getInt.val**: get int value
- **getUInt.val**: get unsigned int value
- **getFloat.val**: get fractional value, ie double, float or decimal
- **getBool.val**: get boolean value
- **getBinInt.val**: get binary value as int from binary string, ie "b0001_1111"
- **getHexInt.val**: get hex value to int
- **getHexStr.val**: get encoded value to byte string representation
- **getOctInt.val**: get octal value to int
- **getJson.val**: get json value
- **getXml.val**: get xml value

## Update using ORM
```nim
echo "Test update single record"
var user = kbase.selectOne(Users(), sqlBuild.where("Users.name=? AND Users.is_active=?", ("Foo", false)))
if not user.isNil:
  user.lastUpdate = some "2025-02-25"
  user.isActive = some false

  echo "Update affected row " & $kbase.update(user)

  let user = kbase.selectOne(Users(), sqlBuild.where("Users.name=?", "Foo"))
  if not user.isNil:
    echo "Modify last update to " & user.lastUpdate.get
    echo "Modify is active to " & $user.isActive.get

echo ""
echo "Test update multiple record"
var users = kbase.select(Users())
for user in users:
  user.isActive = some false
  user.lastUpdate = some "2025-02-25"

  echo $kbase.update(users) & " users modified."

  users = kbase.select(Users())
  for user in users:
    echo "name " & user.name.get
    echo "is active " & $user.isActive.get
```

## Update using SqlBuilder
```nim
let updatedRow = kbase.execQueryAffectedRows(
    sqlBuild.
    update(("is_active", "last_update")).
    value((false, "2025-02-20")).
    table("Users").
    where("Users.is_active = ? AND Users.last_update <> '?'", (true, "2025-02-20"))
  )

echo $updatedRow & " record modified."
```

## Delete using ORM
```nim
echo "Test single delete"
let user = kbase.selectOne(Users(), sqlBuild.where("Users.name=?", "Foo"))
if not user.isNil and kbase.delete(user) != 0:
  echo "User " & user.name.get & " deleted."

echo ""
echo "Test multiple delete"
let users = kbase.select(Users(), sqlBuild.where("Users.name IN (?)", @["Foo", "Bar"].join(", ")))
let userDeleted = kbase.delete(users)

if userDeleted != 0:
  echo $userDeleted & " User(s) deleted."
```

## Delete using SqlBuilder
```nim
echo "Test delete"
let userDeleted = kbase.execQueryAffectedRows(
    sqlBuild.
    delete.
    table("Users").
    where("Users.name IN (?)", @["Foo", "Bar"].join(", "))
  )

if userDeleted != 0:
  echo $userDeleted & " User(s) deleted."
```

### Example complex query using SqlBuilder
```nim
var userRaw = kbase.queryOneRow(
    sqlBuild.
    select(("id", "name", "uuid")).
    table("Users").
    where("Users.name=?", "Foo")
  )

## check if result query id not empty
if not userRaw["id"].isNullOrEmpty:
  ##
  ## lets try to add some post data
  ##
  discard kbase.insertRow(
    sqlBuild.
    insert(("post", "usersId")).
    value(("best practice", userRaw["id"].getBiggestInt.val)).
    table("Posts")
  )

##
## select join
##

var usersRaw = kbase.queryRows(
    sqlBuild.
    select(
      (
        "Users.id AS userId",
        "Users.name AS userName",
        "Users.uuid AS userUUID",
        "post",
        "Posts.id AS postId"
      )
    ).
    table("Users").
    innerJoin("Posts", "Users.id = Posts.usersId")
  )

for user in usersRaw:
  echo "========="
  echo "User id " & $user["userId"].getBiggestInt.val
  echo "User name " & user["userName"]
  echo "User uuid " & user["userUUID"]
  echo "User post " & user["post"]
  echo "Post id " & $user["postId"].getBiggestInt.val


##
## lets try to modify
##
echo "== Test modify data"
userRaw = kbase.queryOneRow(
    sqlBuild.
    select(
      (
        "Users.id AS userId",
        "Users.name AS userName",
        "post",
        "Posts.id AS postId"
      )
    ).
    table("Users").
    innerJoin("Posts", "Users.id = Posts.usersId")
  )

var updatedRow = kbase.execQueryAffectedRows(
    sqlBuild.
    update("post").
    value("practice every day").
    table("Posts").
    where("Posts.id = ?", userRaw["postId"].getBiggestInt.val)
  )

echo $updatedRow & " record modified."

usersRaw = kbase.queryRows(
    sqlBuild.
    select(
      (
        "Users.id AS userId",
        "Users.name AS userName",
        "post",
        "Posts.id AS postId"
      )
    ).
    table("Users").
    innerJoin("Posts", "Users.id = Posts.usersId").
    orderByAsc("userId")
  )

for user in usersRaw:
  echo "========="
  echo "User id " & $user["userId"].getBiggestInt.val
  echo "User name " & user["userName"]
  echo "User post " & user["post"]
  echo "Post id " & $user["postId"].getBiggestInt.val


##
## try with subquery
##

var posts = kbase.queryRows(
    sqlBuild.
    select(("post", "usersId")).
    table("Posts").
    where(
      "Posts.usersId IN (?)",
      $sqlBuild.
      select("id").
      table("Users").
      where("Users.name=?", "Blah")
    )
  )

for post in posts:
  echo "========="
  echo "Post id " & $post["id"].getBiggestInt.val
  echo "Post content " & post["post"]
```

## Connection pooling
We plan to add support for connection pooling for our next developement, but we need to make sure everythings are agnostic between sqlite, mariadb and postgresql. Because we don't want to break our previous release and make smooth movement

## Work with transaction and query session
we can create session for multiple query, and also we can use transaction between session

```nim
let kbase = newKatabase[SqLite]("", "local.db", "", "")

#####
## start session
let dbSession = kbase.session

## do something multiple query here, may you need transaction you can also do here
dbSession.execQuery(...)
dbSession.execQueryAffectedRows(...)
dbSession.queryRows(...)
dbSession.queryOneRow(...)
dbSession.insert(...)
dbSession.update(...)
dbSession.delete(...)
dbSession.select(...)
## etc ...

## or with transaction
## start transaction
dbSession.transactionBegin

## do some db operation here

## check with query if condition meet commit if not roolback
if somethingWrong:
  dbSession.transactionRollback
else:
  dbSession.transactionCommit

## close session
dbSession.close
#####
```

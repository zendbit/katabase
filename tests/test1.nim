# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import std/files
import std/paths
import katalis/plugins/katabase


##
##  type which derived from DbModel already has id field as primary key
##  so we don't need to add manually id primary key
##
type
  ##
  ## the type derived from DbModel will automatic
  ## transform into database table schema
  ## when createTable called
  ##
  ##
  ## NOTE: all field value must be user options, and this is mandatory
  ## for DbModel
  ## firstname: Option[string]
  ##
  ##
  Users* {.dbTable.} = ref object of DbModel
    ##
    ## we also can add table alias to the Users
    ## if we add table alias in the actual database name will
    ## use alias and not the type name
    ##
    ## Users* {.dbTable: "tbl_users".} = ref object of DbModel
    ##
    ## With ebove type definition, the table schema will use tbl_users
    ## as table name
    ##
    name*: Option[string]
    lastUpdate* {.dbColumnType: "TIMESTAMP".} : Option[string]
    ##
    ## we can also add custom columntype depend on the specific database
    ## for example in the sqlite doesn't have vector type
    ## and we want to use vertor type in postgresql or mysql
    ##
    ## content* {.dbColumnType: "VECTOR".}
    ##
    ## we can also mixed some pragma into field, available pragma is:
    ##
    ## someFieldName* {.
    ##   dbColumnName: "tbl_some_field_name" -> for custom alias name
    ##   dbColumnType: "VARCHAR" -> for specific type
    ##   dbColumnLength: 10 -> set length of field
    ##   dbPrimaryKey -> treat field as primary key
    ##   dbNullable -> treat field as default NULL
    ##   dbAutoIncrement -> treat field as autoincrement
    ##   dbUnique -> treat field as unique
    ##   dbCompositeUnique -> same as dbUnique, but will compose with other
    ##   dbIgnore -> ignored field from query and db operation
    ##   dbReference: type -> for references to other type (relational)
    ## .}
    ##
    ##
    ## in postgresql we need to set dbColumnType: "SERIAL|BIGSERIAL" for auto
    ## increment
    ##
    isActive*: Option[bool]

  Posts* {.dbTable.} = ref object of DbModel
    post*: Option[string]
    usersId* {.dbReference: Users.}: Option[BiggestInt]
    ##
    ## usersId field will reference to Users.id
    ##

  Comments* {.dbTable.} = ref object of DbModel
    comment*: Option[string]
    usersId* {.dbReference: Users.}: Option[BiggestInt]
    ##
    ## usersId field will reference to Users.id
    ##
    postsId* {.dbReference: Posts.}: Option[BiggestInt]
    ##
    ## postsId field will reference to Posts.id
    ##

  UsersDetails* {.dbTable.} = ref object of DbModel
    usersId* {.dbReference: Users.}: Option[BiggestInt]
    address*: Option[string]


test "test katabase functionality":
  ##
  ## example bellow will connect to sqlite "test.db"
  ##
  let kbase = newKatabase[SqLite]("", "test.db", "", "")
  ##
  ## other option is for MariaDb/MySql and PostgreSql
  ##
  ## MariaDb/MySql
  ##
  ## let kbase = newKatabase[MySql](
  ##     "localhost",
  ##     "dbName",
  ##     "user",
  ##     "pass",
  ##     Port(7000), -> if not set will use default port (optional)
  ##     encoding -> if not set will use default encoding (optional)
  ##   )
  ##
  ## for postgresql just change the type to [PostgreSql]
  ##


  ##
  ## we optionally call create Users
  ## Users table will created automatically
  ## because it referenced by Posts, Comments and UsersDetails
  ##
  kbase.createTable(Posts())
  kbase.createTable(Comments())
  kbase.createTable(UsersDetails())


  ## lets try to insert into Users table
  echo "== Test insert"
  ## insert single directly
  let userId = kbase.insert(
      Users(
        name: some "Foo",
        lastUpdate: some "2025-01-30",
        isActive: some true
      )
    )

  ##
  ## userId value is primary key autoincrement from table
  ## after data inserted
  ##
  echo "User Foo id " & $userId

  ## we can also add multiple insert using batch list
  let numUserInserted = kbase.insert(
      [
        Users(
          name: some "Bar",
          lastUpdate: some "2025-01-30",
          isActive: some true
        ),
        Users(
          name: some "Blah",
          lastUpdate: some "2025-01-30",
          isActive: some true
        )
      ]
    )

  ##
  ## select all data
  ##
  var users = kbase.select(Users())
  for user in users:
    echo "User name " & user.name.get
    echo "User last update " & user.lastUpdate.get
    echo "User is active " & $user.isActive.get


  echo "== Test update"
  ##
  ## lets try to update some field
  ##
  var user = kbase.selectOne(Users(), sqlBuild.where("Users.name=$# AND Users.isActive=$#", ("Foo", false)))
  if not user.isNil:
    user.lastUpdate = some "2025-02-25"
    user.isActive = some false

    echo "Update affected row " & $kbase.update(user)

    let user = kbase.selectOne(Users(), sqlBuild.where("Users.name=$#", "Foo"))
    if not user.isNil:
      echo "Modify last update to " & user.lastUpdate.get
      echo "Modify is active to " & $user.isActive.get


  echo "== Test update multiple"
  ##
  ## lets try to update multiple fields
  ##
  users = kbase.select(Users())
  for user in users:
    user.isActive = some false
    user.lastUpdate = some "2025-02-25"

  echo $kbase.update(users) & " users modified."

  users = kbase.select(Users())
  for user in users:
    echo "name " & user.name.get
    echo "is active " & $user.isActive.get


  echo "== Test delete single"
  ##
  ## lets try to delete user
  ##
  user = kbase.selectOne(Users(), sqlBuild.where("Users.name=$#", "Foo"))
  if not user.isNil:
    if kbase.delete(user) != 0:
      echo "User " & user.name.get & " deleted."


  echo "== Test delete multiple"
  ##
  ## lets try delete batch multiple user
  ##
  users = kbase.select(Users())
  if kbase.delete(users) != 0:
    echo $users.len & " User deleted."


  echo "== Test raw select using SqlBuilder"

  ##
  ## SqlBuilder is handy tool for query orchestration
  ## to instantiate the query builder we just call sqlBuild
  ## then follow with sql sintax
  ##

  ##
  ## lets try to select Users
  ##

  if kbase.queryRows(
      sqlBuild.
      select(("id", "name", "lastUpdate", "isActive")).
      table("Users").
      where("Users.name NOT IN ($#)", @["Foo", "Bar", "Blah"].join(", "))
    ).len == 0:
    ## add "Foo Bar" user into Users

    ## insert single directly
    echo "== Test insert raw single"
    let userId = kbase.insertRow(
        sqlBuild.
          insert(("name", "lastUpdate", "isActive")).
          value(("Foo", "2025-01-30", true)).
          table("Users")
      )

    ##
    ## userId value is primary key autoincrement from table
    ## after data inserted
    ##
    echo "User Foo id " & $userId

    ##
    ## insert multiple value
    ##
    echo "== Test insert raw multiple"
    var numUserInserted = kbase.execQueryAffectedRows(
        sqlBuild.
          insert(("name", "lastUpdate", "isActive")).
          value(
            @[
              ("Bar", "2025-01-30", true),
              ("Blah", "2025-01-30", true)
            ]
          ).
          table("Users")
      )

  var usersRaw = kbase.queryRows(
      sqlBuild.
      select(("id", "name", "lastUpdate", "isActive")).
      table("Users")
    )

  for user in usersRaw:
    echo "======="
    echo "User name " & user["name"]
    echo "User id " & $user["id"].getInt.val
    echo "User last update " & user["lastUpdate"]

  ##
  ##
  ## from above example we have some get value conversion
  ## available value conversion from query row result
  ##
  ## .getInt -> will return Option[int] value, we can user .val or .get to convert to int
  ##
  ## other conversion
  ## .getUInt -> will return Option[UInt]
  ## .getBiggestInt -> will return Option[BiggestInt]
  ## .getBiggestUInt -> will return Option[BiggestInt]
  ## .isNull -> for checking if value isNull, return true|false
  ## .isEmpty -> for checking if value isEmpty, return true|false
  ## .isNullOrEmpty -> for checking if value is null or empty, return true|false
  ## .getFloat -> will return Option[float]
  ## .getBinInt -> will return Option[int] of binary string value to int
  ## .getHexInt -> will return Option[int] of hex string value to int
  ## .getHexStr -> will return Option[string], return encoded hex value to str
  ## .getOctalInt -> will return Option[int], return octal string to int
  ## .getJson -> will return Option[JsonNode], see std/json
  ## .getXml -> will return Option[XmlNode], see std/xmltree
  ##
  ##


  ##
  ##
  ## lets try to complex query like join
  ##
  ##

  var userRaw = kbase.queryOneRow(
      sqlBuild.
      select(("id", "name")).
      table("Users").
      where("Users.name=$#", "Blah")
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
      innerJoin("Posts", "Users.id = Posts.usersId")
    )

  for user in usersRaw:
    echo "========="
    echo "User id " & $user["userId"].getBiggestInt.val
    echo "User name " & user["userName"]
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
      where("Posts.id = $#", userRaw["postId"].getBiggestInt.val)
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
        "Posts.usersId IN ($#)" %
        $sqlBuild.
        select("id").
        table("Users").
        where("Users.name=$#", "Blah")
      )
    )

  for post in posts:
    echo "========="
    echo "Post id " & $post["id"].getBiggestInt.val
    echo "Post content " & post["post"]

## remove test database
"test.db".Path.removeFile

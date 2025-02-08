# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import std/files
import std/paths
import katalis/katabase

## test type with relational
type
  Users* {.dbTable.} = ref object of DbModel
    name*: Option[string]
    lastUpdate* {.dbColumnType: "TIMESTAMP".} : Option[string]

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


## connect to sqlite database
let kbase = newKatabase[SqLite]("", "test.db", "", "")

test "create table":
  kbase.createTable(Users())
  kbase.createTable(Posts())
  kbase.createTable(Comments())
  kbase.createTable(UsersDetails())

test "insert data":
  echo kbase.insert(Users(
    name: some "Foo Bar",
    lastUpdate: some "2025-01-12"
  ))

test "select data":
  echo %kbase.select(Users(), sqlBuild.where("Users.name=$#", "Foo Bar"))
  echo %kbase.selectOne(Users(), sqlBuild.where("Users.id=$#", 1))

test "select data custom":
  let users = kbase.queryRows(
      sqlBuild.
      select("id", "name", "lastUpdate").
      table("Users")
    )

  for user in users:
    echo user["id"].getBiggestInt
    echo user["name"]

  let user = kbase.queryOneRow(
      sqlBuild.
      select("id", "name", "lastUpdate").
      table("Users").
      where("Users.id=$#", 1)
    )

  echo user["id"].getBiggestInt
  echo user["name"]

test "update data":
  let user = kbase.selectOne(Users(), sqlBuild.where("Users.id=$#", 1))
  if not user.isNil:
    user.name = some "Bar Foo"
    echo kbase.update(user)

  echo %kbase.selectOne(Users(), sqlBuild.where("Users.name=$#", "Bar Foo"))

test "delete data":
  let users = kbase.select(Users())
  for user in users:
    echo %user
    echo kbase.delete(user)

  echo %kbase.select(Users())

"test.db".Path.removeFile

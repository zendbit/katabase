import
  dbModel,
  sqlBuilder
export
  dbModel,
  sqlBuilder

import
  std/[
    nativesockets
  ]
export
  Port


type
  Katabase*[T] = ref object of RootObj
    connType: T
    host*: string
    database*: string
    user*: string
    password*: string
    port*: Port
    encoding*: string


proc newKatabase*[T: PostgreSql|MySql|SqLite](
    host: string,
    database: string,
    user: string,
    password: string,
    port: Port = Port(0),
    encoding: string = ""
  ): Katabase[T] {.gcsafe.} = ## \
  ## create new katabase for database connection
  ## newKatabase[PostgreSql|MySql|SqLite](....)

  result = Katabase[T](
    host: host,
    database: database,
    user: user,
    password: password,
    port: port
  )


proc open[T](self: Katabase[T]): T {.gcsafe.} = ## \
  ## open database connection

  try:
    when self.connType is PostgreSql:
      var dbPort = $self.port
      if $self.port == $Port(0): dbPort = $Port(5432)
      result = db_postgres.open(
          &"{self.host}:{dbPort}",
          self.user,
          self.password,
          self.database
        )

    when self.connType is MySql:
      var dbPort = $self.port
      if $self.port == $Port(0): dbPort = $Port(3306)
      result = db_mysql.open(
          &"{self.host}:{dbPort}",
          self.user,
          self.password,
          self.database
        )

    when self.connType is SqLite:
      result = db_sqlite.open(self.database, "", "", "")

    if self.encoding != "":
      if not result.setEncoding(self.encoding):
        echo &"Failed to set encoding to: {self.encoding}"

  except CatchableError as ex:
    let port = $self.port
    let connection = $ type self.connType
    echo &"Failed to open database"
    echo &"Connection: {connection}"
    echo &"User: {self.user}"
    echo &"Host: {self.host}"
    echo &"Port: {port}"
    echo &"Database: {self.database}"
    echo &"Error: {ex.msg}"


proc whichDialect[T: Katabase|PostgreSql|MySql|SqLite](
    t: T
  ): DbDialect {.gcsafe.} = ## \
  ## get dialect depend on the connection type

  result = DbSqLite
  when t is Katabase:
    if t.connType is PostgreSql: result = DbPostgreSql
    elif t.connType is MySql: result = DbMySql

  else:
    if t is PostgreSql: result = DbPostgreSql
    elif t is MySql: result = DbMySql


proc execQuery*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ) {.gcsafe.} = ## \
  ## execute query

  try:
    session.exec(sql $query)

  except CatchableError as ex:
    echo &"Failed to execute query"
    echo &"Query: {query}"
    echo &"Error: {ex.msg}"


proc execQuery*(
    self: Katabase,
    query: SqlBuilder
  ) {.gcsafe.} = ## \
  ## execute query

  let conn = self.open
  conn.execQuery(query)
  conn.close


proc execQueryAffectedRows*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## execute query then return affected rows
  ## usually for updates statement

  try:
    result = session.execAffectedRows(sql $query)

  except CatchableError as ex:
    echo &"Failed to execute query"
    echo &"Query: {query}"
    echo &"Error: {ex.msg}"


proc execQueryAffectedRows*(
    self: Katabase,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## execute query then return affected rows
  ## usually for updates statement

  let conn = self.open
  result = conn.execQueryAffectedRows(query)
  conn.close


proc queryRows*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): RowResults {.gcsafe.} = ## \
  ## get all rows from query statement

  try:
    let rows = session.getAllRows(sql $query)
    result = rows.map(
        proc (r: seq[string]): RowResult =
          (query.columnNames, r)
      )

  except CatchableError as ex:
    echo &"Failed to execute query"
    echo &"Query: {query}"
    echo &"Error: {ex.msg}"


proc queryRows*(
    self: Katabase,
    query: SqlBuilder
  ): RowResults {.gcsafe.} = ## \
  ## get all rows from query statement

  let conn = self.open
  result = conn.queryRows(query)
  conn.close


proc queryOneRow*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): RowResult {.gcsafe.} = ## \
  ## get row from query

  try:
    let res = session.getRow(sql $query)
    result = (query.columnNames, res)

  except CatchableError as ex:
    echo &"Failed to execute query"
    echo &"Query: {query}"
    echo &"Error: {ex.msg}"


proc queryOneRow*(
    self: Katabase,
    query: SqlBuilder
  ): RowResult {.gcsafe.} = ## \
  ## get row from query

  let conn = self.open
  result = conn.queryOneRow(query)
  conn.close


proc queryValue*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): string {.gcsafe.} = ## \
  ## get single value of first row first column

  try:
    result = session.getValue(sql $query)

  except CatchableError as ex:
    echo &"Failed to execute query"
    echo &"Query: {query}"
    echo &"Error: {ex.msg}"


proc queryValue*(
    self: Katabase,
    query: SqlBuilder
  ): string {.gcsafe.} = ## \
  ## get single value of first row first column

  let conn = self.open
  result = conn.queryValue(query)
  conn.close


proc insertRow*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## insert into table and return generated id primary key
  ## primary key should named with id

  try:
    result = session.insertId(sql $query)

  except CatchableError as ex:
    echo &"Failed to execute query"
    echo &"Query: {query}"
    echo &"Error: {ex.msg}"


proc insertRow*(
    self: Katabase,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## insert into table and return generated id primary key
  ## primary key should named with id

  let conn = self.open
  result = conn.insertRow(query)
  conn.close


proc session*[T](self:Katabase[T]): T = ## \
  ## return db session connection
  ## for pool execQueryution

  self.open


proc transactionBegin*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.gcsafe.} = ## \
  ## transaction begin

  case session.whichDialect
  of DbPostgreSql:
    session.exec(sql "BEGIN")
  of DbMySql:
    session.exec(sql "SET autocommit=0")
    session.exec(sql "START TRANSACTION")
  of DbSqLite:
    session.exec(sql "BEGIN TRANSACTION")


proc transactionRollback*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.gcsafe.} = ## \
  ## transaction rollback

  session.exec(sql "ROLLBACK")


proc transactionCommit*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.gcsafe.} = ## \
  ## transaction commit

  session.exec(sql "COMMIT")


proc createTable*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2
  ) {.gcsafe.} = ## \
  ## create table from DbTable object

  let t = table.toDbTable(session.whichDialect)
  proc initTable(dbTbl: DbTableModel) {.gcsafe.} =
    for column in dbTbl.columns:
      if not column.reference.isNil:
        column.reference.initTable

    session.execQuery(dbTbl.toSql)

  t.initTable


proc createTable*[T: ref object](
    self: Katabase,
    table: T
  ) {.gcsafe.} = ## \
  ## create table from DbTable object

  let conn = self.open
  conn.createTable(table)
  conn.close


proc insert*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    t: T2
  ): BiggestInt {.gcsafe.} = ## \
  ## insert

  let t = t.toDbTable(session.whichDialect)
  let insertDbColumns: seq[DbColumnModel] =
    t.columns.filter(proc (c: DbColumnModel): bool =
      c.name != "id" or
      (c.name == "id" and c.value.kind != JNull))

  let columnNames: seq[string] =
      insertDbColumns.map(proc (c: DbColumnModel): string = c.validName)

  let insertValues: seq[JsonNode] =
      insertDbColumns.map(proc (c: DbColumnModel): JsonNode = c.value)

  session.insertRow(
    sqlBuild.
    insert(columnNames).
    table(t.validName).
    value(insertValues)
  )


proc insert*[T: ref object](
    self: Katabase,
    table: T
  ): BiggestInt {.gcsafe.} = ## \
  ## insert into table

  let conn = self.open
  result = conn.insert(table)
  conn.close


proc insert*[T: ref object](
    self: Katabase,
    table: openArray[T]
  ): BiggestInt {.gcsafe.} = ## \
  ## insert into table

  let conn = self.open
  try:
    conn.transactionBegin
    for t in table: discard conn.insert(t)
    result = table.len
    conn.transactionCommit
  except CatchableError: conn.transactionRollback
  conn.close


proc update*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## update database

  let t = table.toDbTable(session.whichDialect, false)
  let columnNames = t.columnValidNames.filter(proc (s: string): bool = s != "id")
  let updateValues =
    t.columns.filter(proc (c: DbColumnModel): bool = c.validName != "id").
    map(proc (c: DbColumnModel): JsonNode = c.value)


  let updateRow = if condition.isNil: sqlBuild else: condition

  if condition.isNil: updateRow.where(&"{t.validName}.id = $#", table.id)
  else: updateRow.where(&"AND {t.validName}.id = $#", table.id)

  updateRow.
    table(t.validName).
    update(columnNames).
    value(updateValues)

  session.execQueryAffectedRows(updateRow)


proc update*[T: ref object](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## update database

  let conn = self.open
  result = conn.update(table, condition)
  conn.close


proc update*[T: ref object](
    self: Katabase,
    table: openArray[T],
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## update database

  let conn = self.open
  try:
    conn.transactionBegin
    for t in table: discard conn.update(t, condition)
    result = table.len
    conn.transactionCommit
  except CatchableError: conn.transactionRollback
  conn.close


proc select*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): seq[T2] {.gcsafe.} = ## \
  ## select from database

  let t = table.toDbTable(session.whichDialect, false)
  let selectRows = if condition.isNil: sqlBuild else: condition
  selectRows.
    select(t.columnValidNames).
    table(t.validName)

  session.queryRows(selectRows).
    toDbTables(T2, session.whichDialect, false).
    to(T2)


proc select*[T: ref object](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil,
  ): seq[T] {.gcsafe.} = ## \
  ## select from database

  let conn = self.open
  result = conn.select(table, condition)
  conn.close


proc selectOne*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): T2 {.gcsafe.} = ## \
  ## select one from database

  let t = table.toDbTable(session.whichDialect, false)
  let selectRow = if condition.isNil: sqlBuild else: condition
  selectRow.
    select(t.columnValidNames).
    table(t.validName)

  let queryResult = session.queryOneRow(selectRow).
    toDbTable(T2, session.whichDialect, false).
    to(T2)

  if queryResult.id.isSome: result = queryResult


proc selectOne*[T: ref object](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): T {.gcsafe.} = ## \
  ## select one from database

  let conn = self.open
  result = conn.selectOne(table, condition)
  conn.close


proc count*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## count from database

  let t = table.toDbTable(session.whichDialect, false)
  let selectRow = if condition.isNil: sqlBuild else: condition
  selectRow.
    select("COUNT (id) AS count").
    table(t.validName)

  session.queryOneRow(selectRow)[0].parseBiggestInt


proc count*[T: ref object](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## count from database

  let conn = self.Katabase.open
  result = conn.count(table, condition)
  conn.close


proc delete*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## delete from database

  let t = table.toDbTable(session.whichDialect, false)
  let deleteRow = if condition.isNil: sqlBuild else: condition

  if condition.isNil: deleteRow.where(&"{t.validName}.id = $#", table.id)
  else: deleteRow.where(&"AND {t.validName}.id = $#", table.id)

  deleteRow.
    delete.
    table(t.validName)

  session.execQueryAffectedRows(deleteRow)


proc delete*[T: ref object](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## delete from database

  let conn = self.open
  result = conn.delete(table, condition)
  conn.close


proc delete*[T: ref object](
    self: Katabase,
    table: openArray[T],
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## delete from database

  let conn = self.open
  try:
    conn.transactionBegin
    for t in table: discard conn.delete(t, condition)
    result = table.len
    conn.transactionCommit
  except CatchableError: conn.transactionRollback
  conn.close

import
  dbModel,
  sqlBuilder
export
  dbModel,
  sqlBuilder

import
  std/[
    nativesockets,
    asyncdispatch,
    times
  ],
  uuids
export
  Port,
  asyncdispatch,
  uuids,
  times


type
  Katabase*[T] = ref object of RootObj
    connType: T
    host*: string
    database*: string
    user*: string
    password*: string
    port*: Port
    encoding*: string


var errorMsg {.threadvar.}: string


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

  errorMsg = ""
  result = Katabase[T](
    host: host,
    database: database,
    user: user,
    password: password,
    port: port
  )


proc clearError(self: Katabase) = ## \
  ## reset error message

  errorMsg = ""


proc putError(
    self: Katabase,
    error: string
  ) = ## \
  ## put error message

  errorMsg = error


proc hasError*(self: Katabase): bool = ## \
  ## check if has error message

  errorMsg != ""


proc getError*(self: Katabase): string = ## \
  ## get error message

  errorMsg


proc open[T](self: Katabase[T]): T {.gcsafe.} = ## \
  ## open database connection

  try:
    self.clearError
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

  except CatchableError, Defect:
    let port = $self.port
    let connection = $ type self.connType
    self.putError(
      &"Failed to open database\n" &
      &"Connection: {connection}\n" &
      &"User: {self.user}\n" &
      &"Host: {self.host}\n" &
      &"Port: {port}\n" &
      &"Database: {self.database}\n" &
      &"Error: {getCurrentExceptionMsg()}\n"
    )

    echo self.getError


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
    errorMsg = ""
    session.exec(sql $query)

  except CatchableError, Defect:
    errorMsg =
      &"Failed to execute query" &
      &"Query: {query}" &
      &"Error: {getCurrentExceptionMsg()}"

    echo errorMsg


proc execQueryAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ) {.async gcsafe.} = ## \
  ## execute query async

  session.execQuery(query)


proc execQuery*(
    self: Katabase,
    query: SqlBuilder
  ) {.gcsafe.} = ## \
  ## execute query

  let conn = self.open
  conn.execQuery(query)
  conn.close


proc execQueryAsync*(
    self: Katabase,
    query: SqlBuilder
  ) {.async gcsafe.} = ## \
  ## execute query async

  self.execQuery(query)


proc execQueryAffectedRows*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## execute query then return affected rows
  ## usually for updates statement

  try:
    errorMsg = ""
    result = session.execAffectedRows(sql $query)

  except [CatchableError, Defect]:
    errorMsg =
      &"Failed to execute query" &
      &"Query: {query}" &
      &"Error: {getCurrentExceptionMsg()}"

    echo errorMsg


proc execQueryAffectedRowsAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): Future[int64] {.async gcsafe.} = ## \
  ## execute query async then return affected rows
  ## usually for updates statement

  session.execQueryAffectedRows(query)


proc execQueryAffectedRows*(
    self: Katabase,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## execute query then return affected rows
  ## usually for updates statement

  let conn = self.open
  result = conn.execQueryAffectedRows(query)
  conn.close


proc execQueryAffectedRowsAsync*(
    self: Katabase,
    query: SqlBuilder
  ): Future[int64] {.async gcsafe.} = ## \
  ## execute query async then return affected rows
  ## usually for updates statement

  self.execQueryAffectedRows(query)


proc queryRows*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): RowResults {.gcsafe.} = ## \
  ## get all rows from query statement

  try:
    errorMsg = ""
    let rows = session.getAllRows(sql $query)
    result = rows.map(
        proc (r: seq[string]): RowResult =
          (query.columnNames, r)
      )

  except [CatchableError, Defect]:
    errorMsg =
      &"Failed to execute query" &
      &"Query: {query}" &
      &"Error: {getCurrentExceptionMsg()}"

    echo errorMsg


proc queryRowsAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): Future[RowResults] {.async gcsafe.} = ## \
  ## get all rows async from query statement

  session.queryRows(query)


proc queryRows*(
    self: Katabase,
    query: SqlBuilder
  ): RowResults {.gcsafe.} = ## \
  ## get all rows from query statement

  let conn = self.open
  result = conn.queryRows(query)
  conn.close


proc queryRowsAsync*(
    self: Katabase,
    query: SqlBuilder
  ): Future[RowResults] {.async gcsafe.} = ## \
  ## get all rows async from query statement

  self.queryRows(query)


proc queryOneRow*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): RowResult {.gcsafe.} = ## \
  ## get row from query

  try:
    errorMsg = ""
    let res = session.getRow(sql $query)
    result = (query.columnNames, res)

  except CatchableError, Defect:
    errorMsg =
      &"Failed to execute query" &
      &"Query: {query}" &
      &"Error: {getCurrentExceptionMsg()}"

    echo errorMsg


proc queryOneRowAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): Future[RowResult] {.async gcsafe.} = ## \
  ## get row async from query

  session.queryOneRow(query)


proc queryOneRow*(
    self: Katabase,
    query: SqlBuilder
  ): RowResult {.gcsafe.} = ## \
  ## get row from query

  let conn = self.open
  result = conn.queryOneRow(query)
  conn.close


proc queryOneRowAsync*(
    self: Katabase,
    query: SqlBuilder
  ): Future[RowResult] {.async gcsafe.} = ## \
  ## get row async from query

  self.queryOneRow(query)


proc queryValue*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): string {.gcsafe.} = ## \
  ## get single value of first row first column

  try:
    errorMsg = ""
    result = session.getValue(sql $query)

  except CatchableError, Defect:
    errorMsg =
      &"Failed to execute query" &
      &"Query: {query}" &
      &"Error: {getCurrentExceptionMsg()}"

    echo errorMsg


proc queryValueAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): Future[string] {.async gcsafe.} = ## \
  ## get single value async of first row first column

  session.queryValue(query)


proc queryValue*(
    self: Katabase,
    query: SqlBuilder
  ): string {.gcsafe.} = ## \
  ## get single value of first row first column

  let conn = self.open
  result = conn.queryValue(query)
  conn.close


proc queryValueAsync*(
    self: Katabase,
    query: SqlBuilder
  ): Future[string] {.async gcsafe.} = ## \
  ## get single value async of first row first column

  self.queryValue(query)


proc insertRow*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## insert into table and return generated id primary key
  ## primary key should named with id

  try:
    errorMsg = ""
    result = session.insertId(sql $query)

  except CatchableError, Defect:
    errorMsg =
      &"Failed to execute query" &
      &"Query: {query}" &
      &"Error: {getCurrentExceptionMsg()}"

    echo errorMsg


proc insertRowAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    query: SqlBuilder
  ): Future[int64] {.async gcsafe.} = ## \
  ## insert into table async and return generated id primary key
  ## primary key should named with id

  session.insertRow(query)


proc insertRow*(
    self: Katabase,
    query: SqlBuilder
  ): int64 {.gcsafe.} = ## \
  ## insert into table and return generated id primary key
  ## primary key should named with id

  let conn = self.open
  result = conn.insertRow(query)
  conn.close


proc insertRowAsync*(
    self: Katabase,
    query: SqlBuilder
  ): Future[int64] {.async gcsafe.} = ## \
  ## insert into table async and return generated id primary key
  ## primary key should named with id

  self.insertRow(query)


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


proc transactionBeginAsync*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.async gcsafe.} = ## \
  ## transaction begin async

  session.transactionBegin


proc transactionRollback*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.gcsafe.} = ## \
  ## transaction rollback

  session.exec(sql "ROLLBACK")


proc transactionRollbackAsync*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.async gcsafe.} = ## \
  ## transaction rollback async

  session.transactionRollback


proc transactionCommit*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.gcsafe.} = ## \
  ## transaction commit

  session.exec(sql "COMMIT")


proc transactionCommitAsync*[T: PostgreSql|MySql|SqLite](
    session: T
  ) {.async gcsafe.} = ## \
  ## transaction commit async

  session.transactionCommit


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
    # create index in defined
    for k, v in dbTbl.columnsIndex:
      session.execQuery(
        sqlBuild.
          create.
          index(k, v).
          table(dbTbl.validName)
      )

    for k, v in dbTbl.uniqueColumnsIndex:
      session.execQuery(
        sqlBuild.
          create.
          uniqueIndex(k, v).
          table(dbTbl.validName)
      )

  t.initTable


proc createTableAsync*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2
  ) {.async gcsafe.} = ## \
  ## create table async from DbTable object

  session.createTable(table)


proc createTable*[T: ref object](
    self: Katabase,
    table: T
  ) {.gcsafe.} = ## \
  ## create table from DbTable object

  let conn = self.open
  conn.createTable(table)
  conn.close


proc createTableAsync*[T: ref object](
    self: Katabase,
    table: T
  ) {.async gcsafe.} = ## \
  ## create table async from DbTable object

  self.createTable(table)


proc insert*[T: PostgreSql|MySql|SqLite, T2: ref object](
    session: T,
    table: T2
  ): tuple[id: BiggestInt, uuid: string] {.gcsafe.} = ## \
  ## insert

  var id: BiggestInt
  var uuid: string = $genUUID()

  when table is DbModel2:
    ## if DbModel2 insert uuid, createdAt, updatedAt, isActive
    let insertedAt = now().utc.format("yyyy-MM-dd HH:mm:ss")
    table.uuid = some uuid
    table.createdAt = some insertedAt
    table.updatedAt = some insertedAt
    table.isActive = some true

  let t = table.toDbTable(session.whichDialect)
  let insertDbColumns: seq[DbColumnModel] =
    t.columns.filter(proc (c: DbColumnModel): bool =
      c.name != "id" or
      (c.name == "id" and c.value.kind != JNull))

  let columnNames: seq[string] =
      insertDbColumns.map(proc (c: DbColumnModel): string = c.validName)

  let insertValues: seq[JsonNode] =
      insertDbColumns.map(proc (c: DbColumnModel): JsonNode = c.value)

  id = session.insertRow(
      sqlBuild.
      insert(columnNames).
      table(t.validName).
      value(insertValues)
    )

  ## return tuple (id: val, uuid: val)
  (id, uuid)


proc insertAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    t: DbModel
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## insert

  session.insert(t).id


proc insertAsync*[T: PostgreSql|MySql|SqLite](
    session: T,
    t: DbModel2
  ): Future[tuple[id: BiggestInt, uuid: string]] {.async gcsafe.} = ## \
  ## insert

  session.insert(t)


proc insert*[T: DbModel](
    self: Katabase,
    table: T
  ): BiggestInt {.gcsafe.} = ## \
  ## insert into table

  let conn = self.open
  result = conn.insert(table).id
  conn.close


proc insert*[T: DbModel2](
    self: Katabase,
    table: T
  ): tuple[id: BiggestInt, uuid: string] {.gcsafe.} = ## \
  ## insert into table

  let conn = self.open
  result = conn.insert(table)
  conn.close


proc insertAsync*[T: DbModel](
    self: Katabase,
    table: T
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## insert into table async

  self.insert(table).id


proc insertAsync*[T: DbModel2](
    self: Katabase,
    table: T
  ): Future[tuple[id: BiggestInt, uuid: string]] {.async gcsafe.} = ## \
  ## insert into table async

  self.insert(table)


proc insert*[T: DbModel|DbModel2](
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
  except CatchableError, Defect: conn.transactionRollback
  conn.close


proc insertAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: openArray[T]
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## insert into table saync

  self.insert(table)


proc update*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## update database

  when table is DbModel2:
    ## if DbModel2 update updatedAt
    let updatedAt = now().utc.format("yyyy-MM-dd HH:mm:ss")
    table.updatedAt = some updatedAt

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


proc updateAsync*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## update database async

  session.updateAsync(table, condition)


proc update*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## update database

  let conn = self.open
  result = conn.update(table, condition)
  conn.close


proc updateAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## update database async

  self.update(table, condition)


proc update*[T: DbModel|DbModel2](
    self: Katabase,
    table: openArray[T],
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## update database

  let conn = self.open
  for t in table: discard conn.update(t, condition)
  result = table.len
  conn.close


proc updateAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: openArray[T],
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## update database

  self.update(table, condition)


proc select*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
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


proc selectAsync*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): Future[seq[T2]] {.async gcsafe.} = ## \
  ## select from database async

  session.select(table, condition)


proc select*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil,
  ): seq[T] {.gcsafe.} = ## \
  ## select from database

  let conn = self.open
  result = conn.select(table, condition)
  conn.close


proc selectAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil,
  ): Future[seq[T]] {.async gcsafe.} = ## \
  ## select from database async

  self.select(table, condition)


proc selectOne*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
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


proc selectOneAsync*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): Future[T2] {.async gcsafe.} = ## \
  ## select one from database async

  session.selectOne(table, condition)


proc selectOne*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): T {.gcsafe.} = ## \
  ## select one from database

  let conn = self.open
  result = conn.selectOne(table, condition)
  conn.close


proc selectOneAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): Future[T] {.async gcsafe.} = ## \
  ## select one from database async

  self.selectOne(table, condition)


proc count*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
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


proc countAsync*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## count from database async

  session.count(table, condition)


proc count*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## count from database

  let conn = self.Katabase.open
  result = conn.count(table, condition)
  conn.close


proc countAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## count from database async

  self.count(table, condition)


proc delete*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
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


proc deleteAsync*[T: PostgreSql|MySql|SqLite, T2: DbModel|DbModel2](
    session: T,
    table: T2,
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## delete from database async

  session.delete(table, condition)


proc delete*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## delete from database

  let conn = self.open
  result = conn.delete(table, condition)
  conn.close


proc deleteAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: T,
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## delete from database async

  self.delete(table, condition)


proc delete*[T: DbModel|DbModel2](
    self: Katabase,
    table: openArray[T],
    condition: SqlBuilder = nil
  ): BiggestInt {.gcsafe.} = ## \
  ## delete from database

  let conn = self.open
  for t in table: discard conn.delete(t, condition)
  result = table.len
  conn.close


proc deleteAsync*[T: DbModel|DbModel2](
    self: Katabase,
    table: openArray[T],
    condition: SqlBuilder = nil
  ): Future[BiggestInt] {.async gcsafe.} = ## \
  ## delete from database async

  self.delete(table, condition)


proc checkConnection*(self: Katabase) {.gcsafe.} = ## \
  ## check connection to database

  let conn = self.open
  if not self.hasError:
    conn.close

import std/[
    macros,
    typetraits,
    times,
    options,
    parseutils,
    oids,
    tables
  ]
export
  times,
  options,
  oids,
  tables

import sqlBuilder
export sqlBuilder


template dbTable*(name: string = "") {.pragma.}
template dbColumnName*(name: string) {.pragma.}
template dbPrimaryKey* {.pragma.}
template dbNullable* {.pragma.}
template dbAutoIncrement* {.pragma.}
template dbColumnType*(columnType: string) {.pragma.}
template dbColumnLength*(length: BiggestInt) {.pragma.}
template dbUnique*(name: seq[string] = @[]) {.pragma.}
template dbReference*(t: typedesc) {.pragma.}
template dbIgnore* {.pragma.}
template dbUUID* {.pragma.}
template dbIndex*(name: seq[string] = @[]) {.pragma.}
template dbUniqueIndex*(name: seq[string] = @[]) {.pragma.}


type
  DbModel* {.dbTable.} = ref object of RootObj
    id* {.dbPrimaryKey dbAutoIncrement.}: Option[BiggestInt]

  DbTableModel* = ref object of RootObj
    name*: string
    alias*: string
    columns*: seq[DbColumnModel]
    compositeUnique*: seq[string]
    dialect*: DbDialect
    columnsIndex*: TableRef[string, seq[string]]
    uniqueColumnsIndex*: TableRef[string, seq[string]]
    uniqueColumns*: TableRef[string, seq[string]]

  DbColumnModel* = ref object of RootObj
    name*: string
    alias*: string
    isNullable*: bool
    isPrimaryKey*: bool
    isAutoIncrement*: bool
    columnType*: string
    columnLength*: BiggestInt
    isUnique*: bool
    reference*: DbTableModel
    typeOf*: string
    dialect*: DbDialect
    value*: JsonNode
    valueStr*: string


proc newDbTableModel*(
    dialect: DbDialect,
    name: string = "",
    alias: string = "",
    columns: seq[DbColumnModel] = @[],
    columnsIndex: TableRef[string, seq[string]] = newTable[string, seq[string]](),
    uniqueColumnsIndex: TableRef[string, seq[string]] = newTable[string, seq[string]](),
    uniqueColumns: TableRef[string, seq[string]] = newTable[string, seq[string]]()
  ): DbTableModel {.gcsafe.} = ## \
  ## create new DbTableModel

  DbTableModel(
    dialect: dialect,
    name: name,
    alias: alias,
    columns: columns,
    columnsIndex: columnsIndex,
    uniqueColumnsIndex: uniqueColumnsIndex,
    uniqueColumns: uniqueColumns
  )


proc newDbColumnModel*(
    dialect: DbDialect,
    name: string = "",
    alias: string = "",
    isNullable: bool = false,
    isPrimaryKey: bool = false,
    isAutoIncrement: bool = false,
    columnType: string = "",
    columnLength: BiggestInt = 0,
    reference: DbTableModel = nil,
    typeOf: string = "",
    value: JsonNode = nil,
    valueStr: string = ""
  ): DbColumnModel {.gcsafe.} = ## \
  ## new DbColumnModel

  DbColumnModel(
    dialect: dialect,
    name: name,
    alias: alias,
    isNullable: isNullable,
    isPrimaryKey: isPrimaryKey,
    isAutoIncrement: isAutoIncrement,
    columnType: columnType,
    columnLength: columnLength,
    reference: reference,
    typeOf: typeOf,
    value: value,
    valueStr: valueStr
  )


proc validName*[T: DbTableModel|DbColumnModel](
    t: T
  ): string {.gcsafe.} = ## \
  ## get valid name

  if t.alias != "": t.alias
  else: t.name


proc columnValidNames*(self: DbTableModel): seq[string] {.gcsafe.} = ## \
  ## get columns valid name list

  self.columns.map(proc (c: DbColumnModel): string = c.validName)


proc columnNames*(self: DbTableModel): seq[string] {.gcsafe.} = ## \
  ## get columns name list

  self.columns.map(proc (c: DbColumnModel): string = c.name)


proc toColumnValue*(
    val: string,
    typeOf: string
  ): JsonNode {.gcsafe.} = ## \
  # parse string to column value

  if val.toLower != "null":
    if typeOf.isOptionalIntMember:
      var res: BiggestInt
      if val.parseBiggestInt(res) != 0:
        result = %res

    elif typeOf.isOptionalFloatMember:
      var res: BiggestFloat
      if val.parseBiggestFloat(res) != 0:
        result = %res

    elif typeOf.isOptionalBoolMember:
      result = %false
      if val.toLowerAscii.contains("t") or
        val.toLowerAscii.contains("1"):
        result = %true

    else: result = %val

  else: result = %nil


proc toSql*(self: DbTableModel): SqlBuilder {.gcsafe.} = ## \
  ## string representation of db table
  var sqlb = sqlBuild.
    create.
    table(self.validName)

  var isIdAutoIncrement = false

  for column in self.columns:
    var columnType = column.columnType

    # check column type
    # if not pragma not set then set to default depend on the value
    if columnType == "":
      if column.typeOf.isOptionalIntMember:
        columnType = "BIGINT"

        if column.dialect == DbPostgreSql and
          column.isAutoIncrement:
          columnType = "BIGSERIAL"

        elif column.dialect == DbSqLite:
          columnType = "INTEGER"

      elif column.typeOf.isOptionalFloatMember:
        columnType = "DOUBLE PRECISION"

        if column.dialect == DbSqLite:
          columnType = "REAL"

      elif column.typeOf.isOptionalBoolMember:
        columnType = "INTEGER (1)"

      else:
        columnType = "TEXT"

    elif column.dialect == DbSqLite and columnType == "UUID": ## \
      ## if column type is UUID then change to TEXT for SQLITE
      columnType = "TEXT"

    if column.validName == "id" and column.isAutoIncrement: ## \
      ## if column name is id then make it auto increment
      isIdAutoIncrement = true

    sqlb.column(
      column.validName,
      columnType,
      column.columnLength,
      option =
        if column.isAutoIncrement and column.dialect == DbMySql: "AUTO_INCREMENT"
        else: "")

    if not column.reference.isNil:
      sqlb.foreignKey(
        column.validName,
        (column.reference.validName, "id"),
        "CASCADE",
        "CASCADE")

  for _, v in self.uniqueColumns:
    sqlb.unique(v.join(", "))

  if isIdAutoIncrement and self.dialect == DBSqLite:
    sqlb.primaryKey("id AUTOINCREMENT")
  else: sqlb.primaryKey("id")


proc toDbTable*[T: ref object](
    t: T,
    dialect: DbDialect,
    withReference: bool = true
  ): DbTableModel {.gcsafe.} = ## \
  ## convert ref object to DbTableModel

  if t.hasCustomPragma(dbTable):
    result = newDbTableModel(dialect)
    result.name = $ type T
    result.alias = t.getCustomPragmaVal(dbTable)

    for k, v in t[].fieldPairs:
      when not v.hasCustomPragma(dbIgnore):
        var column = newDbColumnModel(dialect)
        column.name = k
        var columnName = column.name

        when v.hasCustomPragma(dbColumnName):
          column.alias = v.getCustomPragmaVal(dbColumnName)
          columnName = column.alias

        column.isPrimaryKey = v.hasCustomPragma(dbPrimaryKey)
        column.isAutoIncrement = v.hasCustomPragma(dbAutoIncrement)

        when v.hasCustomPragma(dbColumnType):
          column.columnType = v.getCustomPragmaVal(dbColumnType)

        when v.hasCustomPragma(dbColumnLength):
          column.columnLength = v.getCustomPragmaVal(dbColumnLength)

        column.isNullable = v.hasCustomPragma(dbNullable)

        when v.hasCustomPragma(dbUnique):
          for name in v.getCustomPragmaVal(dbUnique):
            if not result.uniqueColumns.hasKey(name):
              result.uniqueColumns[name] = @[]

            if columnName notin result.uniqueColumns[name]:
              result.uniqueColumns[name].add(columnName)

          if v.getCustomPragmaVal(dbUnique).len == 0:
            result.uniqueColumns[columnName] = @[columnName]

        when v.hasCustomPragma(dbUniqueIndex):
          for name in v.getCustomPragmaVal(dbUniqueIndex):
            if not result.uniqueColumnsIndex.hasKey(name):
              result.uniqueColumnsIndex[name] = @[]

            if columnName notin result.uniqueColumnsIndex[name]:
              result.uniqueColumnsIndex[name].add(columnName)

          if v.getCustomPragmaVal(dbUniqueIndex).len == 0:
            result.uniqueColumnsIndex[columnName] = @[columnName]

        when v.hasCustomPragma(dbIndex):
          for name in v.getCustomPragmaVal(dbIndex):
            if not result.columnsIndex.hasKey(name):
              result.columnsIndex[name] = @[]

            if columnName notin result.columnsIndex[name]:
              result.columnsIndex[name].add(columnName)

          if v.getCustomPragmaVal(dbIndex).len == 0:
            result.columnsIndex[columnName] = @[columnName]

        if withReference:
          when v.hasCustomPragma(dbReference):
            column.reference = v.getCustomPragmaVal(dbReference)().
              toDbTable(dialect)

        when v.hasCustomPragma(dbModel.dbUUID):
          column.columnType = "UUID"

        column.typeOf = $ type v
        column.value = %v

        result.columns.add(column)

  else:
    raise newException(ValueError, &"type not contains dbTable pragma")


proc toDbTable*(
    row: RowResult,
    t: typedesc,
    dialect: DbDialect,
    withReference: bool = true
  ): DbTableModel {.gcsafe.} = ## \
  ## convert seq

  let table = t().toDbTable(dialect, withReference)
  for i in 0..row.val.high:
    if table.columns[i].name != row.key[i] and
      table.columns[i].alias != row.key[i]: continue

    table.columns[i].value = row.val[i].
      toColumnValue(table.columns[i].typeOf)

    result = table


proc toDbTables*(
    rows: RowResults,
    t: typedesc,
    dialect: DbDialect,
    withReference: bool = true
  ): seq[DbTableModel] {.gcsafe.} = ## \
  ## convert seq

  for values in rows:
    let table = values.toDbTable(t, dialect, withReference)
    if not table.isNil:
      result.add(table)


proc to*(
    self: DbTableModel,
    t: typedesc
  ): auto {.gcsafe.} = ## \
  ## convert DbTableModel to ref object

  let jObj = %*{}
  for column in self.columns:
    jObj[column.name] = column.value

  when t isnot JsonNode:
    jObj.to(t)
  else:
    jObj


proc to*(
    self: openArray[DbTableModel],
    t: typedesc
  ): auto {.gcsafe.} = ## \
  ## convert DbTableModel to ref object

  var tables: seq[t]
  for table in self:
    tables.add(table.to(t))

  tables


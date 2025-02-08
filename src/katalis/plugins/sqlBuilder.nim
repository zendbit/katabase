import std/tables

import common
export common


type
  SqlBuilder* = ref object of RootObj
    select: seq[string]
    isSelectDistinct: bool
    table: seq[string]
    where: seq[string]
    groupBy: seq[string]
    having: string
    orderBy: seq[string]
    limit: int
    offset: int
    union: seq[SqlBuilder]
    unionAll: seq[SqlBuilder]
    innerJoin: seq[string]
    innerJoinCondition: seq[string]
    leftJoin: seq[string]
    leftJoinCondition: seq[string]
    rightJoin: seq[string]
    rightJoinCondition: seq[string]
    insert: seq[string]
    value: seq[string]
    update: seq[string]
    isDelete: bool
    isCreate: bool
    column: seq[string]
    primaryKey: seq[string]
    unique: seq[string]
    foreignKey: TableRef[string, tuple[tableRef: string, columnRef: string]]
    foreignKeyOnDelete: TableRef[string, string]
    foreignKeyOnUpdate: TableRef[string, string]
    onUpdate: string
    onDelete: string


proc newSqlBuilder*(): SqlBuilder {.gcsafe.} = ## \
  ## create new sqlbulder object

  SqlBuilder(
    limit: -1,
    offset: -1,
    foreignKey: newTable[string, tuple[tableRef: string, columnRef: string]](),
    foreignKeyOnDelete: newTable[string, string](),
    foreignKeyOnUpdate: newTable[string, string]()
  )


proc `$`*(sb: SqlBuilder): string {.gcsafe.} = ## \
  ## sql builder to string

  var query: seq[string]
  if sb.select.len != 0:
    query.add("SELECT")
    if sb.isSelectDistinct: query.add("DISTINCT")
    query.add(sb.select.join(", "))
  
  if sb.insert.len != 0:
    query.add("INSERT")
  
  if sb.isCreate:
    query.add("CREATE")

  if sb.isDelete:
    query.add("DELETE")
  
  if sb.update.len != 0:
    query.add("UPDATE")

  if sb.table.len != 0:
    if sb.select.len != 0 or sb.isDelete:
      query.add("FROM")

    if sb.insert.len != 0:
      query.add("INTO")

    if sb.isCreate:
      query.add("TABLE")
      query.add("IF NOT EXISTS")

    query.add(sb.table.join(", "))

    if sb.isCreate:
      query.add("(")
      var createTableProperties: seq[string]
      if sb.column.len != 0:
        createTableProperties.add(sb.column.join(", "))

      if sb.primaryKey.len != 0:
        var primaryKey: seq[string]
        primaryKey.add("PRIMARY KEY")
        primarykey.add("(")
        primaryKey.add(sb.primaryKey.join(", "))
        primarykey.add(")")
        createTableProperties.add(primaryKey.join(" "))

      if sb.foreignKey.len != 0:
        for fk, fkRef in sb.foreignKey:
          var foreignKey: seq[string]
          foreignKey.add("FOREIGN KEY")
          foreignKey.add("(")
          foreignKey.add(fk)
          foreignKey.add(")")
          foreignKey.add("REFERENCES")
          foreignKey.add(fkRef.tableRef)
          foreignKey.add("(")
          foreignKey.add(fkRef.columnRef)
          foreignKey.add(")")
          if fk in sb.foreignKeyOnUpdate:
            foreignKey.add("ON UPDATE")
            foreignKey.add(sb.foreignKeyOnUpdate[fk])
          if fk in sb.foreignKeyOnDelete:
            foreignKey.add("ON DELETE")
            foreignKey.add(sb.foreignKeyOnDelete[fk])
          createTableProperties.add(foreignKey.join(" "))

      if sb.unique.len != 0:
        var unique: seq[string]
        unique.add("UNIQUE")
        unique.add("(")
        unique.add(sb.unique.join(", "))
        unique.add(")")
        createTableProperties.add(unique.join(" "))

      query.add(createTableProperties.join(", "))
      query.add(")")
    
  if sb.insert.len != 0:
    query.add("(")
    query.add(sb.insert.join(", "))
    query.add(")")

  if sb.update.len != 0:
    query.add("SET")

  if sb.value.len != 0:
    if sb.insert.len != 0:
      query.add("VALUES")
      query.add("(")
      query.add(sb.value.join(", "))
      query.add(")")

    if sb.update.len != 0:
      var updateStmt: seq[string]
      for i in 0..sb.update.high:
        updateStmt.add(&"{sb.update[i]} = {sb.value[i]}")

      query.add(updateStmt.join(", "))

  if sb.innerJoin.len != 0:
    for i in 0..sb.innerJoin.high:
      query.add("INNER JOIN")
      query.add(sb.innerJoin[i])
      query.add("ON")
      query.add(sb.innerJoinCondition[i])

  if sb.leftJoin.len != 0:
    for i in 0..sb.leftJoin.high:
      query.add("LEFT JOIN")
      query.add(sb.leftJoin[i])
      query.add("ON")
      query.add(sb.leftJoinCondition[i])

  if sb.rightJoin.len != 0:
    for i in 0..sb.rightJoin.high:
      query.add("RIGHT JOIN")
      query.add(sb.rightJoin[i])
      query.add("ON")
      query.add(sb.rightJoinCondition[i])

  if sb.where.len != 0:
    query.add("WHERE")
    query.add(sb.where.join(" "))

  if sb.groupBy.len != 0:
    query.add("GROUP BY")
    query.add(sb.groupBy.join(", "))
    
  if sb.having != "":
    query.add("HAVING")
    query.add(sb.having)

  if sb.orderBy.len != 0:
    query.add("ORDER BY")
    query.add(sb.orderBy.join(", "))
  
  if sb.limit != -1:
    query.add("LIMIT")
    query.add($sb.limit)

  if sb.offset != -1:
    query.add("OFFSET")
    query.add($sb.offset)

  if sb.union.len != 0:
    for unionQuery in sb.union:
      query.add("UNION")
      query.add($unionQuery)

  if sb.unionAll.len != 0:
    for unionQuery in sb.unionAll:
      query.add("UNION ALL")
      query.add($unionQuery)

  query.join(" ")


template sqlBuild*(): SqlBuilder = ## \
  ## sqlbuilder new instance

  newSqlBuilder()


proc columnNames*(self: SqlBuilder): seq[string] {.gcsafe.} = ## \
  ## get select columns name

  self.select.map(
    proc (column: string): string =
      if column.contains(" AS "):
        column.split(" AS ")[^1].strip
      else:
        column.strip
  )


proc select*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## select statement

  self.select &= column.toSeq
  self


proc create*(self: SqlBuilder): SqlBuilder {.gcsafe discardable.} = ## \
  ## create statement

  self.isCreate = true
  self


proc selectDistinct*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## select statement

  select(self, column).isSelectDistinct = true
  self


proc table*(
    self: SqlBuilder,
    table: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## from table

  self.table &= table.toSeq
  self


proc column*(
    self: SqlBuilder,
    column: string,
    columnType: string = "",
    length: int = 0,
    option: string = ""
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## table column for create table

  var columnDef = &"{column} {columnType}"
  if length != 0: columnDef &= &" ( {length} )"
  self.column.add((&"{columnDef} {option}").strip)
  self


proc primaryKey*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## primary key

  self.primaryKey &= column.toSeq
  self


proc foreignKey*(
    self: SqlBuilder,
    column: string,
    reference: tuple[tableRef: string, columnRef: string],
    onUpdate: string = "",
    onDelete: string = ""
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## foreign key

  self.foreignKey[column] = reference
  if onUpdate != "":
    self.foreignKeyOnUpdate[column] = onUpdate
  if onDelete != "":
    self.foreignKeyOnDelete[column] = onDelete
  self


proc unique*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## unique value

  self.unique &= column.toSeq
  self


proc onUpdate*(
    self: SqlBuilder,
    action: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## on update action

  self.onUpdate = action
  self


proc onDelete*(
    self: SqlBuilder,
    action: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## on delete action

  self.onDelete = action
  self


proc where*(
    self: SqlBuilder,
    condition: string,
    params: varargs[JsonNode, `%`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## where

  self.where &= condition % params.toSeq.toDbValue(true)
  self


proc groupBy*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## group by

  self.groupBy = column.toSeq
  self


proc having*(
    self: SqlBuilder,
    condition: string,
    params: varargs[JsonNode, `%`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## having

  self.having = condition % params.toSeq.toDbValue(true)
  self


proc orderBy*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## order by

  self.orderBy = column.toSeq
  self


proc limit*(
    self: SqlBuilder,
    limit: int
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## limit

  self.limit = limit
  self


proc offset*(
    self: SqlBuilder,
    offset: int
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## offset

  self.offset = offset
  self


proc union*(
    self: SqlBuilder,
    unionWith: SqlBuilder
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## union with other table

  self.union.add(unionWith)
  self


proc unionAll*(
    self: SqlBuilder,
    unionWith: SqlBuilder
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## union with other table

  self.unionAll.add(unionWith)
  self


proc innerJoin*(
    self: SqlBuilder,
    table: string,
    condition: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## inner join

  self.innerJoin.add(table)
  self.innerJoinCondition.add(condition)
  self


proc leftJoin*(
    self: SqlBuilder,
    table: string,
    condition: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## left join

  self.leftJoin.add(table)
  self.leftJoinCondition.add(condition)
  self


proc rightJoin*(
    self: SqlBuilder,
    table: string,
    condition: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## right join

  self.rightJoin.add(table)
  self.rightJoinCondition.add(condition)
  self


proc insert*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## insert data

  self.insert &= column.toSeq
  self


proc value*(
    self: SqlBuilder,
    value: varargs[JsonNode, `%`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## insert value

  self.value &= value.map(proc (n: JsonNode): string = n.toDbValue(true))
  self


proc update*(
    self: SqlBuilder,
    column: varargs[string, `$`]
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## update data

  self.update &= column.toSeq
  self


proc delete*(self: SqlBuilder): SqlBuilder {.gcsafe discardable.} = ## \
  ## delete data

  self.isDelete = true
  self

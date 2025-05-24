import std/tables

import common
export common


type
  SqlBuilder* = ref object of RootObj
    isDrop: bool
    select: seq[string]
    isSelectDistinct: bool
    index: seq[string]
    indexKey: string
    isUniqueIndex: bool
    table: seq[string]
    where: seq[string]
    groupBy: seq[string]
    having: string
    orderBy: seq[string]
    orderOption: string
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
    value: seq[seq[string]]
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


proc escapeQuery(query: string): string {.gcsafe.} = ## \
  ## escape query

  query.replace("??", "$_$_$").replace("?", "$#").replace("$_$_$", "?")


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

  if sb.isDrop:
    query.add("DROP")

  if sb.update.len != 0:
    query.add("UPDATE")

  if sb.index.len != 0 and not sb.isDrop:
    if sb.isUniqueIndex:
      query.add("UNIQUE")
    query.add("INDEX")
    query.add("IF NOT EXISTS")

  if sb.table.len != 0:
    if sb.select.len != 0 or sb.isDelete:
      query.add("FROM")

    if sb.insert.len != 0:
      query.add("INTO")

    if sb.isDrop:
      if sb.indexKey != "":
        query.add("INDEX")
        query.add("IF EXISTS")
        query.add(sb.indexKey)

    if sb.isCreate:
      if sb.index.len != 0: ## \
        ## if create index
        query.add(sb.indexKey)
        query.add("ON")
        query.add(sb.table[0])
        query.add("(")
        query.add(sb.index.join(", "))
        query.add(")")

      else:
        query.add("TABLE")
        query.add("IF NOT EXISTS")

    if sb.index.len == 0 and sb.indexKey == "": ## \
      ## if not create index
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
          for u in sb.unique:
            unique.add(&"UNIQUE ( {u} )")
          createTableProperties.add(unique.join(", "))

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
      var insertValue: seq[string]
      for val in sb.value:
        insertValue.add("( " & val.join(", ") & " )")
      query.add(insertValue.join(","))

    if sb.update.len != 0:
      var updateStmt: seq[string]
      for i in 0..sb.update.high:
        updateStmt.add(&"{sb.update[i]} = {sb.value[0][i]}")

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
    query.add(sb.orderOption)

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


proc toSqlBuilderValue*[T](
    value: T
  ): seq[seq[string]] = ## \
  ## parse value argument
  ## make it flexible
  ## user can pas seq or tuple

  when value isnot seq and value isnot tuple:
    when value is SqlBuilder:
      result.add(@[(% &"SqlBuilder:{value}").toDbValue])
    else:
      result.add(@[(%value).toDbValue(true)])

  when value is seq[tuple]:
    for l in value:
      var vals: seq[JsonNode]
      for v in l.fields:
        vals.add(%v)
      result.add(vals.toDbValue(true))

  when value is seq[JsonNode]:
    result.add(value.map(proc (n: JsonNode): string = n.toDbValue(true)))

  when value is seq[seq[JsonNode]]:
    for v in value:
      result.add(v.map(proc (n: JsonNode): string = n.toDbValue(true)))

  when value is tuple:
    var vals: seq[JsonNode]
    for v in value.fields:
      when v is SqlBuilder:
        vals.add((% &"SqlBuilder:{v}").toDbValue)
      else:
        vals.add(%v)
    result.add(vals.toDbValue(true))


proc toSqlBuilderParam*[T: seq|tuple|string](
    value: T
  ): seq[string] = ## \
  ## parse value argument
  ## make it flexible
  ## user can pas seq or tuple

  when value is string:
    result.add(value)

  when value is tuple:
    for v in value.fields:
      result.add(v)

  when value is seq:
    result = value


proc columnNames*(self: SqlBuilder): seq[string] {.gcsafe.} = ## \
  ## get select columns name

  self.select.map(
    proc (column: string): string =
      if column.contains(" AS "):
        column.split(" AS ")[^1].strip
      else:
        column.strip
  )


proc select*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## select statement

  self.select &= column.toSqlBuilderParam
  self


proc create*(self: SqlBuilder): SqlBuilder {.gcsafe discardable.} = ## \
  ## create statement

  self.isCreate = true
  self


proc drop*(self: SqlBuilder): SqlBuilder {.gcsafe discardable.} = ## \
  ## drop statement

  self.isDrop = true
  self


proc index*[T](
    self: SqlBuilder,
    key: string,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## create column index

  self.index &= column.toSqlBuilderParam
  self.indexKey = key
  self


proc uniqueIndex*[T](
    self: SqlBuilder,
    key: string,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## create column index

  self.index(key, column)
  self.isUniqueIndex = true
  self.indexKey = key
  self


proc index*(
    self: SqlBuilder,
    key: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## create column index

  self.indexKey = key
  self


proc uniqueIndex*(
    self: SqlBuilder,
    key: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## create column index

  self.index(key)
  self.isUniqueIndex = true
  self


proc selectDistinct*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## select statement

  select(self, column).isSelectDistinct = true
  self


proc table*[T](
    self: SqlBuilder,
    table: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## from table

  self.table &= table.toSqlBuilderParam
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


proc primaryKey*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## primary key

  self.primaryKey &= column.toSqlBuilderParam
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


proc unique*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## unique value

  self.unique &= column.toSqlBuilderParam
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
    condition: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## where

  self.where &= condition
  self


proc where*[T](
    self: SqlBuilder,
    condition: string,
    params: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## where

  where(self, condition.escapeQuery % params.toSqlBuilderValue[0])


proc groupBy*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## group by

  self.groupBy = column.toSqlBuilderParam
  self


proc having*(
    self: SqlBuilder,
    condition: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## having

  self.having = condition
  self


proc having*[T](
    self: SqlBuilder,
    condition: string,
    params: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## having

  having(self, condition.escapeQuery % params.toSqlBuilderValue[0])


proc orderBy*[T](
    self: SqlBuilder,
    column: T,
    orderOption: string
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## order by

  self.orderBy = column.toSqlBuilderParam
  self.orderOption = orderOption
  self


proc orderByAsc*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## order by ascending

  orderBy(self, column, "ASC")


proc orderByDesc*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## order by ascending

  orderBy(self, column, "DESC")


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
    unionAll: SqlBuilder
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## union with other table

  self.unionAll.add(unionAll)
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


proc insert*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## insert data

  self.insert &= column.toSqlBuilderParam
  self


proc value*[T](
    self: SqlBuilder,
    value: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## insert value

  self.value &= value.toSqlBuilderValue
  self


proc update*[T](
    self: SqlBuilder,
    column: T
  ): SqlBuilder {.gcsafe discardable.} = ## \
  ## update data

  self.update &= column.toSqlBuilderParam
  self


proc delete*(self: SqlBuilder): SqlBuilder {.gcsafe discardable.} = ## \
  ## delete data

  self.isDelete = true
  self

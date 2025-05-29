import db_connector/[
    db_mysql,
    db_postgres,
    db_sqlite
  ]
export
  db_mysql,
  db_postgres,
  db_sqlite


import std/[
    json,
    sequtils,
    strformat,
    strutils,
    options,
    xmlparser,
    xmltree,
    tables
  ]
export
  json,
  sequtils,
  strformat,
  strutils,
  options,
  xmlparser,
  xmltree,
  tables


let dbEscape* = db_sqlite.dbQuote

type
  DbDialect* = enum
    DbPostgreSql
    DbMySql
    DbSqLite
    None

  PostgreSql* = db_postgres.DbConn
  MySql* = db_mysql.DbConn
  SqLite* = db_sqlite.DbConn
  DbRow* = seq[string]

  RowResult* = tuple[key: seq[string], val: DbRow]
  RowResults* = seq[RowResult]


proc `in`*[T: RowResult|RowResults](column: string, row: T): bool {.gcsafe.} = ## \
  ## check if column string in RowResult|RowResults

  column in row.key


proc `notin`*[T: RowResult|RowResults](column: string, row: T): bool {.gcsafe.} = ## \
  ## check if column string notin RowResult|RowResults

  column notin row.key


proc `[]`*(row: RowResult, column: string): string {.gcsafe.} = ## \
  ## get value of RowResult
  ## by column names

  var idx: int = -1
  for k in row.key:
    idx = idx + 1
    if column != k: continue
    else: break

  row.val[idx]


proc toTable*(row: RowResult): Table[string, string] {.gcsafe.} =
  result = initTable[string, string]()
  for idx in 0..row.key.high:
    result[row.key[idx]] = row.val[idx]


proc toSeqTable*(rows: RowResults): seq[Table[string, string]] {.gcsafe.} =
  for row in rows:
    result.add(row.toTable)


proc toDbValue*(
    val: JsonNode,
    escape: bool = false
  ): string {.gcsafe.} = ## \
  ## to db value string

  if val.kind == JString:
    let value = val.getStr
    if value.startsWith("SqlBuilder:"):
      return value.replace("SqlBuilder:", "")

    if escape:
      return val.getStr.dbEscape

    value
  else: $val


proc toDbValue*(
    val: seq[JsonNode],
    escape: bool = false
  ): seq[string] {.gcsafe.} = ## \
  ## to db value string

  val.map(proc (val: JsonNode): string = val.toDbValue(escape))


proc isOptionalBoolMember*(val: string): bool {.gcsafe.} = ## \
  ## check if string is optional boolean value

  val == $ type Option[bool]


proc isOptionalIntMember*(val: string): bool {.gcsafe.} = ## \
  ## check if string is optional int value

  val in [
      $ type Option[int],
      $ type Option[uint],
      $ type Option[int8],
      $ type Option[uint8],
      $ type Option[int16],
      $ type Option[uint16],
      $ type Option[int64],
      $ type Option[uint64],
      $ type Option[int32],
      $ type Option[uint32],
      $ type Option[BiggestInt],
      $ type Option[BiggestUInt]
    ]


proc isOptionalFloatMember*(val: string): bool {.gcsafe.} = ## \
  ## check if string is optional float value

  val in [
      $ type Option[float64],
      $ type Option[float32],
      $ type Option[float],
      $ type Option[BiggestFloat]
    ]


proc isNull*(val: string): bool {.gcsafe.} = ## \
  ## check if string is represent null value

  val.toLower.strip == "null" or
  val.toLower.strip == "nil"


proc isEmpty*(val: string): bool {.gcsafe.} = ## \
  ## check if string is represent empty value

  val.toLower.strip == ""


proc isNullOrEmpty*(val: string): bool {.gcsafe.} = ## \
  ## check if string is represent empty or null value

  val.isNull or val.isEmpty


proc getInt*(val: string): Option[int] {.gcsafe.} = ## \
  ## get int value

  try: result = some val.strip.parseInt
  except: discard


proc getUInt*(val: string): Option[uint] {.gcsafe.} = ## \
  ## get uint value

  try: result = some val.strip.parseUInt
  except: discard


proc getBiggestInt*(val: string): Option[BiggestInt] {.gcsafe.} = ## \
  ## get BiggestInt value

  try: result = some val.strip.parseBiggestInt
  except: discard


proc getBiggestUInt*(val: string): Option[BiggestUInt] {.gcsafe.} = ## \
  ## get BiggestUInt value

  try: result = some val.strip.parseBiggestUInt
  except: discard


proc getFloat*(val: string): Option[float] {.gcsafe.} = ## \
  ## get float value

  try: result = some val.strip.parseFloat
  except: discard


proc getBool*(val: string): Option[bool] {.gcsafe.} = ## \
  ## get bool value

  if val.toLower.strip == "t": return some true
  if val.toLower.strip == "f": return some false
  try: result = some val.strip.parseBool
  except: discard


proc getBinInt*(val: string): Option[int] {.gcsafe.} = ## \
  ## get binary value to int

  try: result = some val.strip.parseBinInt
  except: discard


proc getHexInt*(val: string): Option[int] {.gcsafe.} = ## \
  ## get hex value to int

  try: result = some val.strip.parseHexInt
  except: discard


proc getHexStr*(val: string): Option[string] {.gcsafe.} = ## \
  ## get hex encoded value to byte str

  try: result = some val.strip.parseHexStr
  except: discard


proc getOctInt*(val: string): Option[int] {.gcsafe.} = ## \
  ## get octal value to int

  try: result = some val.strip.parseOctInt
  except: discard


proc getJson*(val: string): Option[JsonNode] {.gcsafe.} = ## \
  ## get json node value

  try: result = some val.strip.parseJson
  except: discard


proc getXml*(val: string): Option[XmlNode] {.gcsafe.} = ## \
  ## get xml node value

  try: result = some val.strip.parseXml
  except: discard


proc val*[T](o: Option[T]): T = ## \
  ## get Option value
  ## alias .get

  o.get

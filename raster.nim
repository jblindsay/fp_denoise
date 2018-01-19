#[
Author: Dr. John Lindsay
Created: January 18, 2018
Last Modified: January 19, 2018
License: MIT

Notes: Module for reading and writing Whitebox and ArcGIS ASCII raster formats.
]#

import byte_order_reader, byte_order_writer, strutils
import system, endians, os, math, sequtils

##########
# Errors #
##########
type FileIOError = object of Exception

############
# DataType #
############
type DataType = enum
  f64, f32, i32, i16, i8, none

#############
# DataScale #
#############
type DataScale = enum
  continuous, categorical, boolean

# type ByteOrder = enum
#   lsbf, msbf

type Raster* = object
  filename*: string
  minimum*: float64
  maximum*: float64
  rows*: int
  columns*: int
  stacks*: int
  north*: float64
  south*: float64
  east*: float64
  west*: float64
  dataType*: DataType
  zUnits*: string
  xyUnits*: string
  projection*: string
  dataScale*: DataScale
  displayMinimum*: float64
  displayMaximum*: float64
  palette*: string
  nodata*: float64
  byteOrder*: Endianness
  paletteNonlinearity*: float64
  resolutionX*: float64
  resolutionY*: float64
  metadata*: seq[string]
  values: seq[float64]

proc `$`*(self: Raster): string =
  result = "Min:\t$1\n".format(self.minimum)
  result.add("Max:\t$1\n".format(self.maximum))
  result.add("Rows:\t$1\n".format(self.rows))
  result.add("Cols:\t$1\n".format(self.columns))
  result.add("Stacks:\t$1\n".format(self.stacks))
  result.add("North:\t$1\n".format(self.north))
  result.add("South:\t$1\n".format(self.south))
  result.add("East:\t$1\n".format(self.east))
  result.add("West:\t$1\n".format(self.west))

  case self.dataType:
  of DataType.f64:
    result.add("Data Type:\tdouble\n")
  of DataType.f32:
    result.add("Data Type:\tfloat\n")
  of DataType.i32:
    result.add("Data Type:\ti32\n")
  of DataType.i16:
    result.add("Data Type:\tinteger\n")
  else:
    result.add("Data Type:\tbyte\n")

  result.add("Z Units:\t$1\n".format(self.zUnits))
  result.add("XY Units:\t$1\n".format(self.xyUnits))
  result.add("Projection:\t$1\n".format(self.projection))
  result.add("Data Scale:\t$1\n".format(self.dataScale))
  result.add("Display Min:\t$1\n".format(self.displayMinimum))
  result.add("Display Max:\t$1\n".format(self.displayMaximum))
  result.add("Preferred Palette:\t$1\n".format(self.palette))
  result.add("NoData:\t$1\n".format(self.nodata))
  if self.byteOrder == littleEndian:
    result.add("Byte Order:\tLITTLE_ENDIAN\n")
  else:
    result.add("Byte Order:\tBIG_ENDIAN\n")
  result.add("Palette Nonlinearity:\t$1\n".format(self.palette))
  for v in self.metadata:
    result.add("Metadata Entry:\t$1\n".format(v.replace(":", ";")))

proc `[]=`*(self: var Raster, row, column: int, value: float64) {.inline.} =
  if row >= 0 and row < self.rows and column >= 0 and column < self.columns:
    let index = row * self.columns + column
    if index >= 0 and index < len(self.values):
        self.values[index] = value

proc `[]`*(self: Raster, row, column: int): float64  {.inline.} =
  if row >= 0 and row < self.rows and column >= 0 and column < self.columns:
    let index = row * self.columns + column
    if index >= 0 and index < len(self.values):
      return self.values[index]

  result = self.nodata

proc readWhiteboxRaster*(self: var Raster) =
  self.metadata = newSeq[string]()

  var fn =
    if self.filename.toLowerAscii.contains(".dep"):
      self.filename
    else:
      self.filename.replace(".tas", ".dep")

  var f = open(fn)
  defer: close(f)
  for line in f.lines:
    # echo line
    let lcLine = line.toLowerAscii
    if "min:" in lcLine and not lcLine.contains("display"):
      self.minimum = parseFloat(line.split(":")[1].strip)
    elif "max:" in lcLine and not lcLine.contains("display"):
      self.maximum = parseFloat(line.split(":")[1].strip)
    elif "rows:" in lcLine:
      self.rows = parseInt(line.split(":")[1].strip)
    elif "cols:" in lcLine:
      self.columns = parseInt(line.split(":")[1].strip)
    elif "stacks:" in lcLine:
      self.stacks = parseInt(line.split(":")[1].strip)
    elif "north:" in lcLine:
      self.north = parseFloat(line.split(":")[1].strip)
    elif "south:" in lcLine:
      self.south = parseFloat(line.split(":")[1].strip)
    elif "east:" in lcLine:
      self.east = parseFloat(line.split(":")[1].strip)
    elif "west:" in lcLine:
      self.west = parseFloat(line.split(":")[1].strip)
    elif "data type:" in lcLine:
      let v = line.split(":")[1].strip.toLowerAscii
      if "float" in v:
        self.dataType = DataType.f32
      elif "double" in v:
        self.dataType = DataType.f64
      elif "i32" in v:
        self.dataType = DataType.i32
      elif "short" in v or "integer" in v:
        self.dataType = DataType.i16
      elif "byte" in v:
        self.dataType = DataType.i8
    elif "z units:" in lcLine:
      self.zUnits = line.split(":")[1].strip
    elif "xy units:" in lcLine:
      self.xyUnits = line.split(":")[1].strip
    elif "projection:" in lcLine:
      self.projection = line.split(":")[1].strip
    elif "data scale:" in lcLine:
      let v = line.split(":")[1].strip.toLowerAscii
      if "continuous" in v:
        self.dataScale = DataScale.continuous
      elif "categorical" in v:
        self.dataScale = DataScale.categorical
      elif "bool" in v:
        self.dataScale = DataScale.boolean
    elif "display min:" in lcLine:
      self.displayMinimum = parseFloat(line.split(":")[1].strip)
    elif "display max:" in lcLine:
      self.displayMaximum = parseFloat(line.split(":")[1].strip)
    elif "preferred palette:" in lcLine:
      self.palette = line.split(":")[1].strip
    elif "nodata:" in lcLine:
      self.nodata = parseFloat(line.split(":")[1].strip)
    elif "data scale:" in lcLine:
      let v = line.split(":")[1].strip.toLowerAscii
      if "LITTLE" in v:
        self.byteOrder = Endianness.littleEndian
      else:
        self.byteOrder = Endianness.bigEndian
    elif "palette nonlinearity:" in lcLine:
      self.paletteNonlinearity = parseFloat(line.split(":")[1].strip)
    elif "metadata" in lcLine:
      self.metadata.add(line.split(":")[1].strip)

  self.resolutionX = (self.east - self.west) / float(self.columns)
  self.resolutionY = (self.north - self.south) / float(self.rows)

  self.values = newSeq[float64](self.rows * self.columns)
  # for i in 0..<self.values.len:
  #   self.values[i] = self.nodata

  fn =
    if self.filename.toLowerAscii.contains(".dep"):
      self.filename.replace(".dep", ".tas")
    else:
      self.filename

  var fileSize = getFileSize(fn)
  var buf = newSeq[uint8](fileSize)
  var df = open(fn, fmRead)
  defer: df.close()
  discard df.readBytes(buf, Natural(0), Natural(fileSize))

  var bor: ByteOrderReader = newByteOrderReader(buf, self.byteOrder)
  let numPoints = self.rows * self.columns
  case self.dataType:
  of DataType.f64:
    for i in 0..<numPoints:
      self.values[i] = bor.readFloat64
  of DataType.f32:
    for i in 0..<numPoints:
      self.values[i] = float64(bor.readFloat32)
  of DataType.i32:
    for i in 0..<numPoints:
      self.values[i] = float64(bor.readInt32)
  of DataType.i16:
    for i in 0..<numPoints:
      self.values[i] = float64(bor.readInt16)
  else:
    for i in 0..<numPoints:
      self.values[i] = float64(bor.readInt8)

proc calculateMinAndMax(self: var Raster) =
  for i in 0..<self.rows * self.columns:
    let z = self.values[i]
    if z != self.nodata:
      if z < self.minimum:
        self.minimum = z
      if z > self.maximum:
        self.maximum = z

proc writeWhiteboxRaster*(self: var Raster) =
  try:
    self.calculateMinAndMax()

    if self.displayMaximum.classify == fcNegInf:
      self.displayMaximum = self.maximum

    if self.displayMinimum.classify == fcInf:
      self.displayMinimum = self.minimum

    # write the header file
    var fn =
      if self.filename.toLowerAscii.contains(".dep"):
        self.filename
      else:
        self.filename.replace(".tas", ".dep")

    let o = open(fn, fmWrite)
    defer: o.close
    o.writeLine(self)

    # write the data file
    let dataSize =
      if self.dataType == DataType.f64:
        8
      elif self.dataType == DataType.f32 or self.dataType == DataType.i32:
        4
      elif self.dataType == DataType.i16:
        2
      else:
        1

    var fileSize = dataSize * self.rows * self.columns

    fn =
      if self.filename.toLowerAscii.contains(".dep"):
        self.filename.replace(".dep", ".tas")
      else:
        self.filename

    var df = open(fn, fmWrite)
    defer: df.close()

    var bow: ByteOrderWriter = newByteOrderWriter(fileSize, self.byteOrder)
    let numPoints = self.rows * self.columns
    case self.dataType:
    of DataType.f64:
      for i in 0..<numPoints:
        bow.writeFloat64(self.values[i])
    of DataType.f32:
      var val: float32
      for i in 0..<numPoints:
        val = float32(self.values[i])
        bow.writeFloat32(val)
    of DataType.i32:
      var val: int32
      for i in 0..<numPoints:
        val = int32(self.values[i])
        bow.writeInt32(val)
    of DataType.i16:
      var val: int16
      for i in 0..<numPoints:
        val = int16(self.values[i])
        bow.writeInt16(val)
    else:
      var val: int8
      for i in 0..<numPoints:
        val = int8(self.values[i])
        bow.writeInt8(val)

    discard df.writeBytes(bow.data, 0, fileSize)

  except:
    echo "Got exception ", repr(getCurrentException()), " with message ", getCurrentExceptionMsg()

proc readArcAscii(self: var Raster) =
  try:
    # read the file
    var f = open(self.filename)
    defer: close(f)

    var xllcenter: float64 = NegInf
    var yllcenter: float64 = NegInf
    var xllcorner: float64 = NegInf
    var yllcorner: float64 = NegInf

    var index = 0
    for line in f.lines:
      var lineSplit = line.strip.split(" ")
      if lineSplit.len() == 1:
        lineSplit = line.strip.split("\t")

      let lastIndex = len(lineSplit) - 1
      if lineSplit[0].toLowerAscii().contains("nrows"):
        self.rows = parseInt(lineSplit[lastIndex].strip)
      elif lineSplit[0].toLowerAscii().contains("ncols"):
        self.columns = parseInt(lineSplit[lastIndex].strip)
      elif lineSplit[0].toLowerAscii().contains("xllcorner"):
        xllcenter = parseFloat(lineSplit[lastIndex].strip)
      elif lineSplit[0].toLowerAscii().contains("yllcorner"):
        yllcenter = parseFloat(lineSplit[lastIndex].strip)
      elif lineSplit[0].toLowerAscii().contains("xllcenter"):
        xllcorner = parseFloat(lineSplit[lastIndex].strip)
      elif lineSplit[0].toLowerAscii().contains("yllcenter"):
        yllcorner = parseFloat(lineSplit[lastIndex].strip)
      elif lineSplit[0].toLowerAscii().contains("cellsize"):
        self.resolutionX = parseFloat(lineSplit[lastIndex].strip)
        self.resolutionY = parseFloat(lineSplit[lastIndex].strip)
      elif lineSplit[0].toLowerAscii().contains("nodata_value"):
        if lineSplit[lastIndex].contains("."):
          self.dataType = DataType.f32
        else:
          self.dataType = DataType.i32

        self.nodata = parseFloat(lineSplit[lastIndex].strip)
      else: # it's a data line
        if self.values == nil:
          self.values = newSeq[float64](self.rows * self.columns)

        for val in lineSplit:
          if not val.isNilOrWhitespace():
            self.values[index] = parseFloat(val.strip)
            index += 1

    # set the North, East, South, and West coodinates
    if xllcorner.classify != fcNegInf:
      self.east = xllcorner + float64(self.columns)*self.resolutionX
      self.west = xllcorner
      self.south = yllcorner
      self.north = yllcorner + float64(self.rows)*self.resolutionY
    else:
      self.east = xllcenter - (0.5 * self.resolutionX) + float64(self.columns)*self.resolutionX
      self.west = xllcenter - (0.5 * self.resolutionX)
      self.south = yllcenter - (0.5 * self.resolutionY)
      self.north = yllcenter - (0.5 * self.resolutionY) + float64(self.rows)*self.resolutionY

    # initialize the other unused raster parameters
    self.palette = "default"
    self.paletteNonlinearity = 1'f64
    self.projection = "not specified"
    self.zUnits = "not specified"
    self.xyUnits = "not specified"
    self.byteOrder = Endianness.littleEndian

    # the data will be unique to the new raster
    self.minimum = Inf
    self.maximum = NegInf
    self.displayMinimum = Inf
    self.displayMaximum = NegInf

  except:
    echo "Got exception ", repr(getCurrentException()), " with message ", getCurrentExceptionMsg()

proc writeArcAscii(self: var Raster) =
  try:
    # Save the file
    let o = open(self.filename, fmWrite)
    defer: o.close

    o.writeLine("NCOLS $1".format(self.columns))
    o.writeLine("NROWS $1".format(self.rows))
    o.writeLine("XLLCORNER $1".format(self.west))
    o.writeLine("YLLCORNER $1".format(self.south))
    o.writeLine("CELLSIZE $1".format((self.resolutionX + self.resolutionY) / 2'f64))
    o.writeLine("NODATA_VALUE $1".format(self.nodata))

    # write the data
    let numCells = self.rows * self.columns
    var col = 0
    var s = ""
    for i in 0..numCells-1:
      if col < self.columns - 1:
        s.add("$1 ".format(self.values[i].formatFloat(ffDecimal, 2)))
      else:
        s.add("$1".format(self.values[i].formatFloat(ffDecimal, 2)))

      col += 1
      if col == self.columns:
        o.writeLine(s)
        s = ""
        col = 0

  except:
    echo "Got exception ", repr(getCurrentException()), " with message ", getCurrentExceptionMsg()

proc read*(self: var Raster) =
  if self.filename.toLowerAscii.endsWith(".dep") or self.filename.toLowerAscii.endsWith(".tas"):
    self.readWhiteboxRaster()
  elif self.filename.toLowerAscii.endsWith(".asc") or self.filename.toLowerAscii.endsWith(".txt"):
    self.readArcAscii()
  else:
    raise newException(FileIOError, "Unrecognized raster file type")

proc write*(self: var Raster) =
  if self.filename.toLowerAscii.endsWith(".dep") or self.filename.toLowerAscii.endsWith(".tas"):
    self.writeWhiteboxRaster()
  elif self.filename.toLowerAscii.endsWith(".asc") or self.filename.toLowerAscii.endsWith(".txt"):
    self.writeArcAscii()
  else:
    raise newException(FileIOError, "Unrecognized raster file type")


proc newRasterFromFile*(filename: string): Raster =
  # make sure it is a supported file format
  if filename.toLowerAscii().endsWith(".dep") or filename.toLowerAscii().endsWith(".tas"):
    result.filename = filename
  elif filename.toLowerAscii().endsWith(".asc"):
    result.filename = filename
  else:
    raise newException(FileIOError, "Unrecognized file extension")

  result.read()

proc createFromOther*(filename: string,
                    other: Raster,
                    dataType = DataType.none,
                    nodata=NegInf,
                    copyData=false): Raster =

  # make sure it is a supported file format
  if filename.toLowerAscii().endsWith(".dep") or filename.toLowerAscii().endsWith(".tas"):
    result.filename = filename
  elif fileName.toLowerAscii().endsWith(".asc"):
    result.filename = filename
  else:
    raise newException(FileIOError, "Unrecognized file extension")

  # copy parameters unrelated to the data and metadata
  result.north = other.north
  result.south = other.south
  result.east = other.east
  result.west = other.west
  result.rows = other.rows
  result.columns = other.columns
  result.resolutionX = other.resolutionX
  result.resolutionY = other.resolutionY
  result.stacks = other.stacks
  if nodata.classify == fcNegInf:
      result.nodata = other.nodata
  else:
      result.nodata = nodata
  result.dataScale = other.dataScale
  if dataType == DataType.none:
      result.dataType = other.dataType
  else:
      result.dataType = dataType
  result.palette = other.palette
  result.paletteNonlinearity = other.paletteNonlinearity
  result.projection = other.projection
  result.zUnits = other.zUnits
  result.xyUnits = other.xyUnits
  result.byteOrder = other.byteOrder

  # the data will be unique to the new raster
  result.minimum = Inf
  result.maximum = NegInf
  result.displayMinimum = Inf
  result.displayMaximum = NegInf

  if not copyData:
    result.values = repeat(result.nodata, result.rows * result.columns)
  else:
    result.values = other.values

  # the metadata will also be unique
  result.metadata = newSeq[string]()

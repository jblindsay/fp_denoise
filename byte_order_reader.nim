#[
Author: Dr. John Lindsay
Created: January 18, 2018
Last Modified: January 18, 2018
License: MIT

Notes: This module provides convience procs for reading multi-byte values from a byte buffer
taking byte endianness into account.
]#


import system, endians, unittest

type
  ByteOrderReader* = object
    data: seq[uint8]
    endian: Endianness
    pos: int

proc newByteOrderReader*(data: seq[uint8], endian: Endianness, pos = 0): ByteOrderReader =
  result = ByteOrderReader(data: data, endian: endian, pos: pos)

proc `pos=`*(b: var ByteOrderReader, value: int) {.inline.} = b.pos = value

proc pos*(b: var ByteOrderReader): int {.inline.} = return b.pos

proc `endian=`*(b: var ByteOrderReader, value: Endianness) {.inline.} = b.endian = value

proc endian*(b: var ByteOrderReader): Endianness {.inline.} = return b.endian

proc `data=`*(b: var ByteOrderReader, value: seq[uint8]) =
  b.data = value
  b.pos = 0

proc readUint8*(b: var ByteOrderReader): uint8 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  result = b.data[b.pos]
  b.pos += 1

proc readUint16*(b: var ByteOrderReader): uint16 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian16(addr result, addr b.data[b.pos])
  else:
    bigEndian16(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)


proc readUint32*(b: var ByteOrderReader): uint32 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian32(addr result, addr b.data[b.pos])
  else:
    bigEndian32(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)

proc readUint64*(b: var ByteOrderReader): uint64 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian64(addr result, addr b.data[b.pos])
  else:
    bigEndian64(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)

proc readInt8*(b: var ByteOrderReader): int8 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  result = cast[int8](b.data[b.pos])
  b.pos += 1

proc readInt16*(b: var ByteOrderReader): int16 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian16(addr result, addr b.data[b.pos])
  else:
    bigEndian16(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)


proc readInt32*(b: var ByteOrderReader): int32 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian32(addr result, addr b.data[b.pos])
  else:
    bigEndian32(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)

proc readInt64*(b: var ByteOrderReader): int64 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian64(addr result, addr b.data[b.pos])
  else:
    bigEndian64(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)

proc readFloat32*(b: var ByteOrderReader): float32 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian32(addr result, addr b.data[b.pos])
  else:
    bigEndian32(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)

proc readFloat64*(b: var ByteOrderReader): float64 {.inline.} =
  if b.pos + sizeOf(result) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Read past data length")

  if b.endian == littleEndian:
    littleEndian64(addr result, addr b.data[b.pos])
  else:
    bigEndian64(addr result, addr b.data[b.pos])

  b.pos += sizeOf(result)

when isMainModule:

  test "indexError":
    let z: seq[uint8] = @[1'u8]
    var b = newByteOrderReader(z, littleEndian)
    expect(IndexError):
      discard b.readUint16
    expect(IndexError):
      discard b.readUint32
    expect(IndexError):
      discard b.readUint64
    expect(IndexError):
      discard b.readInt16
    expect(IndexError):
      discard b.readInt32
    expect(IndexError):
      discard b.readInt64
    expect(IndexError):
      discard b.readFloat32
    expect(IndexError):
      discard b.readFloat64
    expect(IndexError):
      b.pos = -1
      discard b.readInt16

  test "readUint16":
    let z: seq[uint8] = @[1'u8, 0, 0, 2]
    var b = newByteOrderReader(z, littleEndian)
    check(b.readUint16 == 1'u16)
    check(b.readUint16 == 512'u16)
    b.endian = bigEndian
    b.pos = 0
    check(b.readUint16 == 256'u16)
    check(b.readUint16 == 2'u16)

  test "readUint32":
    let z: seq[uint8] = @[1'u8, 0, 0, 0, 0, 2, 0, 0]
    var b = newByteOrderReader(z, littleEndian)
    check(b.readUint32 == 1'u32)
    check(b.readUint32 == 512'u32)
    b.endian = bigEndian
    b.pos = 0
    check(b.readUint32 == 16777216'u32)
    check(b.readUint32 == 131072'u32)

  test "readUint64":
    let z: seq[uint8] = @[1'u8, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0]
    var b = newByteOrderReader(z, littleEndian)
    check(b.readUint64 == 1'u64)
    check(b.readUint64 == 512'u64)
    b.endian = bigEndian
    b.pos = 0
    check(b.readUint64 == 72057594037927936'u64)
    check(b.readUint64 == 562949953421312'u64)

#[
Authors: Dr. John Lindsay
Created: January 18, 2018
Last Modified: January 18, 2018
License: MIT

Notes: This module provides convience procs for writing multi-byte values from a byte buffer
taking byte endianness into account.
]#

import system, endians

###################
# ByteOrderWriter #
###################
type
  ByteOrderWriter* = object
    data*: seq[uint8]
    endian: Endianness
    pos: int

proc newByteOrderWriter*(size: int, endian: Endianness, pos = 0): ByteOrderWriter =
  var d = newSeq[uint8](size)
  result = ByteOrderWriter(data: d, endian: endian, pos: pos)

proc `pos=`*(b: var ByteOrderWriter, value: int) {.inline.} = b.pos = value

proc pos*(b: var ByteOrderWriter): int {.inline.} = return b.pos

proc `endian=`*(b: var ByteOrderWriter, value: Endianness) {.inline.} = b.endian = value

proc endian*(b: var ByteOrderWriter): Endianness {.inline.} = return b.endian

proc writeUint8*(b: var ByteOrderWriter, value: uint8) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  b.data[b.pos] = value
  b.pos += 1

proc writeUint16*(b: var ByteOrderWriter, value: var uint16) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian16(addr b.data[b.pos], addr value)
  else:
    bigEndian16(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

proc writeUint32*(b: var ByteOrderWriter, value: var uint32) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian32(addr b.data[b.pos], addr value)
  else:
    bigEndian32(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

proc writeUint64*(b: var ByteOrderWriter, value: var uint64) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian64(addr b.data[b.pos], addr value)
  else:
    bigEndian64(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

proc writeInt8*(b: var ByteOrderWriter, value: var int8) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  b.data[b.pos] = cast[uint8](value)
  b.pos += 1

proc writeInt16*(b: var ByteOrderWriter, value: var int16) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian16(addr b.data[b.pos], addr value)
  else:
    bigEndian16(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

proc writeInt32*(b: var ByteOrderWriter, value: var int32) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian32(addr b.data[b.pos], addr value)
  else:
    bigEndian32(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

proc writeInt64*(b: var ByteOrderWriter, value: var int64) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian64(addr b.data[b.pos], addr value)
  else:
    bigEndian64(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

proc writeFloat32*(b: var ByteOrderWriter, value: var float32) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian32(addr b.data[b.pos], addr value)
  else:
    bigEndian32(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

proc writeFloat64*(b: var ByteOrderWriter, value: var float64) {.inline.} =
  if b.pos + sizeOf(value) > b.data.len or b.pos < 0:
    raise newException(IndexError, "Write past data length")

  if b.endian == littleEndian:
    littleEndian64(addr b.data[b.pos], addr value)
  else:
    bigEndian64(addr b.data[b.pos], addr value)

  b.pos += sizeOf(value)

#[
Author: Dr. John Lindsay
Created: January 18, 2018
Last Modified: January 18, 2018
License: MIT
]#

import sequtils

type Array2D*[T] = object
  rows*: int
  columns*: int
  nodata*: T
  values: seq[T]

proc `[]=`*[T](self: var Array2D[T], row, column: int, value: T) {.inline.} =
  if row >= 0 and row < self.rows and column >= 0 and column < self.columns:
    let index = row * self.columns + column
    if index >= 0 and index < len(self.values):
        self.values[index] = value

proc `[]`*[T](self: Array2D[T], row, column: int): T {.inline.} =
  if row >= 0 and row < self.rows and column >= 0 and column < self.columns:
    let index = row * self.columns + column
    if index >= 0 and index < len(self.values):
      return self.values[index]

  result = self.nodata

proc newArray2D*[T](rows, columns: int, initialValue, nodata: T): Array2D[T] =
  result.columns = columns
  result.rows = rows
  result.nodata = nodata
  result.values = repeat(initialValue, rows * columns)

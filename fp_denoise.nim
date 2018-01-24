#[
Author: Dr. John Lindsay
Created: January 18, 2018
Last Modified: January 19, 2018
License: MIT
]#

import system, strutils, endians, os, math, ospaths, times
import raster, array_2d

type Normal = object
  a, b, c: float64

proc angleBetween(self, other: Normal): float64 {.inline.} =
  # Note that this is actually not the angle between the vectors but
  # rather the cosine of the angle between the vectors. This improves
  # the performance considerably. Also note that we do not need to worry
  # about checking for division by zero here because 'c' will always be 
  # non-zero and therefore the vector magnitude cannot be zero.
  let denom = ((self.a * self.a + self.b * self.b + self.c * self.c) *
              (other.a * other.a + other.b * other.b + other.c * other.c)).sqrt()
  result = (self.a * other.a + self.b * other.b + self.c * other.c) / denom 
  
when isMainModule:
  var
    workingDir = ""
    inputFile = ""
    outputFile = ""
    hillshadeFile = ""
    createHillshade = false
    threshold = 15'f64
    filterSize = 11
    iterations = 5
    simpleMeanFilter = false

  ######################
  # Read the arguments #
  ######################
  let arguments = commandLineParams()
  if arguments.len > 0:
    var arg: string
    for i in 0..<arguments.len:
      arg = arguments[i].strip.replace("--", "-")
      if not arg.isNilOrWhitespace:
        if arg.toLowerAscii == "-wd":
          workingDir = arguments[i+1]
        elif arg.toLowerAscii.startsWith "-wd=":
          workingDir = arg.split("=")[1]
        elif arg.toLowerAscii == "-i" or arg.toLowerAscii == "-input":
          inputFile = arguments[i+1]
        elif arg.toLowerAscii.startsWith("-i=") or arg.toLowerAscii.startsWith("-input="):
          inputFile = arg.split("=")[1]
        elif arg.toLowerAscii == "-o" or arg.toLowerAscii == "-output":
          outputFile = arguments[i+1]
        elif arg.toLowerAscii.startsWith("-o=") or arg.toLowerAscii.startsWith("-output="):
          outputFile = arg.split("=")[1]
        elif arg.toLowerAscii == "-threshold":
          threshold = parseFloat(arguments[i+1].strip)
        elif arg.toLowerAscii.startsWith "-threshold=":
          threshold = parseFloat(arg.split("=")[1].strip)
        elif arg.toLowerAscii == "-filter":
          filterSize = parseInt(arguments[i+1].strip)
        elif arg.toLowerAscii.startsWith "-filter=":
          filterSize = parseInt(arg.split("=")[1].strip)
        elif arg.toLowerAscii == "-iterations":
          iterations = parseInt(arguments[i+1].strip)
        elif arg.toLowerAscii.startsWith "-iterations=":
          iterations = parseInt(arg.split("=")[1].strip)
        elif arg.toLowerAscii == "-hillshade":
          hillshadeFile = arguments[i+1].strip
          createHillshade = true
        elif arg.toLowerAscii.startsWith "-hillshade=":
          hillshadeFile = arg.split("=")[1].strip
          createHillshade = true
        elif arg.toLowerAscii == "-m":
          simpleMeanFilter = true
        elif arg.toLowerAscii.contains("-h"):
          echo """
fp_denoise:
This tool performs feature-preserving de-noising on a raster digital elevation model (DEM).

Usage:
--wd          Working directory; appended to input/output file names
-i, --input   Input DEM file name
-o, --output  Output DEM file name
--threshold   Threshold value in degrees (1.0 - 85.0)
--filter      Filter size for normal smoothing (odd value >3)
--iterations  Number of iterations used for elevation updating
--hillshade   Optional output hillshade image file name
-m            If this flag is present, a simple mean filter is used
-h            Help
          """
          quit(QuitSuccess)

  else:
    # No arguments have been supplied, so ask the user for input.
    # That is, proceed as an interactive command line program.
    stdout.write("Working directory: ")
    workingDir = readLine(stdin)

    stdout.write("Input DEM file (with extension): ")
    inputFile = readLine(stdin)

    stdout.write("Output DEM file (with extension): ")
    outputFile = readLine(stdin)

    stdout.write("Output hillshade file (with extension): ")
    hillshadeFile = readLine(stdin)

    stdout.write("Angular Threshold (1.0 - 85.0): ")
    threshold = parseFloat(readLine(stdin))

    stdout.write("Filter Size: ")
    filterSize = parseInt(readLine(stdin))

    stdout.write("Num. Iterations (1 - 50): ")
    iterations = parseInt(readLine(stdin))


  let t0 = cpuTime()

  # Make sure that the input and output file names are fully qualified
  # and perform quality assurance on the input variables.
  if not workingDir.endsWith(DirSep):
    workingDir.add(DirSep)

  if not inputFile.contains(DirSep):
    inputFile = workingDir & inputFile

  if not (inputFile.endsWith(".dep") or inputFile.endsWith(".asc")):
    inputFile.add(".dep")

  if not outputFile.contains(DirSep):
    outputFile = workingDir & outputFile

  if not (outputFile.endsWith(".dep") or outputFile.endsWith(".asc")):
    outputFile.add(".dep")

  if not hillshadeFile.contains(DirSep):
    hillshadeFile = workingDir & hillshadeFile

  if not (hillshadeFile.endsWith(".dep") or hillshadeFile.endsWith(".asc")):
    hillshadeFile.add(".dep")

  if filterSize mod 2 == 0:
    filterSize += 1
    echo "Warning: Filter size ($1) has been modified because it must be odd.".format(filterSize)

  if threshold < 1'f64:
    threshold = 1'f64

  if threshold > 85'f64:
    threshold = 85'f64

  # Convert the threshold to radians and get the cosine
  threshold = threshold.degToRad.cos

  if iterations < 1:
    iterations = 1
    echo "Warning: Iterations must be between 1 and 50."

  if iterations > 50:
    iterations = 50
    echo "Warning: Iterations must be between 1 and 50."


  # Read the input files
  echo("Reading DEM data...")
  let dem = newRasterFromFile(inputFile)

  var output = createFromOther(outputFile, dem, copyData=true)

  let t1 = cpuTime()

  ##########################
  # Declare some variables #
  ##########################
  let
    # dx and dy are used as offsets for 3x3 neighbourhood scans
    dx = [1, 1, 1, 0, -1, -1, -1, 0]
    dy = [-1, 0, 1, 1, 1, 0, -1, -1]
    eightGridRes = dem.resolutionX * 8'f64
    # x and y are used in the estimates of elevation during the update process
    x = [-dem.resolutionX, -dem.resolutionX, -dem.resolutionX, 0'f64, dem.resolutionX, dem.resolutionX, dem.resolutionX, 0'f64]
    y = [-dem.resolutionY, 0'f64, dem.resolutionY, dem.resolutionY, dem.resolutionY, 0'f64, -dem.resolutionY, -dem.resolutionY]
    # midPoint is used to create the smoothing convolution kernel
    midPoint = int(float(filterSize) / 2.0)
    # intercellBreakSlope = degToRad(60'f64)
    # maxZDiffEW = intercellBreakSlope.tan() * dem.resolutionX
    # maxZDiffNS = intercellBreakSlope.tan() * dem.resolutionY
    # maxZDiffDiag = intercellBreakSlope.tan() * (dem.resolutionX*dem.resolutionX + dem.resolutionY*dem.resolutionY).sqrt()
    # maxZDiff = [ maxZDiffNS, maxZDiffDiag, maxZDiffEW, maxZDiffDiag, maxZDiffNS, maxZDiffDiag, maxZDiffEW, maxZDiffDiag, maxZDiffNS ]

  var
    values: array[0..7, float64]
    z: float64
    xn: int
    yn: int
    zn: float64
    a, b, c: float64
    progress: int
    oldProgress: int = 1
    dx2 = newSeq[int]()
    dy2 = newSeq[int]()
    numNeighbours = filterSize * filterSize
    sumW: float64
    w: float64
    diff: float64
    zeroVector = Normal(a: 0'f64, b: 0'f64, c: 0'f64)
    nv: Array2D[Normal] = newArray2D(dem.rows, dem.columns, zeroVector, zeroVector) # normal vectors
    nvSmooth: Array2D[Normal] = newArray2D(dem.rows, dem.columns, zeroVector, zeroVector)

  # Note that this is used to figure out the column (dx2) and
  # row (dy2) offsets for the filter that is used for smoothing,
  # relative to the convolution filter's mid-point cell.
  for r in 0..<filterSize:
    for c in 0..<filterSize:
      dx2.add(c - mid_point)
      dy2.add(r - mid_point)


  ################################
  # Calculate the normal vectors #
  ################################
  echo "Calculating normal vectors..."
  for row in 0..<dem.rows:
    for col in 0..<dem.columns:
      z = dem[row, col]
      if z != dem.nodata:
        for n in 0..7:
          zn = dem[row + dy[n], col + dx[n]]
          if zn != dem.nodata:
            # if (zn - z).abs() > maxZDiff[n]:
            #     # This indicates a very steep inter-cell slope.
            #     # Don't use this neighbouring cell value to
            #     # calculate the vector.
            #     zn = z
            values[n] = zn
          else:
            values[n] = z

        a = -(values[2] - values[4] + 2'f64 * (values[1] - values[5]) + values[0] - values[6])
        b = -(values[6] - values[4] + 2'f64 * (values[7] - values[3]) + values[0] - values[2])
        nv[row, col] = Normal(a: a, b: b, c: eightGridRes)
        
    progress = int(100'f32 * float32(row)/float32(dem.rows - 1))
    if progress != oldProgress:
      stdout.write("\rProgress: $1%".format(progress))
      stdout.flushFile()
      oldProgress = progress
      
  if not simpleMeanFilter:
    # The following version of normal vector smoothing and elevation updates
    # uses Sun's original weighting scheme of (ni . nj - threshold)^2

    ##################################
    # smooth the normal vector field #
    ##################################
    echo ""
    echo "Smoothing the normal vectors..."
    for row in 0..<dem.rows:
      for col in 0..<dem.columns:
        z = dem[row, col]
        if z != dem.nodata:
          sumW = 0'f64
          a = 0'f64
          b = 0'f64
          c = 0'f64
          for n in 0..<numNeighbours:
            xn = col + dx2[n]
            yn = row + dy2[n]
            if dem[yn, xn] != dem.nodata:
              diff = nv[row, col].angleBetween(nv[yn, xn])
              if diff > threshold:
                w = (diff - threshold)*(diff - threshold)
                sumW += w
                a += nv[yn, xn].a * w
                b += nv[yn, xn].b * w
                c += nv[yn, xn].c * w

          a /= sumW
          b /= sumW
          c /= sumW
          nvSmooth[row, col] = Normal(a: a, b: b, c: c)

      progress = int(100'f32 * float32(row)/float32(dem.rows - 1))
      if progress != oldProgress:
        stdout.write("\rProgress: $1%".format(progress))
        stdout.flushFile()
        oldProgress = progress

    echo ""

    #########################################################################
    # Update the elevations of the DEM based on the smoothed normal vectors #
    #########################################################################
    echo "Updating elevations..."
    for i in 1..iterations:
      echo "Iteration $1 of $2...".format(i, iterations)

      for row in 0..<dem.rows:
        for col in 0..<dem.columns:
          z = output[row, col]
          if z != output.nodata:
            sumW = 0'f64
            z = 0'f64
            for n in 0..7:
              xn = col + dx[n]
              yn = row + dy[n]
              zn = output[yn, xn]
              if zn != output.nodata:
                diff = nvSmooth[row, col].angleBetween(nvSmooth[yn, xn])
                if diff > threshold:
                  w = (diff - threshold)*(diff - threshold)
                  sumW += w
                  z += -(nvSmooth[yn, xn].a * x[n] + nvSmooth[yn, xn].b * y[n] - nvSmooth[yn, xn].c * zn) / nvSmooth[yn, xn].c * w
                  
            if sumW > 0'f64: # this is a division-by-zero safeguard and must be in place.
              output[row, col] = z / sumW

  else:
    # The following version of normal vector smoothing and elevation updates
    # uses a simple mean filter for all neighbours with differences in normal
    # vectors less than the threshold. This is more efficient than the Sun
    # normal smoothing scheme and provides a smoother surface.

    ##################################
    # smooth the normal vector field #
    ##################################
    echo ""
    echo "Smoothing the normal vectors..."
    for row in 0..<dem.rows:
      for col in 0..<dem.columns:
        z = dem[row, col]
        if z != dem.nodata:
          sumW = 0'f64
          a = 0'f64
          b = 0'f64
          c = 0'f64
          for n in 0..<numNeighbours:
            xn = col + dx2[n]
            yn = row + dy2[n]
            if dem[yn, xn] != dem.nodata:
              diff = nv[row, col].angleBetween(nv[yn, xn])
              if diff > threshold:
                sumW += 1'f64
                a += nv[yn, xn].a
                b += nv[yn, xn].b
                c += nv[yn, xn].c

          a /= sumW
          b /= sumW
          c /= sumW
          nvSmooth[row, col] = Normal(a: a, b: b, c: c)

      progress = int(100'f32 * float32(row)/float32(dem.rows - 1))
      if progress != oldProgress:
        stdout.write("\rProgress: $1%".format(progress))
        stdout.flushFile()
        oldProgress = progress

    echo ""

    #########################################################################
    # Update the elevations of the DEM based on the smoothed normal vectors #
    #########################################################################
    echo "Updating elevations..."

    for i in 1..iterations:
      echo "Iteration $1 of $2...".format(i, iterations)

      for row in 0..<dem.rows:
        for col in 0..<dem.columns:
          z = output[row, col]
          if z != output.nodata:
            sumW = 0'f64
            z = 0'f64
            for n in 0..7:
              xn = col + dx[n]
              yn = row + dy[n]
              zn = output[yn, xn]
              if zn != output.nodata:
                diff = nvSmooth[row, col].angleBetween(nvSmooth[yn, xn])
                if diff > threshold:
                  sumW += 1'f64
                  z += -(nvSmooth[yn, xn].a * x[n] + nvSmooth[yn, xn].b * y[n] - nvSmooth[yn, xn].c * zn) / nvSmooth[yn, xn].c
                  
            if sumW > 0'f64: # this is a division-by-zero safeguard and must be in place.
              output[row, col] = z / sumW


  let t2 = cpuTime()

  ####################
  # Save the new DEM #
  ####################
  echo("Saving data...")
  output.metadata.add("Created by the fp_denoise tool")
  output.metadata.add("Filter Size: $1".format(filterSize))
  output.metadata.add("Threshold: $1".format(threshold))
  output.metadata.add("Iterations: $1".format(iterations))
  output.write()

  let t3 = cpuTime()
  echo "Elapsed times (without i/o): ", (t2 - t1).formatFloat(ffDecimal, 2), "s"
  echo "Elapsed times (with i/o): ", (t3 - t0).formatFloat(ffDecimal, 2), "s"

  if createHillshade:
    ################################################
    # Output the a hillshade (shaded relief) image #
    ################################################
    var
      hillshadeRaster = createFromOther(hillshadeFile, dem)
      aspect, tanSlope, hillshade: float64
      fx, fy: float64
      term1: float64
      term2: float64
      term3: float64

    let
      azimuth = (315'f64 - 90'f64).degToRad()
      altitude = 30'f64.degToRad()
      sinTheta = altitude.sin()
      cosTheta = altitude.cos()

    echo "Creating a hillshade image..."
    for row in 0..<dem.rows:
      for col in 0..<dem.columns:
        z = output[row, col]
        if z != dem.nodata:
          for n in 0..7:
            xn = col + dx[n]
            yn = row + dy[n]
            zn = output[yn, xn]
            if zn != dem.nodata:
              values[n] = zn
            else:
              values[n] = z

          a = -(values[2] - values[4] + 2'f64 * (values[1] - values[5]) + values[0] - values[6])
          b = -(values[6] - values[4] + 2'f64 * (values[7] - values[3]) + values[0] - values[2])
          fx = -a / eightGridRes
          fy = -b / eightGridRes
          if fx != 0'f64:
            tanSlope = (fx * fx + fy * fy).sqrt()
            aspect = (180'f64 - ((fy / fx).arctan()).radToDeg() + 90'f64 * (fx / (fx).abs())).degToRad()
            term1 = tanSlope / (1'f64 + tanSlope * tanSlope).sqrt()
            term2 = sinTheta / tanSlope
            term3 = cosTheta * (azimuth - aspect).sin()
            hillshade = term1 * (term2 - term3)
          else:
            hillshade = 0.5'f64

          if hillshade < 0'f64:
            hillshade = 0'f64

          hillshadeRaster[row, col] = hillshade * 255'f64

      progress = int(100'f32 * float32(row)/float32(dem.rows - 1))
      if progress != oldProgress:
        stdout.write("\rProgress: $1%".format(progress))
        stdout.flushFile()
        oldProgress = progress

    hillshadeRaster.palette = "grey.pal"
    hillshadeRaster.metadata.add("Created by the fp_denoise tool")
    hillshadeRaster.metadata.add("Filter Size: $1".format(filterSize))
    hillshadeRaster.metadata.add("Threshold: $1".format(threshold))
    hillshadeRaster.metadata.add("Iterations: $1".format(iterations))
    hillshadeRaster.write()

    echo ""

  # All done!
  echo "Done"

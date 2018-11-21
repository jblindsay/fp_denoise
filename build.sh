DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "$DIR" != pwd ]; then
  cd $DIR
fi

nim c -d:release fp_denoise.nim

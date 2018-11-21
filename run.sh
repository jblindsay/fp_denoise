#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "$DIR" != pwd ]; then
  cd $DIR
fi

./fp_denoise \
--wd="/Users/johnlindsay/Documents/data/JayStateForest/" \
-i="JayStateForest_filtered_NN_filtered_filled.dep" \
-o="tmp1.dep" \
--threshold=15.0 \
--filter=11
--shaded_relief="tmp2.dep"

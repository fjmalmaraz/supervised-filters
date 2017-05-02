#!/bin/bash

# This file is part of ESAI-CEU-UCH/supervised-filters (https://github.com/ESAI-CEU-UCH/supervised-filters)
#
# Copyright (c) 2017, ESAI, Universidad CEU Cardenal Herrera,
# (F. Zamora-Martínez, F. Muñoz-Almaraz, P. Botella-Rocamora, J. Pardo)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#  
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#  
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

. settings.sh
. scripts/configure.sh

cleanup()
{
    echo "CLEANING UP, PLEASE WAIT UNTIL FINISH"
    cd $ROOT_PATH
    for dest in "$@"; do
	for i in $(ls -t $dest | head -n 16); do
            rm -f $dest/$i
	done
    done
}

##################
## FFT FEATURES ##
##################

echo "Computing FFT features"
# Computes FFT features. Additionally it writes sequence numbers to
# SEQUENCES_PATH.
if ! $APRIL_EXEC scripts/PREPROCESS/compute_fft.lua $DATA_PATH $PBF_PATH $SEQUENCES_PATH; then
    sleep 2
    echo "ERROR: Unable to compute FFT features"
    echo "CLEANING UP, PLEASE WAIT UNTIL FINISH"
    rm -Rf $PBF_PATH $SEQUENCES_PATH
    exit 10
fi

sort -u $SEQUENCES_PATH > $SEQUENCES_PATH.bak
mv -f $SEQUENCES_PATH.bak $SEQUENCES_PATH

###########################
## DS OVER FFT FEATURES ##
###########################

echo "Computing log compressed fft "

if ! $APRIL_EXEC scripts/PREPROCESS/compute_fft_60s_30s_compress.lua $DATA_PATH $FFT_COMPRESS_PATH $SEQUENCES_PATH; then
    sleep 2
    echo "ERROR: Unable to compute FFT _COMPRESS features"
    echo "CLEANING UP, PLEASE WAIT UNTIL FINISH"
    rm -Rf $FFT_COMPRESS_PATH $SEQUENCES_PATH
    exit 10
fi

echo "Computing DS filter"
mkdir -p $DS_PATH
if ! Rscript scripts/PREPROCESS/filter_DS.R; then
    echo "ERROR: Unable to compute DS filter "
    cleanup $DS_PATH
    exit 10
fi


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


KNN_PBF_CONF=scripts/MODELS/confs/knn-pbf.lua
KNN_DS_CONF=scripts/MODELS/confs/knn-ds.lua

TRAIN_ALL_SCRIPT=scripts/MODELS/train_all_subjects_wrapper.lua
KNN_TRAIN_SCRIPT=scripts/MODELS/train_one_subject_knn.lua

###############################################################################

cleanup()
{
    echo "Has been produced an error :("
    echo "CLEANING UP, PLEASE WAIT UNTIL FINISH: $@"
    cd $ROOT_PATH
    for dest in "$@"; do
        rm -Rf $dest
    done
}

# control-c execution
control_c()
{
    echo -en "\n*** Exiting by control-c ***\n"
    cleanup $1
    exit 10
}

train()
{
    SCRIPT=$1
    CONF=$2
    RESULT=$3
    ARGS=$4
    # trap keyboard interrupt (control-c)
    trap "control_c $RESULT" SIGINT
    #
    mkdir -p $RESULT
    echo clip,preictal > $RESULT/test.txt
    echo "Training with script= $SCRIPT   conf= $CONF   result= $RESULT   args= \"$ARGS\""
    echo "IT CAN TAKE SEVERAL HOURS, PLEASE WAIT"
    if [[ $VERBOSE_TRAIN == 0 ]]; then
	$APRIL_EXEC $TRAIN_ALL_SCRIPT $SCRIPT -f $CONF $ARGS \
            --test=$RESULT/test.txt \
            --prefix=$RESULT > $RESULT/train.out
	err=$?
    else
	$APRIL_EXEC $TRAIN_ALL_SCRIPT $KNN_TRAIN_SCRIPT -f $CONF $ARGS \
            --test=$RESULT/test.txt \
            --prefix=$RESULT | tee $RESULT/train.out
	err=$?
    fi
    # removes keyboard interrupt trap (control-c)
    trap - SIGINT
    return $err    
}

train_knn_PBF()
{
    train $KNN_TRAIN_SCRIPT $1 $2 "--fft=$PBF_PATH"
    return $?
}

train_knn_DS()
{
    train $KNN_TRAIN_SCRIPT $1 $2 "--fft=$DS_PATH"
    return $?
}

###############################################################################

if ! ./preprocess.sh; then
    exit 10
fi


##################
## KNN PBF     ##
##################

mkdir -p $KNN_PBF_RESULT
if ! train_knn_PBF $KNN_PBF_CONF $KNN_PBF_RESULT; then
    cleanup $KNN_PBF_RESULT
    exit 10
fi


##################
## KNN DS     ##
##################

mkdir -p $KNN_DS_RESULT
if ! train_knn_DS $KNN_DS_CONF $KNN_DS_RESULT; then
    cleanup $KNN_DS_RESULT
    exit 10
fi

$APRIL_EXEC ./scripts/measureAUC.lua $KNN_PBF_RESULT/test.txt
$APRIL_EXEC ./scripts/measureAUC.lua $KNN_DS_RESULT/test.txt
$APRIL_EXEC ./scripts/measureAUC.lua $KNN_PBF_RESULT/test.txt $KNN_DS_RESULT/test.txt

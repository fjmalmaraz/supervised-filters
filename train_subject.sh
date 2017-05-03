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

if [[ $# != 1 ]]; then
    echo "The script receives one argument with the SUBJECT name"
    exit 10
fi

KNN_PBF_CONF=scripts/MODELS/confs/knn-pbf.lua
KNN_DS_CONF=scripts/MODELS/confs/knn-ds.lua

TRAIN_ALL_SCRIPT=scripts/MODELS/train_all_subjects_wrapper.lua
KNN_TRAIN_SCRIPT=scripts/MODELS/train_one_subject_knn.lua

###############################################################################

. settings.sh
mkdir -p $TMP_PATH
. scripts/configure.sh

# overwrite SUBJECTS variable to contain only one subject
export SUBJECTS=$1
SUBJECT=$1

if [[ ! -d $DATA_PATH/$SUBJECT ]]; then
    echo "Unable to locate $DATA_PATH/$SUBJECT subject folder"
    exit 10
fi

if ! ./preprocess.sh; then
    exit 10
fi

###############################################################################

cleanup()
{
    echo "CLEANING UP, PLEASE WAIT UNTIL FINISH"
    cd $ROOT_PATH
    for dest in "$@"; do
        rm -f $dest/${SUBJECT}*
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
            --test=$RESULT/test.$SUBJECT.txt \
            --prefix=$RESULT > $RESULT/train.$SUBJECT.out
	err=$?
    else
	$APRIL_EXEC $TRAIN_ALL_SCRIPT $KNN_TRAIN_SCRIPT -f $CONF $ARGS \
	    --fft=$PBF_PATH  \
            --test=$RESULT/test.$SUBJECT.txt \
            --prefix=$RESULT | tee $RESULT/train.$SUBJECT.out
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

echo "The test results for this subject are located at:"
echo "  - $BMC_ENSEMBLE_RESULT/test.$SUBJECT.txt"

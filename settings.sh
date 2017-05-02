# Source data path (it can be a relative or absolute path)
#export DATA_PATH=DATA
export DATA_PATH=/home/experimentos/CORPORA/KAGGLE/EPILEPSY_PREDICTION/
# Intermediate results path
export TMP_PATH=TMP
# Models training path
export MODELS_PATH=MODELS
# Submissions results path
export SUBMISSIONS_PATH=SUBMISSIONS
# Indicate which mask use to distinguish test data from holdout data
export TEST_MASK="*test*"
# Indicate if compiling with MKL or not
export USE_MKL=1
# Change this if you want verbose output during training
export VERBOSE_TRAIN=0
# The following parameters are fore intermediate results
if [[ -z $SUBJECTS ]]; then
    export SUBJECTS=$(find $DATA_PATH/ -mindepth 1 -maxdepth 1 -type d -exec basename {} ";" | sort | tr '\n' ' ')
fi
export ROOT_PATH=$(pwd)
export LISTS_PATH=$TMP_PATH/lists
export SEQUENCES_PATH=$TMP_PATH/SEQUENCES.txt
export PBF_PATH=$TMP_PATH/FFT_60s_30s_BFPLOS
export DS_PATH=$TMP_PATH/FFT_60s_30s_DS
export FFT_COMPRESS_PATH=$TMP_PATH/FFT_60s_30s_COMPRESS
# Models temporary results

export KNN_PBF_RESULT=$MODELS_PATH/KNN_PBF_RESULT
export KNN_DS_RESULT=$MODELS_PATH/KNN_DS_RESULT

# Number of threads available, change it in the way you need (only
# useful if you have MKL installed, or specific ATLAS library)
export OMP_NUM_THREADS=4
# check data paths
if [[ ! -d $DATA_PATH ]]; then
    echo "The indicated data path $DATA_PATH is not a folder"
    exit 10
fi
if [[ ! -e $TMP_PATH ]]; then
    mkdir -p $TMP_PATH
elif [[ ! -d $TMP_PATH ]]; then
    echo "The indicated tmp path $TMP_PATH is not a folder"
    exit 10
fi
if [[ ! -d $MODELS_PATH ]]; then
    echo "The indicated tmp path $MODELS_PATH is not a folder"
    exit 10
fi
if [[ ! -d $SUBMISSIONS_PATH ]]; then
    echo "The indicated submissions path $SUBMISSIONS_PATH is not a folder"
    exit 10
fi
if [[ -z $SUBJECTS ]]; then
    echo "The indicated data path doesn't contain any subject subfolder"
    exit 10
fi

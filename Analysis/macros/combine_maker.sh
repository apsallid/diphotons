#!/bin/bash

## version=full_analysis_anv1_v19
version=$1 && shift

fitname=2D 
#www=~/www/exo/spring15_7415
## www=~/www/exo/moriond16
www=~/www/exo/spring17
if [[ $(whoami) == "mquittna" ]]; then
    www=/afs/cern.ch/user/m/mquittna/www/diphoton/Phys14/
fi

shapes="default_shapes"
default_model=""

opts=""
input_opts=""
data_version=""
prepare=""
while [[ -n $1 ]]; do
    case $1 in
	--fit-name)
	    fitname=$2
	    shift
	    ;;
	--www)
	    www=$2
	    shift
	    ;;
	--verbose)
	    verbose="--verbose"
	    opts="$opts --verbose"
	    ;;
	--prepare-*)
	    prepare="$prepare $1"
	    ;;
	--redo-input)
	    rerun="1"
	    ;;
	--label)
	    addlabel=$2
	    shift
	    ;;
	--use-templates)
	    templates="semiparam"
	    opts="$opts $1"
	    ;;
        --mix-templates)
            mix="--mix-templates"
            ;;
	--bkg-shapes)
	    shapes=$(echo $(basename $2 | sed 's%.json%%'))
	    opts="$opts $1 $2"
	    shift
	    ;;
	--default-model)
	    default_model=$2
	    opts="$opts $1 $2"
	    shift
	    ;;
	--use-templates)
	    templates="use_templates"
	    opts="$opts $1"
	    ;;
	--mix-templates)
	    mix="--mix-templates"
	    ;;
	--nuisance-fractions-covariance)
	    covariance=$(echo $(basename $2 | sed 's%.json%%'))
	    opts="$opts $1"
	    ;;
	--generate-ws-bkgnbias)
	    spurious="bias";
	    opts="$opts $1"
	    ;;
	--fwhm-input-file)
	    fwhm="$2"
	    opts="$opts $1"
	    ;;
	--only-coup*)
	    log_label="${log_label}$(echo $2 | tr ',' '_')"
	    opts="$opts $1 $2"
	    shift
	    ;;
	--lumi*)
	    lumi=$2
	    shift
	    ;;
	--data-file)
	    input_opts="$input_opts $1 $2"
	    data_version="$(basename $(dirname $2))"
	    shift
	    ;;
	--*-file)
	    input_opts="$input_opts $1 $2"
	    shift
	    ;;
	--fit-background)
	    just_fit_bkg="1"
	    ;;
	--load)
	    load_also="$load_also $1 $2"
	    opts="$opts $1 $2"
	    echo $load_also
	    shift
	    ;;
	*)
	    opts="$opts $1"
	    ;;	    
    esac
    shift
done
shift

echo $version $lumi

if [[ -z $version ]] || [[ -z $lumi ]]; then
    echo "usage: $0 <analysis_version> --lumi <lumi> [run_options]"
    exit 0
fi

input_folder=$version

[[ -n $data_version ]] && version=$data_version

label="$shapes"
[[ -n $default_model ]] && label="${label}_${default_model}"
[[ -n $covariance ]] && label="${label}_${covariance}"
[[ -n $templates ]] && label="${label}_${templates}"
[[ -n $bias ]] && label="${label}_${bias}"
[[ -n $templates ]] && label="${label}_${templates}"
[[ -n $addlabel ]] && label="${label}_${addlabel}"

input=${version}_${fitname}_final_ws.root
input_log=${version}_${fitname}_final_ws.log
#treesdir=~musella/public/workspace/exo/
treesdir=./
## ls $treesdir/$version
ls $treesdir/$input_folder
[[ ! -d $treesdir/$input_folder ]] && treesdir=$PWD
workdir=${version}_${fitname}_${label}_lumi_${lumi}

if [[ -n $bias ]]; then
    if [[ -z $fwhm ]]; then
	opts="--compute-fwhm"
    fi
fi

mkdir $workdir

mkdir $www/$version

# set -x
if [[ -n $rerun  ]] || [[ ! -f $input ]]; then
    echo "**************************************************************************************************************************"
    echo "creating $input"
    echo "**************************************************************************************************************************"
    subset=$fitname
    if [[ "$fitname" == "2D" ]]; then
        subset="2D,singlePho"
        mix="--mix-templates"
    fi
    set -x
    ./templates_maker.py --load templates_maker.json,templates_maker_prepare.json $load_also --only-subset $subset $mix --input-dir $treesdir/$input_folder $prepare -o $input $verbose $input_opts 2>&1 | tee $input_log
    set +x
    echo "**************************************************************************************************************************"
elif [[ -n $mix ]]; then
    echo "**************************************************************************************************************************"
    echo "running event mixing"
    echo "**************************************************************************************************************************"    
    set -x
    ./templates_maker.py --load templates_maker_prepare.json $load_also --read-ws $input $mix $verbose 2>&1 | tee mix_$input_log
    set +x
    echo "**************************************************************************************************************************"
fi
	    

echo "**************************************************************************************************************************"
echo "running model creation"
echo "**************************************************************************************************************************"

if [[ -z $just_fit_bkg ]]; then
    ##--binned-data-in-datacard \
    set -x
    ./combine_maker.py \
	--fit-name $fitname  --luminosity $lumi  --lumi $lumi \
	--fit-background \
	--generate-signal \
	--generate-datacard \
	--read-ws $input \
	--ws-dir $workdir \
	-O $www/$version/$workdir \
	-o $workdir.root  \
	--cardname datacard_${workdir}.txt $opts 2>&1 | tee $workdir/combine_maker${log_label}.log
    set +x
else
    set -x
    ./combine_maker.py \
	--fit-name $fitname  --luminosity $lumi  --lumi $lumi \
	--fit-background \
	--read-ws $input \
	--ws-dir $workdir \
	-O $www/$version/$workdir \
	-o $workdir.root  \
	$opts 2>&1 | tee $workdir/combine_maker_bkg_only${log_label}.log
    set +x
fi

echo "**************************************************************************************************************************"

#!/usr/bin/env bash


# FunSec - Fungal Secreted Proteins (or Secretome) Predictor Pipeline.
# Copyright (C) 2016 João Baptista <baptista.joao33@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


# To do list:

# - Python fasta parser
# - The grep that displays the final output can tell the empty files that aren't removed in the Final directory 
# - Read from stdin


set -euo pipefail

# Variables initialization

SCRIPT_DIR="$(dirname "$0")"
export SCRIPT_DIR
export INPUT_DIR=""
export INPUT_FILE=""
export FILE_NAME=""
export OUTPUT=""
export SIGNALP_METHOD="best"	# default value
export SIGNALP_CUTOFF_TM=0.5	# default value
export SIGNALP_CUTOFF_NOTM=0.45	# default value
export SIGNALP_CUT=70	# default value
export SIGNALP_MINIMAL=10	# default value
export THRESHOLD_WOLFPSORT=17	# default value
export PARALLEL_JOBS=0
FLAG_INPUT_DIR=0
FLAG_INPUT_FILE=0
FLAG_OUTPUT=0
FLAG_PARALLEL=0

# Setup and configure the signalp and tmhmm files

if [ -f "$SCRIPT_DIR"/bin/signalp-4.1/signalp ]
then
	sed -i "13s|.*|    \$ENV{SIGNALP} = '$SCRIPT_DIR/bin/signalp-4.1';|" "$SCRIPT_DIR"/bin/signalp-4.1/signalp 
	sed -i "20s|.*|my \$MAX_ALLOWED_ENTRIES=100000;|" "$SCRIPT_DIR"/bin/signalp-4.1/signalp
else
	echo -e "Could not find the file signalp of the program SignalP 4.1. Exiting..."
	exit 1
fi

if [ -f "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm ] && [ -f "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmmformat.pl ]
then
	sed -i "1s|.*|#!$(which perl)|" "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm
	sed -i "1s|.*|#!$(which perl)|" "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmmformat.pl
else
	echo -e "Could not find the files tmhmm and tmhmmformat.pl of the program TMHMM 2.0. Exiting..."
	exit 1
fi

# First parse the options h and v, even if they are the last options in the command line.

for i in "$@"
do
	case $i in
			-h)
				echo -e "Usage:

	./FunSec.sh -[OPTION] [ARGUMENT]

Example:

	./FunSec.sh -f input.fa -o output_dir 

General Options:

	-d DIR,		Input directory (for multiple files).
	-f FILE,	Input file.
	-o OUTPUT,	Output directory.
	-p N,		Runs the script in parallel with N jobs. The number of jobs is the same as the number of CPU cores. Using \"0\" will run as many jobs in parallel as possible. When in doubt use \"-p 100%\". GNU Parallel must be installed.

WolfPsort 0.2 Options:

	-w N,		Threshold value for WolfPsort 0.2. N must be a integer in the range 1-30. The default value is \"17\".

SignalP 4.1 Options:

	-c N,		N-terminal truncation of input sequences. The value of \"0\" disables truncation. The default is 70 residues.
	-m N,		Minimal predicted signal peptide length. The default is 10 residues.
	-x N,		D-cutoff value for SignalP-TM networks. N must be in the range 0-1. To reproduce SignalP 3.0's sensitivity use \"0.34\". The default is \"0.5\".
	-y N,		D-cutoff value for SignalP-noTM networks. N must be in the range 0-1. To reproduce SignalP 3.0's sensitivity use \"0.34\". The default is \"0.45\".
	-n,		The SignalP-noTM neural networks are chosen.

Miscellaneous:

	-h,		Displays this message.
	-v,		Displays version.

The options -d or -f and -o and their respective arguments are mandatory, the rest of the options are optional. For more information read the README.md file.

Please cite this script as well as all the programs that are used in this script, including GNU Parallel if the option -p was used. Thank you!"
				exit 0
			;;
			-v)
				echo -e "Version: 3.0
Last Updated: 17-07-17."
				exit 0 
			;;
	esac
done

# Parse the rest of the options

while getopts ":d:f:o:w:p:vhc:m:nx:y:" OPT
do
	case "$OPT" in
		d)
			INPUT_DIR="$OPTARG"
			if [ -d "$INPUT_DIR" ]	
			then
				if [ ! "$(ls -A "$INPUT_DIR")" ]	# if the directory is empty or not
				then
					echo -e "\n$INPUT_DIR is empty. Use -h for more information."
					exit 1
				fi
			elif [ ! -e "$INPUT_DIR" ]
			then
				echo -e "\n$INPUT_DIR does not exist. Use -h for more information."
				exit 1
			else
				echo -e "\n$INPUT_DIR is not a directory. Use -h for more information."
				exit 1
			fi
			FLAG_INPUT_DIR=1
			;;
		f)
			INPUT_FILE="$OPTARG"
			if [ -f "$INPUT_FILE" ]	
			then
				if [ ! -s "$INPUT_FILE" ]	
				then
					echo -e "\n$INPUT_FILE is empty. Use -h for more information."
					exit 1
				else
					FILE_NAME="$(basename "$INPUT_FILE")"
				fi
			elif [ ! -e "$INPUT_FILE" ]
			then
				echo -e "\n$INPUT_FILE does not exist. Use -h for more information."
				exit 1
			else
				echo -e "\n$INPUT_FILE is not a file. Use -h for more information."
				exit 1
			fi
			FLAG_INPUT_FILE=1
			;;
		o)
			OUTPUT="$OPTARG"
			if [ ! -d "$OUTPUT" ]	
			then
				echo -e "\n$OUTPUT is not a directory. Use -h for more information."
				exit 1
			elif [ ! -e "$OUTPUT" ]	
			then
				mkdir -p "$OUTPUT"/FunSec_Output
			fi
			FLAG_OUTPUT=1
			;;
		p)
			PARALLEL_JOBS="$OPTARG"
			if [ -z "$(command -v parallel)" ]	# if parallel is installed return true, else return false
			then  
				echo -e "\nParallel is not installed. Use -h for more information."
				exit 1
			fi
			FLAG_PARALLEL=1
			;;
		w)
			THRESHOLD_WOLFPSORT="$OPTARG"
			if [[ $THRESHOLD_WOLFPSORT =~ ^-?[0-9]+$ ]]
			then
				if [ "$THRESHOLD_WOLFPSORT" -lt 1 ]  || [ "$THRESHOLD_WOLFPSORT" -gt 30 ] 
				then
					echo -e "\nThe threshold number for WolfPsort 0.2 must be a integer in the range 1-30. Use -h for more information."
					exit 1
				fi
			else
				echo -e "\nThe threshold number for WolfPsort 0.2 must be a integer. Use -h for more information."
				exit 1
			fi
			;;
		c)
			SIGNALP_CUT="$OPTARG"
			if [[ $SIGNALP_CUT =~ ^-?[0-9]+$ ]]
			then
				if [ "$SIGNALP_CUT" -lt 0 ] 
				then
					echo -e "\nThe minimal predicted signal peptide length must be greater than or equal to \"0\". Use -h for more information."
					exit 1
				fi
			else
				echo -e "\nThe minimal predicted signal peptide length must be a integer. Use -h for more information."
				exit 1
			fi
			;;
		m)
			SIGNALP_MINIMAL="$OPTARG"
			if [[ $SIGNALP_MINIMAL =~ ^-?[0-9]+$ ]]
			then
				if [ "$SIGNALP_MINIMAL" -lt 0 ]
				then
					echo -e "\nThe value to truncate each sequence must be greater than or equal to \"0\". Use -h for more information."
					exit 1
				fi
			else
				echo -e "\nThe value to truncate each sequence must be a integer. Use -h for more information."
				exit 1
			fi
			;;
		x)
			SIGNALP_CUTOFF_TM="$OPTARG"
			if [[ ! "$SIGNALP_CUTOFF_TM" =~ ^0\.[0-9]+$ ]] && [[ ! "$SIGNALP_CUTOFF_TM" =~ ^0$ ]] && [[ ! "$SIGNALP_CUTOFF_TM" =~ ^1$ ]] 
			then
				echo -e "\nThe D-cutoff value for SignalP-TM networks must be in the range 0-1. Use -h for more information."
				exit 1
			fi
			;;
		y)
			SIGNALP_CUTOFF_NOTM="$OPTARG"
			if [[ ! "$SIGNALP_CUTOFF_NOTM" =~ ^0\.[0-9]+$ ]] && [[ ! "$SIGNALP_CUTOFF_NOTM" =~ ^0$ ]] && [[ ! "$SIGNALP_CUTOFF_NOTM" =~ ^1$ ]] 
			then
				echo -e "\nThe D-cutoff value for SignalP-noTM networks must be in the range 0-1. Use -h for more information."
				exit 1
			fi
			;;
		n)
			SIGNALP_METHOD="notm"
			;;
		v)
			continue
			;;
		h)
			continue
			;;
		\?)
			echo -e "\nInvalid option: -$OPTARG. Use -h for more information."
			exit 1
			;;
		:)
			echo -e "\nThe option -$OPTARG needs an argument. Use -h for more information."
			exit 1
			;;
	esac
done

# if $OUTPUT/FunSec_Output exists it will ask for permission to overwrite.

overwrite() {
	if [ -d "$OUTPUT"/FunSec_Output ]
	then
		echo -ne "\n$OUTPUT/FunSec_Output already exists, this will overwrite it. Do you want to continue? [Y/n]  "
		read -r FLAG_OVERWRITE
		if [ "$FLAG_OVERWRITE" == "yes" ] || [ "$FLAG_OVERWRITE" == "y" ] || [ "$FLAG_OVERWRITE" == "Yes" ] || [ "$FLAG_OVERWRITE" == "Y" ]
		then
			echo -e "\nOverwriting $OUTPUT/FunSec_Output ..."
			rm -rf "$OUTPUT"/FunSec_Output && \
			mkdir "$OUTPUT"/FunSec_Output
		else
			echo -e "\nExiting..."
			exit 0
		fi
	else
		mkdir "$OUTPUT"/FunSec_Output
	fi
}

# Exits if both -f and -d were given

if [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_INPUT_FILE" -eq 1 ] 
then
	echo -e "\nSelect either -f or -d. Use -h for more information."
	exit 1
fi

# Runs the functions to check the -d or -f, -o and -p options and runs the corresponding script. 

if [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ] && [ "$FLAG_PARALLEL" -eq 1 ] # if the -d, -o and -p options were given
then
	overwrite && \
	echo -e "\nThe program $0 is running in parallel, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/Dir_parallel.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
elif  [ "$FLAG_INPUT_FILE" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ]  && [ "$FLAG_PARALLEL" -eq 1 ] # if the -f, -o and -p options were given
then
	overwrite && \
	echo -e  "\nThe program $0 is running in parallel, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/File_parallel.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
elif [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ]  && [ "$FLAG_PARALLEL" -eq 0 ] # if the -d and -o options were given
then
	overwrite && \
	echo -e "\nThe program $0 is running, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/Dir.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log 
	exit 0
elif  [ "$FLAG_INPUT_FILE" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ]  && [ "$FLAG_PARALLEL" -eq 0 ] # if the -f and -o options were given
then
	overwrite && \
	echo -e  "\nThe program $0 is running, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/File.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
else
	echo -e "\nThe options -d or -f and -o and their respective arguments must be specified. Use -h for more information."
	exit 1
fi


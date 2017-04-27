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
# - SignalP options
# - The grep that displays the final output can tell the empty files that aren't removed in the Final directory 
# - parallelize retriving the seqs


set -euo pipefail

# Variables initialization

SCRIPT_DIR="$(dirname "$0")"
export SCRIPT_DIR
export INPUT_DIR=""
export INPUT_FILE=""
export FILE_NAME=""
export OUTPUT=""
export THRESHOLD_WOLFPSORT=0
FLAG_INPUT_DIR=0
FLAG_INPUT_FILE=0
FLAG_OUTPUT=0
FLAG_WOLFPSORT=0
FLAG_PARALLEL=0
FLAG_HELP=0
FLAG_VERSION=0

# Setup

if [ -f "$SCRIPT_DIR"/bin/signalp-4.1/signalp ]
then
	sed -i "13s|.*|    \$ENV{SIGNALP} = '$SCRIPT_DIR/bin/signalp-4.1';|" "$SCRIPT_DIR"/bin/signalp-4.1/signalp 
	sed -i "20s|.*|my \$MAX_ALLOWED_ENTRIES=100000;|" "$SCRIPT_DIR"/bin/signalp-4.1/signalp
else
	echo -e "Could not find the file signalp. Existing..."
	exit 1
fi

if [ -f "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm ] && [ -f "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmmformat.pl ]
then
	sed -i "1s|.*|#!$(which perl)|" "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm
	sed -i "1s|.*|#!$(which perl)|" "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmmformat.pl
else
	echo -e "Could not find the files tmhmm and tmhmmformat.pl. Existing..."
	exit 1
fi

# Command options and arguments parser

while getopts ":d:f:o:w:pvh" OPT
do
	case "$OPT" in
		d)
			INPUT_DIR="$OPTARG"
			FLAG_INPUT_DIR=1
			;;
		f)
			INPUT_FILE="$OPTARG"
			FLAG_INPUT_FILE=1
			;;
		o)
			OUTPUT="$OPTARG"
			FLAG_OUTPUT=1
			;;
		w)
			THRESHOLD_WOLFPSORT="$OPTARG"
			FLAG_WOLFPSORT=1
			;;
		p)
			FLAG_PARALLEL=1
			;;
		h)
			FLAG_HELP=1
			;;
		v)
			FLAG_VERSION=1
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

# Version

version() {
	echo -e "Version: 2.1
Last Updated: 27-04-17."
}

# Help 

help_text() {
	echo -e "Usage:

        ./FunSec.sh -[OPTION] [ARGUMENT]

Options:

		-d,		Input directory (for multiple files).
		-f,		Input file.
		-o,		Output directory.
		-h,		Displays this message.
		-w,		Threshold number for the program WolfPsort 0.2. Must be in the range 1-30, the default value is 17.
		-p,		Runs the script in parallel, which makes it faster. GNU Parallel must be installed.
		-v,		Displays version.

        The options -d or -f and -o and their respective arguments must be specified. For more information read the README.md file.

Please cite this script as well as all the programs that are used in this script including GNU Parallel, if the option -p was used. Thank you!"
}

# Function to check the input directory

input_dir_check() {
	if [ -d "$INPUT_DIR" ]	# if input is a directory
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
}

# Function to check the input file

input_file_check() {
	if [ -f "$INPUT_FILE" ]	# if input is a file
	then
		if [ ! -s "$INPUT_FILE" ]	# if the file is empty or not
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
}

# Function to check the output directory

output_check() {
	if [ -d "$OUTPUT" ]	# if output is a directory
	then
		if [ -d "$OUTPUT"/FunSec_Output ]	# if $OUTPUT/FunSec_Output exists it will ask for permission to overwrite.
		then
			echo -ne "\n$OUTPUT/FunSec_Output already exists, this will overwrite it. Do you want to continue? [Y/n]  "
			read -r FLAG_OVERWRITE
			if [ "$FLAG_OVERWRITE" == "yes" ] || [ "$FLAG_OVERWRITE" == "y" ] || [ "$FLAG_OVERWRITE" == "Yes" ] || [ "$FLAG_OVERWRITE" == "Y" ]
			then
				echo -e "\nOverwriting $OUTPUT/FunSec_Output ..."
				rm -rf "$OUTPUT"/FunSec_Output && \
				mkdir "$OUTPUT"/FunSec_Output
			else
				echo -e "\nExisting..."
				exit 0
			fi
		else
			mkdir "$OUTPUT"/FunSec_Output
		fi
	elif [ ! -e "$OUTPUT" ]	# if $OUTPUT doesn't exist then create the directory
	then
		mkdir -p "$OUTPUT"/FunSec_Output
	else
		echo -e "\n$OUTPUT is not a directory. Use -h for more information."
		exit 1
	fi
}

# Function to check the threshold number

threshold_wolfpsort_check() {
	if [ "$THRESHOLD_WOLFPSORT" -gt 0 ] 2> /dev/null && [ "$THRESHOLD_WOLFPSORT" -lt 31 ]	# if threshold is > than 0 and < 31 
	then
		echo -e "\nThe threshold number for WolfPsort is set to $THRESHOLD_WOLFPSORT."
	else
		echo -e "\nThe threshold number for WolfPsort must be in the range 1-30. Use -h for more information."
		exit 1
	fi
}

# Function to check if parallel is installed

parallel_check() {
	if [ -z "$(command -v parallel)" ]	# if parallel is installed return true, else return false
	then  
		echo -e "\nParallel is not installed. Use -h for more information."
		exit 1
	fi
}

# Runs the help function

if [ "$FLAG_HELP" -eq 1 ] # if the -h option was given
then
	help_text
	exit 0
fi

# Runs version function 

if [ "$FLAG_VERSION" -eq 1 ] # if the -v option was given
then
	version
	exit 0
fi

# Runs the function to check and set the threshold number

if [ "$FLAG_WOLFPSORT" -eq 1 ] # if the -w option was given
then
	threshold_wolfpsort_check
else
	THRESHOLD_WOLFPSORT=17
fi

# Runs the functions to check the -d or -f, -o and -p options and runs the corresponding script. 

if [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ] && [ "$FLAG_PARALLEL" -eq 1 ] # if the -d, -o and -p options were given
then
	parallel_check && \
	input_dir_check && \
	output_check && \
	echo -e "\nThe program $0 is running in parallel, it may take a while. I encourage you to go outside or to pet some animal."
	bash "$SCRIPT_DIR"/bin/FunSec/Dir_parallel.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
elif  [ "$FLAG_INPUT_FILE" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ]  && [ "$FLAG_PARALLEL" -eq 1 ] # if the -f, -o and -p options were given
then
	parallel_check && \
	input_file_check && \
	output_check && \
	echo -e  "\nThe program $0 is running in parallel, it may take a while. I encourage you to go outside or to pet some animal."
	bash "$SCRIPT_DIR"/bin/FunSec/File_parallel.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
elif [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ]  && [ "$FLAG_PARALLEL" -eq 0 ] # if the -d and -o options were given
then
	input_dir_check && \
	output_check && \
	echo -e "\nThe program $0 is running, it may take a while. I encourage you to go outside or to pet some animal."
	bash "$SCRIPT_DIR"/bin/FunSec/Dir.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log 
	exit 0
elif  [ "$FLAG_INPUT_FILE" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ]  && [ "$FLAG_PARALLEL" -eq 0 ] # if the -f and -o options were given
then
	input_file_check && \
	output_check && \
	echo -e  "\nThe program $0 is running, it may take a while. I encourage you to go outside or to pet some animal."
	bash "$SCRIPT_DIR"/bin/FunSec/File.sh | tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
else
	echo -e "\nThe options -d or -f and -o and their respective arguments must be specified. Use -h for more information."
	exit 1
fi


#!/usr/bin/env bash


# FunSec - Fungal Secreted Proteins (or Secretome) Prediction Pipeline.
# Copyright (C) 2019 João Baptista <baptista.joao33@gmail.com>
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

# - parse parallel arg 
# - The grep that displays the final output can tell the empty files that aren't removed in the Final directory 
# - if targetp has too many inputs, it crushs

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
export WOLFPSORT_THRESHOLD=17	# default value
export TARGETP_MTP_CUTOFF=0 #default value
export TARGETP_SP_CUTOFF=0 #default value
export TARGETP_OTHER_CUTOFF=0 #default value
export PARALLEL_JOBS=0 
FLAG_INPUT_DIR=0
FLAG_INPUT_FILE=0
FLAG_OUTPUT=0
FLAG_PARALLEL=0

# Setup and configure the signalp and tmhmm files

if [ -f "$SCRIPT_DIR"/bin/signalp-4.1/signalp ]; then
	sed -i "13s|.*|    \$ENV{SIGNALP} = '$SCRIPT_DIR/bin/signalp-4.1';|" "$SCRIPT_DIR"/bin/signalp-4.1/signalp 
	sed -i "20s|.*|my \$MAX_ALLOWED_ENTRIES=500000;|" "$SCRIPT_DIR"/bin/signalp-4.1/signalp
else
	echo -e "Could not find the file signalp of the program SignalP 4.1. Exiting..."
	exit 1
fi

if [ -f "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm ] && [ -f "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmmformat.pl ]; then
	sed -i "1s|.*|#!$(command -v perl)|" "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm
	sed -i "1s|.*|#!$(command -v perl)|" "$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmmformat.pl
else
	echo -e "Could not find the files tmhmm and/or tmhmmformat.pl of the program TMHMM 2.0. Exiting..."
	exit 1
fi

if [ -f "$SCRIPT_DIR"/bin/targetp-1.1/targetp ]; then
	if [ "$(echo -n "$SCRIPT_DIR/bin/targetp-1.1" | wc -c)" -lt 59 ]; then
		true
		# sed -i "23s|.*|$SCRIPT_DIR/bin/targetp-1.1 |" "$SCRIPT_DIR"/bin/targetp-1.1/targetp 
	else
		echo -e "The TargetP path is too long. Exiting..."
		exit 1
	fi
	sed -i "23s|.*|TARGETP=/home/baptista/Documents/targetp-1.1 |" "$SCRIPT_DIR"/bin/targetp-1.1/targetp 
	sed -i "26s|.*|TMP=/var/tmp|" "$SCRIPT_DIR"/bin/targetp-1.1/targetp
	sed -i "29s|.*|PASTE=$(command -v paste)|" "$SCRIPT_DIR"/bin/targetp-1.1/targetp
	sed -i "33s|.*|PERL=$(command -v perl)|" "$SCRIPT_DIR"/bin/targetp-1.1/targetp
	sed -i "43s|.*|	then AWK=$(command -v gawk)|" "$SCRIPT_DIR"/bin/targetp-1.1/targetp
	sed -i "48s|.*|SH=$(command -v sh)|" "$SCRIPT_DIR"/bin/targetp-1.1/targetp
	sed -i "58s|.*|	then ECHO='echo -e'|" "$SCRIPT_DIR"/bin/targetp-1.1/targetp
else
	echo -e "Could not find the file targetp of the program TargetP 1.1. Exiting..."
	exit 1
fi

# First parse the options h and v, even if they are the last options in the command line.

for i in "$@"; do
	case $i in
			-h)
				echo -e "Usage:

	./FunSec.sh -[OPTION] [ARGUMENT]

Example:

	./FunSec.sh -f input.fa -o output_dir 

General Options:

	-d DIR,		Input directory (for multiple FASTA files).
	-f FILE,	Input FASTA file.
	-o OUTPUT,	Output directory.
	-p N,		Runs the script in parallel with N jobs. The number of jobs is the same as the number of CPU cores. Using \"0\" will run as many jobs in parallel as possible. When in doubt use \"-p 100%\". GNU Parallel must be installed.

WolfPsort 0.2 Options:

	-w N,		Threshold value for WolfPsort 0.2. N must be an integer in the range 1-30. The default value is \"17\".

SignalP 4.1 Options:

	-c N,		N-terminal truncation of input sequences. The value of \"0\" disables truncation. The default is 70 residues.
	-m N,		Minimal predicted signal peptide length. The default is 10 residues.
	-x N,		D-cutoff value for SignalP-TM networks. N must be in the range 0-1. To reproduce SignalP 3.0's sensitivity use \"0.34\". The default is \"0.5\".
	-y N,		D-cutoff value for SignalP-noTM networks. N must be in the range 0-1. To reproduce SignalP 3.0's sensitivity use \"0.34\". The default is \"0.45\".
	-n,		The SignalP-noTM neural networks are chosen.

TargetP 1.1 Options:

	-e N,		mTP-cutoff value. N must be in the range 0-1. The default is \"0\".
	-s N,		SP-cutoff value. N must be in the range 0-1. The default is \"0\".
	-z N,		other-cutoff value. N must be in the range 0-1. The default is \"0\".

Miscellaneous:

	-h,		Displays this message.
	-v,		Displays version.

The options -d or -f and -o and their respective arguments are mandatory, the rest of the options are optional. For more information read the README.md file.

Please cite this script as well as all the programs that are used in this script, including GNU Parallel if the option -p was used. Thank you!"
				exit 0
			;;
			-v)
				echo -e "Version: 4.0
Last Updated: 17-04-19."
				exit 0 
			;;
	esac
done

# Parse the rest of the options

while getopts ":d:f:o:w:p:vhc:m:nx:y:e:s:z:" OPT; do
	case "$OPT" in
		d)
			INPUT_DIR="$OPTARG"
			if [ -e "$INPUT_DIR" ];	then
				if [ -d "$INPUT_DIR" ];	then
					if [ ! "$(ls -A "$INPUT_DIR")" ]; then	# if the directory is empty or not
						echo -e "\n$INPUT_DIR is empty. Use -h for more information."
						exit 1
					else
						for f in "$INPUT_DIR"/*; do
							if [ -f "$f" ]; then
								if [ ! -s "$f" ]; then
									echo -e "\n$INPUT_DIR/$f is empty. Use -h for more information."
									exit 1
								else 
									if [ "$("$SCRIPT_DIR"/bin/FunSec/Parser.py "$f")" == "ERROR" ]; then
										echo -e "\n$f is not a FASTA file"
										exit 1
									elif [ "$("$SCRIPT_DIR"/bin/FunSec/Parser.py "$f")" == "ERROR1" ]; then
										echo -e "\n$f headers length is longer than 20 characters"
										exit 1
									elif [ "$("$SCRIPT_DIR"/bin/FunSec/Parser.py "$f")" == "ERROR2" ]; then
										echo -e "\n$f headers contain spaces"
										exit 1
									elif [ "$("SCRIPT_DIR"/bin/FunSec/Parser.py "$f")" == "ERROR3" ]; then
										echo -e "\n$f contains illegal characters"
										exit 1
									else
										FLAG_INPUT_DIR=1
									fi
								fi 
							else
								echo -e "\n$INPUT_DIR/$f is not a file. Use -h for more information."
								exit 1
							fi
						done 
					fi
				else
					echo -e "\n$INPUT_DIR is not a directory. Use -h for more information."
					exit 1
				fi
			else
				echo -e "\n$INPUT_DIR does not exist. Use -h for more information."
				exit 1
			fi
			;;
		f)
			INPUT_FILE="$OPTARG"
			if [ -e "$INPUT_FILE" ]; then
				if [ -f "$INPUT_FILE" ]; then
					if [ ! -s "$INPUT_FILE" ]; then
						echo -e "\n$INPUT_FILE is empty. Use -h for more information."
						exit 1
					else
						BASENAME="$(basename "$INPUT_FILE")"
						FILE_NAME="${BASENAME%.*}"
						unset BASENAME
						if [ "$("$SCRIPT_DIR"/bin/FunSec/Parser.py "$INPUT_FILE")" == "ERROR" ]; then
							echo -e "\n$INPUT_FILE is not a FASTA file."
							exit 1
						elif [ "$("$SCRIPT_DIR"/bin/FunSec/Parser.py "$INPUT_FILE")" == "ERROR1" ]; then
							echo -e "\n$INPUT_FILE headers length is longer than 20 characters."
							exit 1
						elif [ "$("$SCRIPT_DIR"/bin/FunSec/Parser.py "$INPUT_FILE")" == "ERROR2" ]; then
							echo -e "\n$INPUT_FILE headers contain spaces."
							exit 1
						elif [ "$("$SCRIPT_DIR"/bin/FunSec/Parser.py "$INPUT_FILE")" == "ERROR3" ]; then
							echo -e "\n$INPUT_FILE contains illegal characters."
							exit 1
						else 
							FLAG_INPUT_FILE=1
						fi
					fi
				else
					echo -e "\n$INPUT_FILE is not a file. Use -h for more information."
					exit 1
				fi
			else
				echo -e "\n$INPUT_FILE does not exist. Use -h for more information."
				exit 1
			fi
			;;
		o)
			OUTPUT="$OPTARG"
			if [ -e "$OUTPUT" ]; then
				if [ ! -d "$OUTPUT" ]; then
					echo -e "\n$OUTPUT is not a directory. Use -h for more information."
					exit 1
				else
					FLAG_OUTPUT=1
				fi
			else
				mkdir -p "$OUTPUT"/FunSec_Output
			fi
			;;
		p)
			PARALLEL_JOBS="$OPTARG"
			if [ -z "$(command -v parallel)" ]; then	# if parallel is installed return true, else return false
				echo -e "\nParallel is not installed. Use -h for more information."
				exit 1
			else
				FLAG_PARALLEL=1
			fi
			;;
		w)
			WOLFPSORT_THRESHOLD="$OPTARG"
			if [[ $WOLFPSORT_THRESHOLD =~ ^-?[0-9]+$ ]]; then
				if [ "$WOLFPSORT_THRESHOLD" -lt 1 ] || [ "$WOLFPSORT_THRESHOLD" -gt 30 ]; then
					echo -e "\nThe threshold value for WolfPsort 0.2 must be in the range 1-30. Use -h for more information."
					exit 1
				fi
			else
				echo -e "\nThe threshold value for WolfPsort 0.2 must be an integer. Use -h for more information."
				exit 1
			fi
			;;
		c)
			SIGNALP_CUT="$OPTARG"
			if [[ $SIGNALP_CUT =~ ^-?[0-9]+$ ]]; then 
				if [ "$SIGNALP_CUT" -lt 0 ]; then
					echo -e "\nThe minimal predicted signal peptide length must be greater than or equal to \"0\". Use -h for more information."
					exit 1
				fi
			else
				echo -e "\nThe minimal predicted signal peptide length must be an integer. Use -h for more information."
				exit 1
			fi
			;;
		m)
			SIGNALP_MINIMAL="$OPTARG"
			if [[ $SIGNALP_MINIMAL =~ ^-?[0-9]+$ ]]; then
				if [ "$SIGNALP_MINIMAL" -lt 0 ]; then
					echo -e "\nThe value to truncate each sequence must be greater than or equal to \"0\". Use -h for more information."
					exit 1
				fi
			else
				echo -e "\nThe value to truncate each sequence must be an integer. Use -h for more information."
				exit 1
			fi
			;;
		x)
			SIGNALP_CUTOFF_TM="$OPTARG"
			if [[ ! "$SIGNALP_CUTOFF_TM" =~ ^0\.[0-9]+$ ]] && [[ ! "$SIGNALP_CUTOFF_TM" =~ ^0$ ]] && [[ ! "$SIGNALP_CUTOFF_TM" =~ ^1$ ]]; then
				echo -e "\nThe D-cutoff value for SignalP-TM networks must be an integer in the range 0-1. Use -h for more information."
				exit 1
			fi
			;;
		y)
			SIGNALP_CUTOFF_NOTM="$OPTARG"
			if [[ ! "$SIGNALP_CUTOFF_NOTM" =~ ^0\.[0-9]+$ ]] && [[ ! "$SIGNALP_CUTOFF_NOTM" =~ ^0$ ]] && [[ ! "$SIGNALP_CUTOFF_NOTM" =~ ^1$ ]]; then
				echo -e "\nThe D-cutoff value for SignalP-noTM networks must be an integer in the range 0-1. Use -h for more information."
				exit 1 
			fi
			;;
		n)
			SIGNALP_METHOD="notm"
			;;
		e)
			TARGETP_MTP_CUTOFF=$OPTARG
			if [[ ! "$TARGETP_MTP_CUTOFF" =~ ^0\.[0-9]+$ ]] && [[ ! "$TARGETP_MTP_CUTOFF" =~ ^0$ ]] && [[ ! "$TARGETP_MTP_CUTOFF" =~ ^1$ ]]; then
				echo -e "\nThe mTP-cutoff value must be an integer in the range 0-1. Use -h for more information."
				exit 1 
			fi
			;;
		s)
			TARGETP_SP_CUTOFF=$OPTARG
			if [[ ! "$TARGETP_SP_CUTOFF" =~ ^0\.[0-9]+$ ]] && [[ ! "$TARGETP_SP_CUTOFF" =~ ^0$ ]] && [[ ! "$TARGETP_SP_CUTOFF" =~ ^1$ ]]; then
				echo -e "\nThe SP-cutoff value must be an integer in the range 0-1. Use -h for more information."
				exit 1 
			fi
			;;
		z)
			TARGETP_OTHER_CUTOFF=$OPTARG
			if [[ ! "$TARGETP_OTHER_CUTOFF" =~ ^0\.[0-9]+$ ]] && [[ ! "$TARGETP_OTHER_CUTOFF" =~ ^0$ ]] && [[ ! "$TARGETP_OTHER_CUTOFF" =~ ^1$ ]]; then
				echo -e "\nThe other-cutoff value must be an integer in the range 0-1. Use -h for more information."
				exit 1 
			fi
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

# Exits if both -f and -d were given

if [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_INPUT_FILE" -eq 1 ]; then
	echo -e "\nSelect either -f or -d. Use -h for more information."
	exit 1
fi

# if $OUTPUT/FunSec_Output exists it will ask for permission to overwrite.

overwrite() {
	if [ -e "$OUTPUT"/FunSec_Output ]; then 
		echo -ne "\n$OUTPUT/FunSec_Output already exists, this will overwrite it. Do you want to continue? [Y/n] "
		read -r FLAG_OVERWRITE
		if [ "$FLAG_OVERWRITE" == "yes" ] || [ "$FLAG_OVERWRITE" == "y" ] || [ "$FLAG_OVERWRITE" == "Yes" ] || [ "$FLAG_OVERWRITE" == "Y" ]; then
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

# Runs the functions to check the -d or -f, -o and -p options and runs the corresponding script. 

if [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ] && [ "$FLAG_PARALLEL" -eq 1 ]; then # if the -d, -o and -p options were given
	overwrite && \
	echo -e "\nThe program $0 is running in parallel, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/Dir_parallel.sh | \
	tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
elif [ "$FLAG_INPUT_FILE" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ] && [ "$FLAG_PARALLEL" -eq 1 ]; then # if the -f, -o and -p options were given
	overwrite && \
	echo -e "\nThe program $0 is running in parallel, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/File_parallel.sh | \
	tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
elif [ "$FLAG_INPUT_DIR" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ] && [ "$FLAG_PARALLEL" -eq 0 ]; then # if the -d and -o options were given
	overwrite && \
	echo -e "\nThe program $0 is running, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/Dir.sh | \
	tee -a "$OUTPUT"/FunSec_Output/FunSec.log 
	exit 0
elif [ "$FLAG_INPUT_FILE" -eq 1 ] && [ "$FLAG_OUTPUT" -eq 1 ] && [ "$FLAG_PARALLEL" -eq 0 ]; then # if the -f and -o options were given
	overwrite && \
	echo -e "\nThe program $0 is running, it may take a while."
	bash "$SCRIPT_DIR"/bin/FunSec/File.sh | \
	tee -a "$OUTPUT"/FunSec_Output/FunSec.log
	exit 0
else
	echo -e "\nThe options -d or -f and -o and their respective arguments must be specified. Use -h for more information."
	exit 1
fi

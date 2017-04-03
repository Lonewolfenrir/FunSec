#!/usr/bin/env bash


#	FunSec - Fungi Secreted Proteins (or Secretome) Predictor Pipeline.
#	Copyright (C) 2016 João Baptista <baptista.joao33@gmail.com>
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.


# To do list:
#
# - Check the bin directory for the correct programs files.
# - Report sequences or no?

set -eo pipefail

# Version

version() {
echo -e "Version: 1.0
Last Updated: 21-02-17"
}

# Help text

help_text() {
echo -e "Usage:

        ./FunSec.sh -[OPTION] [ARGUMENT]

Options:

        -i,		Input directory.
        -o,		Output directory.
        -h,		Displays this message.
        -w,		Threshold number for the program WolfPsort 0.2. Must be in the range of 1-30, the default value is 17.
        -v,		Displays version.

        Both options -i and -o must be specified. For more information read the README.md file."
}

# SignalP 4.1

signalp() {
echo -e "\nRunning SignalP 4.1.\n"
mkdir "$OUTPUT"/FunSec_Output/SignalP
ls "$INPUT"/ | while read -r i
do
	./bin/signalp-4.1/signalp -m "$OUTPUT"/FunSec_Output/SignalP/"$i" "$INPUT"/"$i" 2> /dev/null | \
	awk '{if ($1 != "#") print $1}'
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# TMHMM 2.0c after SignalP 4.1

tmhmm() {
echo -e "\nRunning TMHMM 2.0 with SignalP 4.1 mature sequences.\n"
mkdir "$OUTPUT"/FunSec_Output/TMHMM
ls "$OUTPUT"/FunSec_Output/SignalP/ | while read -r i
do
	./bin/tmhmm-2.0c/bin/tmhmm -short "$OUTPUT"/FunSec_Output/SignalP/"$i" | \
	awk '{if ($5=="PredHel=0") print $1}' | \
	sort | \
	tee "$OUTPUT"/FunSec_Output/TMHMM/"$i"
done
ls ./ | grep "TMHMM"| while read -r i  # Remove directories created by TMHMM
do
	rm -rf "$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# Phobius 1.01

phobius() {
echo -e "\nRunning Phobius 1.01.\n"
mkdir "$OUTPUT"/FunSec_Output/Phobius
ls "$INPUT"/ | while read -r i
do
	./bin/phobius/phobius.pl -short < "$INPUT"/"$i" 2> /dev/null | \
	awk '{if ($2 == "0" && $3 =="Y") print $1}' | \
	sort | \
	tee "$OUTPUT"/FunSec_Output/Phobius/"$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# SignalP 4.1 + TMHMM 2.0c and Phobius 1.01

signalp_tmhmm_phobius() {
echo -e "\nSelecting the common sequences found by SignalP 4.1 + TMHMM 2.0 and Phobius 1.01."
mkdir "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers
ls "$OUTPUT"/FunSec_Output/TMHMM/ | while read -r i  # The path is "$OUTPUT"/FunSec_Output/TMHMM/"$i" because the output of phobius may contain empty files.
do
	comm -12 "$OUTPUT"/FunSec_Output/Phobius/"$i" "$OUTPUT"/FunSec_Output/TMHMM/"$i" > "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers/"$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# SignalP + TMHMM and Phobius Sequences Retriever

signalp_tmhmm_phobius_retriever() {
echo -e "\nRetriving the common sequences of SignalP 4.1 + TMHMM 2.0 and Phobius 1.01."
mkdir "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences
ls "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers | while read -r i
do
	for f in $(cat "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers/"$i")
	do
		awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$INPUT"/"$i" | \
    sed '/^$/d' >> "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences/"$i"
	done
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# WolfPsort 0.2

wolfpsort() {
echo -e "\nRunning WolfPsort 0.2.\n"
mkdir "$OUTPUT"/FunSec_Output/WolfPsort
ls "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences/ | while read -r i
do
	./bin/WoLFPSort-master/bin/runWolfPsortSummary fungi < "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences/"$i" | \
	sed 's/,//g' | \
	awk -v w="$THRESHOLD_WOLFPSORT" 'BEGIN {FS=" "} {if ($2 == "extr" && $3 > w) print $1}' | \
	sort | \
	tee "$OUTPUT"/FunSec_Output/WolfPsort/"$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# ProtComp 9.0

protcomp() {
echo -e "\nRunning ProtComp 9.0.\n"
mkdir "$OUTPUT"/FunSec_Output/ProtComp
ls "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences/ | while read -r i
do
	./bin/lin/pc_fm "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences/"$i" -NODB -NOOL | \
	awk 'BEGIN {RS="Seq name: "} /Integral Prediction of protein location: Membrane bound Extracellular/ || /Integral Prediction of protein location: Extracellular/ {print $1}' | \
	sort | \
	tee "$OUTPUT"/FunSec_Output/ProtComp/"$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# WolfPsort and ProtComp

wolfpsort_protcomp() {
echo -e "\nSelecting the common sequences found by WolfPsort 0.2 and ProtComp 9.0."
mkdir "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers
ls "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences/ | while read -r i
do
	comm -12 "$OUTPUT"/FunSec_Output/WolfPsort/"$i" "$OUTPUT"/FunSec_Output/ProtComp/"$i" > "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/"$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# WolfPsort and ProtComp Sequences Retriever

wolfpsort_protcomp_retriever() {
echo -e "\nRetriving the common sequences of WolfPsort 0.2 and ProtComp 9.0."
mkdir "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Sequences
ls "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/ | while read -r i
do
	for f in $(cat "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/"$i")
	do
		awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Sequences/"$i" | \
		sed '/^$/d' >> "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Sequences/"$i"
	done
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# Ps-scan 1.86

ps_scan() {
echo -e "\nRunning Ps-scan 1.86.\n"
mkdir "$OUTPUT"/FunSec_Output/Ps-scan
ls "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Sequences/ | while read -r i
do
	./bin/ps_scan/ps_scan.pl -p "[KRHQSA]-[DENQ]-E-L>" "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Sequences/"$i" | \
	awk 'BEGIN{RS=">"} {print $1}' | \
	sed '/^$/d' | \
	sort | \
	tee "$OUTPUT"/FunSec_Output/Ps-scan/"$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# Ps-scan Sequences Remover

ps_scan_remover() {
echo -e "\nRemoving the sequences found by Ps-scan 1.86 from the WolfPsort 0.2 and ProtComp 9.0 common sequences."
mkdir "$OUTPUT"/FunSec_Output/Final "$OUTPUT"/FunSec_Output/Final/Headers
ls "$OUTPUT"/FunSec_Output/Ps-scan/ | while read -r i
do
	comm -13 "$OUTPUT"/FunSec_Output/Ps-scan/"$i" "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/"$i" > "$OUTPUT"/FunSec_Output/Final/Headers/"$i"
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# Ps-scan Sequences Retriever

ps_scan_retriever() {
echo -e "\nRetriving final secreted sequences."
mkdir "$OUTPUT"/FunSec_Output/Final/Sequences
ls "$OUTPUT"/FunSec_Output/Final/Headers/ | while read -r i
do
	for f in $(cat "$OUTPUT"/FunSec_Output/Final/Headers/"$i")
	do
		awk -v f="$f" 'BEGIN{RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Sequences/"$i" | \
		sed '/^$/d' >> "$OUTPUT"/FunSec_Output/Final/Sequences/"$i"
	done
done
echo -e "\nFinished. (Runtime - $SECONDS seconds)"
}

# Variables

INPUT=""  # Input directory
OUTPUT="" # Output directory
FLAG_INPUT=0  # If Input is true or false
FLAG_OUTPUT=0	# If Output is true or false
THRESHOLD_WOLFPSORT=17	# Threshold for WolfPsort program

# Command options and arguments parser

while getopts :i:o:w:vh OPT
do
	case $OPT in
		i)
			INPUT=$OPTARG
			if [ -d "$INPUT" ]	# if input is a directory
			then
				if [ "$(ls -A "$INPUT")" ]	# if the directory is empty or not
				then
					FLAG_INPUT=1
				else
					echo -e "\n$INPUT is empty."
					exit 1
				fi
			else
				echo -e "\n$INPUT doesn't exist or it's not a directory."
				exit 1
			fi
			;;
		o)
			OUTPUT=$OPTARG
			if [ -d "$OUTPUT" ]	# if input is a directory
			then
				FLAG_OUTPUT=1
				if [ -d "$OUTPUT"/FunSec_Output ]	# if $OUTPUT/FunSec_Output exists it will ask for permission to overwrite.
				then
					echo -e "\n$OUTPUT/FunSec_Output already exists, this will overwrite it. Do you want to continue? [Y/n]"
					read -r FLAG_OVERWRITE
					if [ "$FLAG_OVERWRITE" == "yes" ] || [ "$FLAG_OVERWRITE" == "y" ] || [ "$FLAG_OVERWRITE" == "Yes" ] || [ "$FLAG_OVERWRITE" == "Y" ]
					then
						echo -e "\nOverwriting $OUTPUT/FunSec_Output."
						rm -rf "$OUTPUT"/FunSec_Output && mkdir "$OUTPUT"/FunSec_Output
					else
						echo -e "\nExisting..."
						exit 0
					fi
				else
					echo -e "\nCreating $OUTPUT/FunSec_Output."
					mkdir "$OUTPUT"/FunSec_Output
				fi
			else
				echo -e "\n$OUTPUT doesn't exist or it's not a directory."
				exit 1
			fi
			;;
		w)
			THRESHOLD_WOLFPSORT=$OPTARG
			if [[ "$THRESHOLD_WOLFPSORT" -gt 0 && "$THRESHOLD_WOLFPSORT" -lt 31 ]]
			then
				echo -e "\nThe threshold number for WolfPsort is set to $THRESHOLD_WOLFPSORT."
			else
				echo -e "\nThe threshold number for WolfPsort must be in the range of 1-30. Use -h for more information."
				exit 1
			fi
			;;
		h)
			help_text
			exit 0
			;;
		v)
			version
			exit 0
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

if [ $FLAG_INPUT == 1 ] && [ $FLAG_OUTPUT == 1 ]
then
	cd "$(dirname "$0")" || exit 1
	echo -e "\nThe program $0 is running, it may take a while. I encourage you to go outside or to pet some animal."
	signalp && tmhmm && phobius && signalp_tmhmm_phobius && signalp_tmhmm_phobius_retriever && wolfpsort && protcomp && wolfpsort_protcomp && wolfpsort_protcomp_retriever && ps_scan && ps_scan_remover && ps_scan_retriever
	exit 0
else
	echo -e "\nBoth options -i and -o must be specified. Use -h for more information."
	exit 1
fi


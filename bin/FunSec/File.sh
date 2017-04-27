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


set -euo pipefail

# Trap

trap 'find "$OUTPUT"/FunSec_Output -empty -delete ; find ./ -maxdepth 1 -type d -name "TMHMM_*" -exec rm -rf {} \; ; find ./ -type d -name "Headers" -exec rm -rf {} +' SIGHUP SIGINT SIGTERM SIGQUIT ERR EXIT

# Citation 

citation() {
	echo -e "\nPlease cite this script as well as all the programs that are used in this script. Thank you!"
}

# SignalP 4.1  

echo -e "\nRunning SignalP 4.1...\n"
mkdir -p "$OUTPUT"/FunSec_Output/SignalP/Log
"$SCRIPT_DIR"/bin/signalp-4.1/signalp -m "$OUTPUT"/FunSec_Output/SignalP/"$FILE_NAME" "$INPUT_FILE" 2> /dev/null | \
tee -a "$OUTPUT"/FunSec_Output/SignalP/Log/SignalP.log | \
awk '{if ($10 == "Y") print $1}' | \
sort
if [ ! -s "$OUTPUT"/FunSec_Output/SignalP/"$FILE_NAME" ]
then 
	echo -e "No proteins were predicted with a signal peptide. Existing..."
	citation 
	exit 1
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# TMHMM 2.0c

echo -e "\nRunning TMHMM 2.0 with SignalP 4.1 mature sequences...\n"
mkdir -p "$OUTPUT"/FunSec_Output/TMHMM/Log
"$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm -short "$OUTPUT"/FunSec_Output/SignalP/"$FILE_NAME" | \
tee -a "$OUTPUT"/FunSec_Output/TMHMM/Log/TMHMM.log | \
awk '{if ($5=="PredHel=0") print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/TMHMM/"$FILE_NAME"
find ./ -maxdepth 1 -type d -name "TMHMM_*" -exec rm -rf {} \;
if [ ! -s "$OUTPUT"/FunSec_Output/TMHMM/"$FILE_NAME" ]
then 
	echo -e "No proteins were predicted without trans-membrane regions. Existing..."
	citation
	exit 1
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# Phobius 1.01

echo -e "\nRunning Phobius 1.01...\n"
mkdir -p "$OUTPUT"/FunSec_Output/Phobius/Log
"$SCRIPT_DIR"/bin/phobius/phobius.pl -short < "$INPUT_FILE" 2> /dev/null | \
tee -a "$OUTPUT"/FunSec_Output/Phobius/Log/Phobius.log | \
awk '{if ($2 == "0" && $3 =="Y") print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/Phobius/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/Phobius/"$FILE_NAME" ]
then 
	echo -e "No proteins were predicted without trans-membrane regions or with signal peptides. Existing..."
	citation 
	exit 1
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# SignalP 4.1 + TMHMM 2.0c and Phobius 1.01

echo -e "\nSelecting the common sequences found by SignalP 4.1 + TMHMM 2.0 and Phobius 1.01...\n"
mkdir -p "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers
comm -12 "$OUTPUT"/FunSec_Output/Phobius/"$FILE_NAME" "$OUTPUT"/FunSec_Output/TMHMM/"$FILE_NAME" | \
tee "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers/"$FILE_NAME" ]
then 
	echo -e "No common proteins were found. Existing..."
	citation
	exit 1
else	
	while read -r f
	do
		awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$INPUT_FILE" | \
		sed '/^$/d' >> "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME" 
	done < "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers/"$FILE_NAME"
	rm -rf "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# WolfPsort 0.2

echo -e "\nRunning WolfPsort 0.2...\n"
mkdir -p "$OUTPUT"/FunSec_Output/WolfPsort/Log
"$SCRIPT_DIR"/bin/WoLFPSort-master/bin/runWolfPsortSummary fungi < "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME" | \
tee -a "$OUTPUT"/FunSec_Output/WolfPsort/Log/WolfPsort.log | \
grep -E -o ".* extr [0-9]{,2}" | \
awk -v w="$THRESHOLD_WOLFPSORT" 'BEGIN {FS=" "} {if ($2 == "extr" && $3 > w) print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/WolfPsort/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/WolfPsort/"$FILE_NAME" ]
then 
	echo -e "No proteins were predicted to be secreted. Existing..."
	citation
	exit 1
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# ProtComp 9.0

echo -e "\nRunning ProtComp 9.0...\n"
mkdir -p "$OUTPUT"/FunSec_Output/ProtComp/Log
"$SCRIPT_DIR"/bin/lin/pc_fm "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME" -NODB -NOOL | \
tee -a "$OUTPUT"/FunSec_Output/ProtComp/Log/ProtComp.log | \
awk 'BEGIN {RS="Seq name: "} /Integral Prediction of protein location: Membrane bound Extracellular/ || /Integral Prediction of protein location: Extracellular/ {print $1}' | \
sed 's/,$//g' | \
sort | \
tee "$OUTPUT"/FunSec_Output/ProtComp/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/ProtComp/"$FILE_NAME" ]
then 
	echo -e "No proteins were predicted to be secreted. Existing..."
	citation
	exit 1
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# WolfPsort and ProtComp

echo -e "\nSelecting the common sequences found by WolfPsort 0.2 and ProtComp 9.0...\n"
mkdir -p "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers
comm -12 "$OUTPUT"/FunSec_Output/WolfPsort/"$FILE_NAME" "$OUTPUT"/FunSec_Output/ProtComp/"$FILE_NAME" | \
tee "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/"$FILE_NAME" ]
then 
	echo -e "No common proteins were found. Existing..."
	citation
	exit 1
else
	while read -r f
	do
		awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME" | \
		sed '/^$/d' >> "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/"$FILE_NAME"
	done < "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/"$FILE_NAME"
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# Ps-scan 1.86

echo -e "\nRunning Ps-scan 1.86...\n"
mkdir -p "$OUTPUT"/FunSec_Output/Ps-scan/Log "$OUTPUT"/FunSec_Output/Final
"$SCRIPT_DIR"/bin/ps_scan/ps_scan.pl -p "[KRHQSA]-[DENQ]-E-L>" "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/"$FILE_NAME" | \
tee -a "$OUTPUT"/FunSec_Output/Ps-scan/Log/Ps-scan.log | \
awk 'BEGIN{RS=">"} {print $1}' | \
sed '/^$/d' | \
sort > "$OUTPUT"/FunSec_Output/Ps-scan/"$FILE_NAME"
if [ ! -s  "$OUTPUT"/FunSec_Output/Ps-scan/"$FILE_NAME" ]
then 
	echo -e "No endoplasmic reticulum targeting motifs found."
	rm -rf "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers
	cp -r "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/* "$OUTPUT"/FunSec_Output/Final/
else
	mkdir "$OUTPUT"/FunSec_Output/Final/Headers 
	comm -13 "$OUTPUT"/FunSec_Output/Ps-scan/"$FILE_NAME" "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers/"$FILE_NAME" > "$OUTPUT"/FunSec_Output/Final/Headers/"$FILE_NAME"
	if [ ! -s "$OUTPUT"/FunSec_Output/Final/Headers/"$FILE_NAME" ]
	then
		echo -e "No proteins were predicted to be secreted. Existing..."
		rm -rf "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers
		citation
		exit 1
	else
		while read -r f	
		do
			awk -v f="$f" 'BEGIN{RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/"$FILE_NAME" | \
			sed '/^$/d' | \
			tee -a "$OUTPUT"/FunSec_Output/Final/"$FILE_NAME" | \
			awk 'BEGIN{RS=">"}END{printf $1"\n"}'
		done < "$OUTPUT"/FunSec_Output/Final/Headers/"$FILE_NAME"
		rm -rf "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp/Headers
		rm -rf "$OUTPUT"/FunSec_Output/Final/Headers
	fi
fi

# Final Message

echo -e "\n$0 has finished (Runtime - $SECONDS seconds). The final secreted proteins can be found in $OUTPUT/FunSec_Output/Final.\n"
grep -H -c "^>" "$OUTPUT"/FunSec_Output/Final/*
citation
exit 0

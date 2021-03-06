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


set -euo pipefail

# Trap

trap 'find "$OUTPUT"/FunSec_Output -empty -delete ; find ./ -maxdepth 1 -type d -name "TMHMM_*" -exec rm -rf {} + ; find "$OUTPUT"/FunSec_Output/SignalP -type f -name "$FILE_NAME".fa -delete 2> /dev/null ; find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius -type f -name "$FILE_NAME" -delete 2> /dev/null ; find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP -type f -name pre_"$FILE_NAME" -delete 2> /dev/null ; find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP -type f -name "$FILE_NAME" -delete 2> /dev/null ; find "$OUTPUT"/FunSec_Output/Final -type f -name "$FILE_NAME" -delete 2> /dev/null' SIGHUP SIGINT SIGTERM SIGQUIT ERR EXIT 

# Citation 

citation() {
	echo -e "\nPlease cite FunSec as well as all the programs that are used in the pipeline. Thank you!"
}

# SignalP 4.1  

echo -e "\nRunning SignalP 4.1...\n"
mkdir "$OUTPUT"/FunSec_Output/SignalP
"$SCRIPT_DIR"/bin/signalp-4.1/signalp -c "$SIGNALP_CUT" -M "$SIGNALP_MINIMAL" -s "$SIGNALP_METHOD" -u "$SIGNALP_CUTOFF_NOTM" -U "$SIGNALP_CUTOFF_TM" -m "$OUTPUT"/FunSec_Output/SignalP/"$FILE_NAME".fa "$INPUT_FILE" 2> /dev/null | \
tee "$OUTPUT"/FunSec_Output/SignalP/SignalP.log | \
awk '{if ($10 == "Y") print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/SignalP/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/SignalP/"$FILE_NAME" ]; then
	echo -e "No proteins were predicted with a signal peptide. Exiting..."
	citation 
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# TMHMM 2.0c

echo -e "\nRunning TMHMM 2.0 with SignalP 4.1 mature sequences...\n"
mkdir "$OUTPUT"/FunSec_Output/TMHMM
"$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm -short "$OUTPUT"/FunSec_Output/SignalP/"$FILE_NAME".fa | \
tee "$OUTPUT"/FunSec_Output/TMHMM/TMHMM.log | \
awk '{if ($5=="PredHel=0") print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/TMHMM/"$FILE_NAME"
find ./ -maxdepth 1 -type d -name "TMHMM_*" -exec rm -rf {} +
find "$OUTPUT"/FunSec_Output/SignalP -type f -name "$FILE_NAME".fa -delete
if [ ! -s "$OUTPUT"/FunSec_Output/TMHMM/"$FILE_NAME" ]; then
	echo -e "No proteins were predicted without trans-membrane regions. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# Phobius 1.01

echo -e "\nRunning Phobius 1.01...\n"
mkdir "$OUTPUT"/FunSec_Output/Phobius
"$SCRIPT_DIR"/bin/phobius/phobius.pl -short < "$INPUT_FILE" 2> /dev/null | \
tee "$OUTPUT"/FunSec_Output/Phobius/Phobius.log | \
awk '{if ($2 == "0" && $3 =="Y") print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/Phobius/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/Phobius/"$FILE_NAME" ]; then
	echo -e "No proteins were predicted without trans-membrane regions or with a signal peptide. Exiting..."
	citation 
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# SignalP 4.1 + TMHMM 2.0c and Phobius 1.01

echo -e "\nSelecting the common sequences found by SignalP 4.1 plus TMHMM 2.0 and Phobius 1.01...\n"
mkdir "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius
comm -12 "$OUTPUT"/FunSec_Output/Phobius/"$FILE_NAME" "$OUTPUT"/FunSec_Output/TMHMM/"$FILE_NAME" | \
tee "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME" ]; then
	echo -e "No common proteins were found. Exiting..."
	citation
	exit 0
else	
	while read -r f; do
		awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$INPUT_FILE" | \
		sed '/^$/d' >> "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME".fa 
	done < "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME"
	find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius -type f -name "$FILE_NAME" -delete
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# WolfPsort 0.2

echo -e "\nRunning WolfPsort 0.2...\n"
mkdir "$OUTPUT"/FunSec_Output/WolfPsort
"$SCRIPT_DIR"/bin/WoLFPSort-master/bin/runWolfPsortSummary fungi < "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME".fa | \
tee "$OUTPUT"/FunSec_Output/WolfPsort/WolfPsort.log | \
grep -E -o ".* extr [0-9]{,2}" | \
awk -v w="$WOLFPSORT_THRESHOLD" 'BEGIN {FS=" "} {if ($2 == "extr" && $3 > w) print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/WolfPsort/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/WolfPsort/"$FILE_NAME" ]; then
	echo -e "No proteins were predicted to be secreted. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# ProtComp 9.0

echo -e "\nRunning ProtComp 9.0...\n"
mkdir "$OUTPUT"/FunSec_Output/ProtComp
"$SCRIPT_DIR"/bin/lin/pc_fm "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME".fa -NODB -NOOL | \
tee "$OUTPUT"/FunSec_Output/ProtComp/ProtComp.log | \
awk 'BEGIN {RS="Seq name: "} /Integral Prediction of protein location: Membrane bound Extracellular/ || /Integral Prediction of protein location: Extracellular/ {print $1}' | \
sed 's/,$//g' | \
sort | \
tee "$OUTPUT"/FunSec_Output/ProtComp/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/ProtComp/"$FILE_NAME" ]; then 
	echo -e "No proteins were predicted to be secreted. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# TargetP 1.1

echo -e "\nRunning TargetP 1.1...\n"
mkdir "$OUTPUT"/FunSec_Output/TargetP
"$SCRIPT_DIR"/bin/targetp-1.1/targetp -N -t "$TARGETP_MTP_CUTOFF" -s "$TARGETP_SP_CUTOFF" -o "$TARGETP_OTHER_CUTOFF" "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME".fa | \
tee "$OUTPUT"/FunSec_Output/TargetP/TargetP.log | \
awk '{if ($6 == "S") print $1}' | \
sort | \
tee "$OUTPUT"/FunSec_Output/TargetP/"$FILE_NAME"
if [ ! -s "$OUTPUT"/FunSec_Output/TargetP/"$FILE_NAME" ]; then
	echo -e "No proteins were predicted to be secreted. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# WolfPsort, ProtComp and TargetP 

echo -e "\nSelecting the common sequences found by WolfPsort 0.2, ProtComp 9.0 and TargetP 1.1...\n"
mkdir "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP
comm -12 "$OUTPUT"/FunSec_Output/WolfPsort/"$FILE_NAME" "$OUTPUT"/FunSec_Output/ProtComp/"$FILE_NAME" > "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/pre_"$FILE_NAME"
comm -12 "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/pre_"$FILE_NAME" "$OUTPUT"/FunSec_Output/TargetP/"$FILE_NAME" | \
tee "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME"
find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP -type f -name pre_"$FILE_NAME" -delete
if [ ! -s "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME" ]; then 
	echo -e "No common proteins were found. Exiting..."
	citation
	exit 0
else
	while read -r f; do
		awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"$FILE_NAME".fa | \
		sed '/^$/d' >> "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME".fa
	done < "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME"
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# Ps-scan 1.86

echo -e "\nRunning Ps-scan 1.86...\n"
mkdir "$OUTPUT"/FunSec_Output/Ps-scan "$OUTPUT"/FunSec_Output/Final
"$SCRIPT_DIR"/bin/ps_scan/ps_scan.pl -p "[KRHQSA]-[DENQ]-E-L>" "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME".fa | \
tee "$OUTPUT"/FunSec_Output/Ps-scan/Ps-scan.log | \
awk 'BEGIN{RS=">"} {print $1}' | \
sed '/^$/d' | \
sort > "$OUTPUT"/FunSec_Output/Ps-scan/"$FILE_NAME"
if [ ! -s  "$OUTPUT"/FunSec_Output/Ps-scan/"$FILE_NAME" ]; then
	echo -e "No endoplasmic reticulum targeting motifs found."
	find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP -type f -name "$FILE_NAME" -delete
	cp "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME".fa "$OUTPUT"/FunSec_Output/Final/
else
	cat "$OUTPUT"/FunSec_Output/Ps-scan/"$FILE_NAME"
	comm -13 "$OUTPUT"/FunSec_Output/Ps-scan/"$FILE_NAME" "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME" > "$OUTPUT"/FunSec_Output/Final/"$FILE_NAME"
	if [ ! -s "$OUTPUT"/FunSec_Output/Final/"$FILE_NAME" ]; then
		echo -e "\nNo proteins were predicted to be secreted. Exiting..."
		citation
		exit 0
	else
		while read -r f; do 
			awk -v f="$f" 'BEGIN{RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"$FILE_NAME".fa | \
			sed '/^$/d' >> "$OUTPUT"/FunSec_Output/Final/"$FILE_NAME".fa
		done < "$OUTPUT"/FunSec_Output/Final/"$FILE_NAME"
		find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP -type f -name "$FILE_NAME" -delete
		find "$OUTPUT"/FunSec_Output/Final -type f -name "$FILE_NAME" -delete
	fi
fi

# Final Message

echo -e "\n$0 has finished (Runtime - $SECONDS seconds). The final secreted proteins can be found in $OUTPUT/FunSec_Output/Final/$FILE_NAME.fa.\n"
grep -H -c "^>" "$OUTPUT"/FunSec_Output/Final/"$FILE_NAME".fa
citation
exit 0

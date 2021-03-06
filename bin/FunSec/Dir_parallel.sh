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

trap 'find "$OUTPUT"/FunSec_Output -empty -delete ; find ./ -maxdepth 1 -type d -name "TMHMM_*" -exec rm -rf {} \; ; find "$OUTPUT"/FunSec_Output -type d -name "Headers" -exec rm -rf {} + ; find "$OUTPUT"/FunSec_Output/SignalP -type f -name "*.fa" -delete 2> /dev/null' SIGHUP SIGINT SIGTERM SIGQUIT ERR EXIT

# Citation 

citation() {
	echo -e "\nPlease cite FunSec as well as all the programs that are used in the pipeline including GNU Parallel. Thank you!"   
}

# SignalP 4.1  

SIGNALP_AWK='{if ($10 == "Y") print $1}'

echo -e "\nRunning SignalP 4.1...\n"
mkdir -p "$OUTPUT"/FunSec_Output/SignalP/Log
find "$INPUT_DIR" -maxdepth 1 -type f -exec basename {} \; | \
	parallel -j "$PARALLEL_JOBS" --noswap --load 80% --no-notice ""$SCRIPT_DIR"/bin/signalp-4.1/signalp -c "$SIGNALP_CUT" -M "$SIGNALP_MINIMAL" -s "$SIGNALP_METHOD" -u "$SIGNALP_CUTOFF_NOTM" -U "$SIGNALP_CUTOFF_TM" -m "$OUTPUT"/FunSec_Output/SignalP/{.}.fa "$INPUT_DIR"/{} 2> /dev/null | tee "$OUTPUT"/FunSec_Output/SignalP/Log/{.}.log | awk '$SIGNALP_AWK' | sort | tee "$OUTPUT"/FunSec_Output/SignalP/{.}"
if [ "$(find "$OUTPUT"/FunSec_Output/SignalP -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/SignalP -maxdepth 1 -type f | wc -l)" ]; then
	echo -e "No proteins were predicted with a signal peptide. Exiting..."
	citation 
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# TMHMM 2.0c

TMHMM_AWK='{if ($5=="PredHel=0") print $1}'

echo -e "\nRunning TMHMM 2.0 with SignalP 4.1 mature sequences...\n"
mkdir -p "$OUTPUT"/FunSec_Output/TMHMM/Log
find "$OUTPUT"/FunSec_Output/SignalP -maxdepth 1 -type f -exec basename {} \; | \
	parallel -j "$PARALLEL_JOBS" --noswap --load 80%  --no-notice ""$SCRIPT_DIR"/bin/tmhmm-2.0c/bin/tmhmm -short "$OUTPUT"/FunSec_Output/SignalP/{.}.fa | tee "$OUTPUT"/FunSec_Output/TMHMM/Log/{.}.log | awk '$TMHMM_AWK' | sort | tee "$OUTPUT"/FunSec_Output/TMHMM/{.}"
find ./ -maxdepth 1 -type d -name "TMHMM_*" -exec rm -rf {} +
find "$OUTPUT"/FunSec_Output/SignalP -type f -name "*.fa" -delete
if [ "$(find "$OUTPUT"/FunSec_Output/TMHMM -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/TMHMM -maxdepth 1 -type f | wc -l)" ]; then
	echo -e "No proteins were predicted without trans-membrane regions. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# Phobius 1.01

PHOBIUS_AWK='{if ($2 == "0" && $3 == "Y") print $1}'

echo -e "\nRunning Phobius 1.01...\n"
mkdir -p "$OUTPUT"/FunSec_Output/Phobius/Log
find "$INPUT_DIR" -maxdepth 1 -type f -exec basename {} \; | \
	parallel -j "$PARALLEL_JOBS" --noswap --load 80% --no-notice ""$SCRIPT_DIR"/bin/phobius/phobius.pl -short < "$INPUT_DIR"/{} 2> /dev/null | tee "$OUTPUT"/FunSec_Output/Phobius/Log/{.}.log | awk '$PHOBIUS_AWK' | sort | tee "$OUTPUT"/FunSec_Output/Phobius/{.}"
if [ "$(find "$OUTPUT"/FunSec_Output/Phobius -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/Phobius -maxdepth 1 -type f | wc -l)" ]; then
	echo -e "No proteins were predicted without trans-membrane regions or with a signal peptide. Exiting..."
	citation 
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# SignalP 4.1 + TMHMM 2.0c and Phobius 1.01

echo -e "\nSelecting the common sequences found by SignalP 4.1 plus TMHMM 2.0 and Phobius 1.01...\n"
mkdir -p "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers
find "$OUTPUT"/FunSec_Output/TMHMM -maxdepth 1 -type f -exec basename {} \; | \
	parallel -j "$PARALLEL_JOBS" --noswap --load 80% --no-notice "comm -12 "$OUTPUT"/FunSec_Output/Phobius/{.} "$OUTPUT"/FunSec_Output/TMHMM/{.} | tee "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers/{.}"
if [ "$(find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers -maxdepth 1 -type f | wc -l)" ]; then 
	echo -e "No common proteins were found. Exiting..."
	citation
	exit 0
else
	find "$INPUT_DIR" -maxdepth 1 -type f -exec basename {} \; | while read -r i; do
		while read -r f; do
			awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$INPUT_DIR"/"$i" | \
			sed '/^$/d' >> "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"${i%.*}".fa 
		done < "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/Headers/"${i%.*}"
	done
	find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius -type d -name Headers -exec rm -rf {} +
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# WolfPsort 0.2

WOLFPSORT_AWK='BEGIN {FS=" "} {if ($2 == "extr" && $3 > w) print $1}'

echo -e "\nRunning WolfPsort 0.2...\n"
mkdir -p "$OUTPUT"/FunSec_Output/WolfPsort/Log
find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius -maxdepth 1 -type f -exec basename {} \; | \
	parallel -j "$PARALLEL_JOBS" --noswap --load 80% --no-notice ""$SCRIPT_DIR"/bin/WoLFPSort-master/bin/runWolfPsortSummary fungi < "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/{.}.fa | tee "$OUTPUT"/FunSec_Output/WolfPsort/Log/{.}.log | grep -E -o '.* extr [0-9]{,2}' | awk -v w="$WOLFPSORT_THRESHOLD" '$WOLFPSORT_AWK' | sort | tee "$OUTPUT"/FunSec_Output/WolfPsort/{.}"
if [ "$(find "$OUTPUT"/FunSec_Output/WolfPsort -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/WolfPsort -maxdepth 1 -type f | wc -l)" ]; then 
	echo -e "No proteins were predicted to be secreted. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# ProtComp 9.0

PROTCOMP_AWK='BEGIN {RS="Seq name: "} /Integral Prediction of protein location: Membrane bound Extracellular/ || /Integral Prediction of protein location: Extracellular/ {print $1}'

echo -e "\nRunning ProtComp 9.0...\n"
mkdir -p "$OUTPUT"/FunSec_Output/ProtComp/Log
find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius -maxdepth 1 -type f -exec basename {} \; | \
	parallel -j "$PARALLEL_JOBS" --noswap --load 80% --no-notice ""$SCRIPT_DIR"/bin/lin/pc_fm "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/{.}.fa -NODB -NOOL | tee "$OUTPUT"/FunSec_Output/ProtComp/Log/{.}.log | awk '$PROTCOMP_AWK' | sed 's/,$//g' | sort | tee "$OUTPUT"/FunSec_Output/ProtComp/{.}"
if [ "$(find "$OUTPUT"/FunSec_Output/ProtComp -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/ProtComp -maxdepth 1 -type f | wc -l)" ]; then
	echo -e "No proteins were predicted to be secreted. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# TargetP 1.1

echo -e "\nRunning TargetP 1.1...\n"
mkdir -p "$OUTPUT"/FunSec_Output/TargetP/Log
find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius -maxdepth 1 -type f -exec basename {} \; | while read -r i; do
	"$SCRIPT_DIR"/bin/targetp-1.1/targetp -N -t "$TARGETP_MTP_CUTOFF" -s "$TARGETP_SP_CUTOFF" -o "$TARGETP_OTHER_CUTOFF" "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"${i%.*}".fa | \
	tee "$OUTPUT"/FunSec_Output/TargetP/Log/"${i%.*}".log | \
	awk '{if ($6 == "S") print $1}' | \
	sort | \
	tee "$OUTPUT"/FunSec_Output/TargetP/"${i%.*}"
done
if [ "$(find "$OUTPUT"/FunSec_Output/TargetP -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/TargetP -maxdepth 1 -type f | wc -l)" ]; then 
	echo -e "No proteins were predicted to be secreted. Exiting..."
	citation
	exit 0
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# WolfPsort, ProtComp and TargetP

echo -e "\nSelecting the common sequences found by WolfPsort 0.2, ProtComp 9.0 and TargetP 1.1...\n"
mkdir -p "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers
find "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius -maxdepth 1 -type f -exec basename {} \; | while read -r i; do
	comm -12 "$OUTPUT"/FunSec_Output/WolfPsort/"${i%.*}" "$OUTPUT"/FunSec_Output/ProtComp/"${i%.*}" > "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers/pre_"${i%.*}"
	comm -12 "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers/pre_"${i%.*}" "$OUTPUT"/FunSec_Output/TargetP/"${i%.*}" | \
	tee "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers/"${i%.*}"
done
find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers -type f -name "pre_*" -delete
if [ "$(find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers -maxdepth 1 -type f | wc -l)" ]; then
	echo -e "No common proteins were found. Exiting..."
	citation
	exit 0
else
	find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers -maxdepth 1 -type f -exec basename {} \; | while read -r i; do
		while read -r f; do
			awk -v f="$f" 'BEGIN {RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/SignalP_TMHMM_Phobius/"${i%.*}".fa | \
			sed '/^$/d' >> "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"${i%.*}".fa
		done < "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers/"${i%.*}"
	done
fi
echo -e "\nFinished. (Runtime - $SECONDS seconds)"

# Ps-scan 1.86

PS_SCAN_AWK='BEGIN{RS=">"} {print $1}' 

echo -e "\nRunning Ps-scan 1.86...\n"
mkdir -p "$OUTPUT"/FunSec_Output/Ps-scan/Log "$OUTPUT"/FunSec_Output/Final
find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP -maxdepth 1 -type f -exec basename {} \; | \
	parallel -j "$PARALLEL_JOBS" --noswap --load 80% --no-notice ""$SCRIPT_DIR"/bin/ps_scan/ps_scan.pl -p \"[KRHQSA]-[DENQ]-E-L>\" "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/{.}.fa | tee "$OUTPUT"/FunSec_Output/Ps-scan/Log/{.}.log | awk '$PS_SCAN_AWK' | sed '/^$/d' | sort > "$OUTPUT"/FunSec_Output/Ps-scan/{.}"
if [ "$(find "$OUTPUT"/FunSec_Output/Ps-scan -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/Ps-scan -maxdepth 1 -type f | wc -l)" ]; then
	echo -e "No endoplasmic reticulum targeting motifs found."
	rm -rf "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers
	cp -r "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/* "$OUTPUT"/FunSec_Output/Final/
else
	mkdir "$OUTPUT"/FunSec_Output/Final/Headers 
	find "$OUTPUT"/FunSec_Output/Ps-scan -maxdepth 1 -type f -exec basename {} \; | \
		parallel -j "$PARALLEL_JOBS" --noswap --load 80% --no-notice "comm -13 "$OUTPUT"/FunSec_Output/Ps-scan/{.} "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/Headers/{.} > "$OUTPUT"/FunSec_Output/Final/Headers/{.}"
	if [ "$(find "$OUTPUT"/FunSec_Output/Final/Headers -maxdepth 1 -type f -empty | wc -l)" -eq "$(find "$OUTPUT"/FunSec_Output/Final/Headers -maxdepth 1 -type f | wc -l)" ]; then 
		echo -e "No proteins were predicted to be secreted. Exiting..."
		citation
		exit 0
	else
		find "$OUTPUT"/FunSec_Output/Final/Headers -maxdepth 1 -type f -exec basename {} \; | while read -r i; do
			while read -r f; do
				awk -v f="$f" 'BEGIN{RS=">"} {if ($1 == f) print RS$0}' "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP/"${i%.*}".fa | \
				sed '/^$/d' >> "$OUTPUT"/FunSec_Output/Final/"${i%.*}".fa 
			done < "$OUTPUT"/FunSec_Output/Final/Headers/"${i%.*}"
		done
		find "$OUTPUT"/FunSec_Output/WolfPsort_ProtComp_TargetP -type d -name Headers -exec rm -rf {} +
		find "$OUTPUT"/FunSec_Output/Final -type d -name Headers -exec rm -rf {} +
	fi
fi

# Final Message

echo -e "\n$0 has finished (Runtime - $SECONDS seconds). The final secreted proteins can be found in $OUTPUT/FunSec_Output/Final.\n"
grep -H -c "^>" "$OUTPUT"/FunSec_Output/Final/*
citation
exit 0

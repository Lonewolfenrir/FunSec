# FunSec - Fungal Secreted Proteins (or Secretome) Prediction Pipeline #

## Description ##

FunSec was designed to automate the prediction of fungal secreted proteins from single or multiple FASTA files. It uses a complex pipeline that contains programs for the prediction of signal peptides, trans-membrane regions, subcellular localization and endoplasmic reticulum targeting motifs. It can also be used to predict complete fungal secretomes.

To predict signal peptides and trans-membrane regions, two different methods are used and only the proteins that are predicted by both methods are selected for further analysis. The first method uses SignalP 4.1 and TMHMM 2.0 to predict signal peptides and trans-membrane regions, respectively. The second method uses Phobius 1.01, which predicts both signal peptides and trans-membrane regions. For the subcellular localization prediction, three predictors are used: WolfPsort 0.2, TargetP 1.1 and ProtComp 9.0. Again, only the common proteins are selected. Finally, Ps-scan 1.86 is used with the profile of the PS00014 Prosite motif entry to predict endoplasmic reticulum (ER) proteins, which are then removed.

## Requirements ##

This pipeline only runs in **GNU/Linux**. It's necessary to install the programs used in the pipeline, so users will have to download and setup each program individually and move it into the FunSec's bin directory. Beware that, unfortunately, some of the programs have stopped working properly in most recent Linux Kernel versions. The last kernel version tested was **4.9 LTS**, so we recommend using this version to run the script.

### Installation ###

Please follow the instructions below for how to setup up each program.

##### SignalP 4.1 #####

To download SignalP 4.1, visit this <http://www.cbs.dtu.dk/cgi-bin/nph-sw_request?signalp> page and download the program for the Unix platform. User should receive a tar.gz file. To untar the file use the following command in your terminal:

```
tar -zxvf FILE.tar.gz
```

This will create a directory named signalp-4.1. The directory must be moved into the FunSec's bin directory.

For more instructions, visit this <http://www.cbs.dtu.dk/services/doc/signalp-4.1.readme> page.

##### TMHMM 2.0 #####

To download TMHMM 2.0, visit this <http://www.cbs.dtu.dk/cgi-bin/sw_request?tmhmm> page and download the program for the Unix platform. Users should receive a tar.gz file. To untar the file use the following command in your terminal:

```
tar -zxvf FILE.tar.gz
```

This will create a directory named tmhmm-2.0c. The directory must be moved into the FunSec's bin directory.

For more instructions, visit this <http://www.cbs.dtu.dk/services/doc/tmhmm-2.0c.readme> page.

##### Phobius 1.01 #####

To download Phobius 1.01, visit this <http://software.sbc.su.se/cgi-bin/request.cgi?project=phobius> page. Users should receive a tar.gz file. To untar the file use the following command in your terminal: 

```
tar -zxvf FILE.tar.gz
```

This will create a directory named tmp, inside it there are two more directories, one of them named phobius. The phobius directory must be moved into the FunSec's bin directory.

##### WolfPsort 0.2 #####

To download WolfPsort 0.2, visit this <https://github.com/fmaguire/WoLFPSort> page or use the following command in your terminal:

```
wget https://github.com/fmaguire/WoLFPSort/archive/master.zip
```

Users should receive a zip file. To unzip the file use the following command:

```
unzip FILE.zip
```

This will create a directory named WoLFPSort-master. The directory must be moved into the FunSec's bin directory.

##### TargetP 1.1 #####

To download TargetP 1.1, visit this <http://www.cbs.dtu.dk/cgi-bin/nph-sw_request?targetp> page and download the program for the Linux platform. Users should receive a tar.Z file. To untar the file use the following command in your terminal:

```
cat targetp-1.1b.Linux.tar.Z | uncompress | tar xvf -
```

This will create a directory named targetp-1.1b. The directory must be moved into the FunSec's bin directory. Note that TargetP 1.1 **requires** a short pathname to work, so it is advised to place FunSec in a short pathname directory.

For more instructions, visit this <http://www.cbs.dtu.dk/services/doc/targetp-1.1.readme> page.

##### ProtComp 9.0 #####

To download ProtComp 9.0, visit this <http://linux5.softberry.com/cgi-bin/download.pl?file=protcompan> page. Users should receive a tar.bz2 file. To untar the file use the following command in your terminal:

```
tar -xvjf FILE.tar.bz2
```

This will create a directory named lin. The directory must be moved into the FunSec's bin directory.

##### Ps-scan 1.86 #####

To download Ps-scan 1.86, visit this <ftp://ftp.expasy.org/databases/prosite/ps_scan/ps_scan_linux_x86_elf.tar.gz> page or use the following command in your terminal:

```
wget ftp://ftp.expasy.org/databases/prosite/ps_scan/ps_scan_linux_x86_elf.tar.gz
```

Users should receive a tar.gz file. To untar the file use the following command:

```
tar -zxvf FILE.tar.gz
```

This will create a directory named ps_scan. The directory must be moved into the FunSec's bin directory.

##### GNU Parallel #####

GNU Parallel is not mandatory, however, it speeds up the pipeline by executing the programs in parallel. This program should be in the repositories of your GNU/Linux system. For more information visit this <https://www.gnu.org/software/parallel/> page.

## Usage ##

The pipeline only works with **FASTA** files and due to the software's limitations, the headers must be 20 characters or less and cannot have spaces. To run it please use the following code in the GNU/Linux command-line:

```
./FunSec.sh -[OPTION] [ARGUMENT]
```

## Options ##

General Options:

```
	-d DIR,		Input directory (for multiple FASTA files). The headers must be 20 characters or less and cannot have spaces.
	-f FILE,	Input FASTA file. The headers must be 20 characters or less and cannot have spaces.
	-o OUTPUT,	Output directory.
	-p N,		Runs the pipeline in parallel with N jobs. The number of jobs is the same as the number of CPU cores. When using "0", it will run as many jobs in parallel as possible. When in doubt use "-p 100%". GNU Parallel must be installed.
```

WolfPsort 0.2 Options:

```
	-w N,		Threshold value for WolfPsort 0.2. N must be an integer in the range 1-30. The default value is "17".
```

SignalP 4.1 Options:

```
	-c N,		N-terminal truncation of input sequences. The value of "0" disables truncation. The default is 70 residues.
	-m N,		Minimal predicted signal peptide length. The default is 10 residues.
	-x N,		D-cutoff value for SignalP-TM networks. N must be in the range 0-1. To reproduce SignalP 3.0's sensitivity use "0.34". The default is "0.5".
	-y N,		D-cutoff value for SignalP-noTM networks. N must be in the range 0-1. To reproduce SignalP 3.0's sensitivity use "0.34". The default is "0.45".
	-n,		The SignalP-noTM neural networks are chosen.
```

TargetP 1.1 Options:

```
	-e N,		mTP-cutoff value. N must be in the range 0-1. The default is "0".
	-s N,		SP-cutoff value. N must be in the range 0-1. The default is "0".
	-z N,		other-cutoff value. N must be in the range 0-1. The default is "0".
```

Miscellaneous:

```
	-h,		Displays this message.
	-v,		Displays version.
```

The options -d or -f and -o and their respective arguments are mandatory, the rest of the options are optional. For more information read the README.md file.

## Citation ##

Please cite FunSec as well as all the programs that are used in the pipeline including GNU Parallel, if the option -p was used. Thank you!

## Contact ##

For further information or feedback please open an [issue](https://gitlab.com/lonewolfenrir/funsec/issues).

## License ##

GPLv3, see LICENSE file for more information.

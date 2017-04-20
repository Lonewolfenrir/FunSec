# FunSec - Fungal Secreted Proteins (or Secretome) Predictor Pipeline #

## Description ##

This script was designed to automate the prediction of fungal secreted proteins from single or multiple FASTA files using a complex pipeline that uses programs for the prediction of signal peptides, trans-membrane regions, subcellular localization and endoplasmic reticulum targeting motif. It can also be used for the prediction of complete fungal secretomes when given their proteomes.

To predict signal peptides and trans-membrane regions we used two different methods and only the proteins that were predicted by both methods were selected for further analysis. The first method uses SignalP 4.1 and TMHMM 2.0 to predict signal peptides and trans-membrane regions respectively. The second method uses Phobius 1.01 which predicts both signal peptides and trans-membrane regions. By using two methods that rely in different approaches for their predictions we were able to reduce the rate of false positives. The subcellular localization prediction was made using two predictors, WolfPsort 0.2 and ProtComp 9.0 and again only the common proteins were selected. Finally, Ps-scan 1.86 with the profile of the Prosite motif entry, PS00014, was used to predict the endoplasmic reticulum proteins.

## Requirements ##

This script only runs in **Linux** and Perl needs to be installed. The script needs the programs described above, so users will have to install each program individually into the bin directory of this script, with the following structure:

```
-bin
  |-lin
  |-phobius
  |-ps_scan
  |-signalp-4.1
  |-tmhmm-2.0c
  |-WoLFPSort-master
```

#### SignalP 4.1 ####

First, to download SignalP 4.1 visit <http://www.cbs.dtu.dk/cgi-bin/nph-sw_request?signalp> and download the program for the Unix platform. You should receive a tar.gz file. To untar the file use the following command in your terminal:

```
tar -zxvf FILE.tar.gz
```

This will create a directory called signalp-4.1. You must move this directory into the bin directory of this script. Then you must edit the file signalp in the directory bin/signalp-4.1/. You should see something like this:

```
# full path to the signalp-4.1 directory on your system (mandatory)
BEGIN {
    $ENV{SIGNALP} = '/usr/cbs/bio/src/signalp-4.1';
}

# determine where to store temporary files (must be writable to all users)
my $outputDir = "/var/tmp";

# max number of sequences per run (any number can be handled)
my $MAX_ALLOWED_ENTRIES=10000;
```

The path to the signalp-4.1 directory must be changed, if you don't know the path to the directory you can use the command 'pwd' in your signalp-4.1 directory and paste it on the configuration. If you are dealing with more than 10000 sequences per file, you must edit the value for the maximum allowed entries.

For more instructions go to <http://www.cbs.dtu.dk/services/doc/signalp-4.1.readme>.

#### TMHMM 2.0 ####

To download TMHMM 2.0 for the Unix platform visit <http://www.cbs.dtu.dk/cgi-bin/sw_request?tmhmm>. You should receive a tar.gz file. To untar the file use the following command:

```
tar -zxvf FILE.tar.gz
```

This will create a directory called tmhmm-2.0c. You must move this directory into the bin directory of this script. Now you will probably have to edit the first line of the files tmhmm and tmhmmformat.pl in the directory bin/tmhmm-2.0c/bin/. Run the following command:

```
which perl
```

If the output isn't /usr/local/bin/perl, then you must change the path in the first lines of the files with the one given by the command above.

#### Phobius 1.01 ####

To download Phobius 1.01 visit <http://software.sbc.su.se/cgi-bin/request.cgi?project=phobius>. You should receive a tar.gz file. To untar the file use the following command:

```
tar -zxvf FILE.tar.gz
```

This will create a directory called phobius. You must move this directory into the bin directory of this script.

#### WolfPsort 0.2 ####

To download WolfPsort you can go to <https://github.com/fmaguire/WoLFPSort> or use the following command:

```
wget https://github.com/fmaguire/WoLFPSort/archive/master.zip
```

You should receive a zip file. To unzip the file use the following command:

```
unzip FILE.zip
```

Then move the file WoLFPSort-master to the bin directory of this script.

#### ProtComp 9.0 ####

To download ProtComp you can go to <http://linux5.softberry.com/cgi-bin/download.pl?file=protcompan>. You should receive a tar.bz2 file. To untar the file use the following command:

```
tar -xvjf FILE.tar.bz2
```

This will create a directory called lin. You must move this directory into the bin directory of this script.

#### Ps-scan 1.86 ####

To download Ps-scan 1.86 you can go to <ftp://ftp.expasy.org/databases/prosite/ps_scan/ps_scan_linux_x86_elf.tar.gz> or use the following command:

```
wget ftp://ftp.expasy.org/databases/prosite/ps_scan/ps_scan_linux_x86_elf.tar.gz
```

You should receive a tar.gz file. To untar the file use the following command:

```
tar -zxvf FILE.tar.gz
```

This will create a directory called ps_scan. You must move this directory into the bin directory of this script.

#### GNU Parallel ####

To use the option '-p' of the script, GNU Parallel must be installed. Using GNU Parallel speeds up the pipeline by executing the programs in parallel. This program should be in the repositories of your Linux system.

## Usage ##

This script only works with FASTA format files.

```
./FunSec.sh -[OPTION] [ARGUMENT]
```

## Options ##

```
-d,		Input directory (for multiple files).
-f,		Input file.
-o,		Output directory.
-h,		Displays this message.
-w,		Threshold number for the program WolfPsort 0.2. Must be in the range 1-30. The default value is 17.
-p,		Runs the script in parallel, which makes it faster. GNU Parallel must be installed.
-v,		Displays version.

The options -d or -f and -o and their respective arguments must be specified. 
```

## Citation ##

Please cite this script as well as all the programs that are used in this script including GNU Parallel, if the option -p was used. Thank you!

[![DOI](https://zenodo.org/badge/78019551.svg)](https://zenodo.org/badge/latestdoi/78019551)

## Contact ##

For further information or feedback please open an [issue](https://github.com/Lonewolfenrir/FunSec/issues).

## License ##

GPLv3, see LICENSE file for more information.

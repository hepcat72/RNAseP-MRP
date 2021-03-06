# Intro

This repository houses or links to all analysis scripts and packages required to perform the Mutation Frequency and Maturing Poly-A Abundance analyses that were performed for the journal article "Assembly of S. cerevisiae telomerase and its nuclear localization depend on RNase P and RNase MRP protein components".  Linked repositories & software packages may have their own dependencies and requirements.  All scripts are provided as-is.  No formal installation support is provided by the developer of the scripts in this repository, but feel free to create issues relating to the shell scripts in this repo.  Issues relating to dependencies should be brought up with the developers of those software packages.

# License

GNU General Public License, version 3

See LICENSE file.

# Requirements

## System Requirements

- *nix OS (tested on Springdale linux version 6 and macOS Mojave version 10.14.3)
    - tcsh (tested on version 6.17.00 on linux and 6.18.01 on macOS)
    - perl (tested on version 5.10.1 on linux and 5.28.0 on macOS)
- A Galaxy Server (tested on Galaxy 19.01)
    - Either the ability to install or request the installation of tools

## Command Line Scripts (installation notes)

### Script Modifications for Installation

Note that each command line script may need to be edited to work on your system.  Each is provided as-is.  However, the following is a set of quick & untested notes that may help in editing each script to run on your data.  A user expereinced in shell scripting should be able to get the scripts working in about an hour.

The path to the tcsh executable will have to be checked at the top of each script (e.g. `/bin/tcsh`).

All three scripts are either called with or were written to require a package called batchCommander, which is a utility for running commands on a compute cluster.  This package has not yet been publicly released.  You can either contact rleach@princeton.edu and request access to a pre-release version or incorporate your own batch script.

#### split_amplicons3.tcsh

Arguments: reference_amplicon_fasta_file "forward_sample_fastq_files" "reverse_sample_fastq_files_same_order" clean_up_intermediate_files

Example arguments: amplicons.fasta "*forward.fastq" "*reverse.fastq" 1

Note, the forward and reverse files must be supplied in the same sample order.  If you use a glob pattern for each set of files, they must be inside quotes and named such that the shell displays them in the same sample order.  Each forward and reverse pair will be processed together, assuming that they were supplied in the same sample order.

Other than that, and making sure all the dependencies are in your path, this script should not need to be modified.

#### freebayes_div_and_conq.tcsh

This script takes no arguments.  It assues that there are 5 directories named `ASH1`, `NME1`, `TLC1-1`, `TLC1-2`, and `TLC1-3` and that there are reference fasta files for each amplicon 2 directories up in a reference directory: `../../REFERENCE/{ASH1,NME1,TLC1-1,TLC1-2,TLC1-3}.fa`.

#### count_snps.tcsh

Arguments: amplicon_name amplicon_length sample_number

This script assumes vcf files are sorted into directories created by freebayes_div_and_conq.tcsh and named in the following manner: `DG$s-*.split/*.vcf` where `$s` is the sample number.  The only thing you should need to modufy in the script is the places where the prefix "DG" is used.

### Mutation Frequency Analysis

Located in: RNAseP-MRP/mutation_frequency_analysis/scripts

Note, each script's dependencies must be manually installed in order for the scripts to work.  Look inside each script to view the usage notes at the top.  Some may require a specific directory structure.

- count_snps.tcsh
- freebayes_div_and_conq.tcsh
    - batchCommander (https://github.com/hepcat72/batchCommander) [*]
    - freeBayes (https://github.com/ekg/freebayes/releases)
- split_amplicons.tcsh
    - batchCommander (https://github.com/hepcat72/batchCommander) [*]
    - convertSeq (https://github.com/hepcat72/convertSeq)
    - parseBlast (https://github.com/hepcat72/parseBlast)
    - filetools (https://github.com/hepcat72/filetools)
        - rename.pl
        - grep.pl
    - Blast (version 2.2.26 - available via ncbi's ftp site)
        - blastall
        - formatdb
- *OPTIONAL* CFF (https://github.com/hepcat72/CFF)
    - mergeSeqs.pl
- *OPTIONAL* barcode_splitter (https://bitbucket.org/princeton_genomics/barcode_splitter/)

[*] Note, all dependencies are freely available except batchCommander.  batchCommander is a utility for running a series of command line calls on a cluster and works on SLURM, Torque, and SGE compute clusters.  You can either edit the above shell scripts to use your own cluster scripts or you can request a pre-release copy of batchCommander by emailing rleach@princeton.edu.

## Galaxy Workflows

Note that all workflows must be imported and any missing galaxy tools noted by Galaxy must be installed in order for the workflows to operate.

### Mutation Frequency Analysis

Located in: RNAseP-MRP/mutation_frequency_analysis/galaxy_workflows

- 1-QC.ga
- 2-Amplicon_Lengths.ga
- 3-Mapping.ga
- *OPTIONAL* Cut_Short_Amplicon_Adapters.ga (if amplicons are shorter than read length)

### Maturing Poly-A Abundance Analysis

Located in: RNAseP-MRP/maturing_polya_abundance_analysis

#### Main Workflow

- Mature_RNA_Abundance_Analysis_v4_(streamlined).ga

#### Sub-workflows

- Mature_RNA_Abundance_Analysis_Helper_1_(calc_abund_all).ga
- Mature_RNA_Abundance_Analysis_Helper_2_(plot_survival).ga
- Mature_RNA_Abundance_Analysis_Helper_3_(mapping_locs).ga
- Mature_RNA_Abundance_Analysis_Helper_4_(overrep_seqs).ga
- Mature_RNA_Abundance_Analysis_Helper_5_(collate_survival).ga

# Step-by-step Analyses

Some example data is provided so you can make sure you have the correct types of inputs to these analyses.  Unless otherwise noted, the input of each step is the output from the previous step.  Runtimes will depend on the size of the input data and the number of nodes on the compute cluster used.

## Mutation Frequency Analysis

In preparation, import these Galaxy Workflows (`*.ga`) into your Galaxy account and install any missing tools noted by Galaxy upon import:

- 1-QC.ga
- 2-Amplicon_Lengths.ga
- 3-Mapping.ga
- *OPTIONAL* Cut_Short_Amplicon_Adapters.ga

### Step 1: Split on barcodes

This step can be performed on galaxy or the command line using the barcode splitter of your choice.  We used the barcode splitter linked in the script requirements above with 1 allowed mismatch.

Input: Fastq files for forward and reverse reads which have not been barcode-split yet.

Output: A fastq file for each sample.  Each sample has sequences for all amplicons.

### Step 2: Blast and then split amplicons for each sample based on top hits

split_amplicons.tcsh can be run on a cluster using batchCommander.  It takes a fasta file of the reference amplicon sequences and the forward and reverse fastq files.  The forward and reverse files must be similarly named so that they are processed in the same order (tip: they must appear in the same relative order when using `ls` on the command line).

Note, you must preplace the following with your parameters:

- `/path/to/` with the path to `split_amplicons.tcsh`.
- `forward_reads.fq` with the name of your forward reads file.
- `reverse_reads.fq` with the name of your reverse reads file.

```
disEmbarrass.pl --de-split-auto /path/to/split_amplicons.tcsh reference_amplicons.fa "forward_reads.fq" "reverse_reads.fq" 1 > ampsplt.commands

batchCommander.pl ampsplt.commands --verbose --mem 8000
```

Output: A fastq file for each sample and amplicon.

### Step 3: Run Galaxy workflow "Cut short amplicon adapters"

This needs to be done only on forward and reverse reads of amplicons that are shorter than the read length that came off of the sequencer.  It should be run on all samples for each affected amplicon.  Amplicons/Samples must be in paired collections.

Our custom adapters and amplicon length parameters are pre-filled in, but should be changed for your data.  Min and max lengths (for *minimum_final_trimmed_length* and *maximum_final_trimmed_length*) of *amplicon length* +/- 5 and the expected adapter length included in the reads (for *adapter_overlap_minimum*) are what we used.

Output: A fastq file with adapters trimmed off.

### Step 4: Run the workflow "Amplicon lengths"

This simply counts the nucleotides in the amplicon reference sequences.  The lengths will be entered in the next step.  These are the lengths of our amplicon templates we used in our analysis:

- ASH1: 191
- NME1: 309
- TLC1-1: 348
- TLC1-2: 316
- TLC1-3: 243

Output: A text file with amplicon lengths.

### Step 5: Run the galaxy workflow "Mutation Frequencies"

Run this for each amplicon-separated collection of paired-end fastq files.  We set the length filters of +/- 10 using the amplicon template lengths determined above:

- ASH1	181	201
- NME1	181	201
- TLC1-1 	142	162
- TLC1-2 	174	194
- TLC1-3 	233	253

If the freeBayes command fails on Galaxy because it runs out of memory or exceeded computation time and gets killed by the cluster, download the bam files, split them up, and run them manually using `freebayes_div_and_conq.tcsh`.  It breaks up bam files for every 10k mappings.  It needs to be run from a directory containing the subdirectories for each amplicon - each of which contains a set of bam files (one for each sample).  Note, it assumes that all stitched-together reads are intended to map from beginning to end of the reference amplicon it was mapped to.

Output: A vcf file for each sample and amplicon.

### Step 6: Run the SNP counting and depth script

The following is a tcsh shell script to create a file of calls to the `count_snps.tcsh` script and run them on a compute cluster.  You can optionally supply a walltime of 1 hour (or use a 1 hour queue), as all jobs should take under an hour.  The foreach loop should is on a series of colon-delimited strings representing `amplicon_name:amplicon_length` (shown are the amplicon parameters used in our analysis - change them for your amplicons).  Although batchCommander is used here to submit the jobs, you may alternatively use your own cluster script.

You must replace the following:

- `ASH1:191 NME1:309 TLC1-1:348 TLC1-2:316 TLC1-3:243` - as indicated in the paragraph above.
- `/path/to/` - with the path to `count_snps.tcsh`.

```
echo -n "" > cntsnps.commands
foreach r ( ASH1:191 NME1:309 TLC1-1:348 TLC1-2:316 TLC1-3:243 )
set a=`echo $r | cut -d ":" -f 1`
set l=`echo $r | cut -d ":" -f 2`
foreach s ( `seq 1 36` )
echo "/path/to/count_snps.tcsh $a $l $s > $a.DG$s.snpcounts.stdout" >> cntsnps.commands
end
end

batchCommander.pl cntsnps.commands -p DONE --verbose -s 0
```

Output: A tab-delimited text file for each sample and amplicon.  Columns are:

1. Sample name
2. Amplicon name
3. Amplicon position
4. Total number of reads overlapping this position
5. Total number of alternate observations (i.e. not the nucleotide in the amplicon reference)
6. The reference nucleotide (^ indicates that the value in the following column represents the total nucleotides that are "not" the value indicated)
7. Number of nucleotides that are not the reference value
8. Nucleotide 'A'~
9. Number of occurrences of the nucleotide 'A'~
10. Nucleotide 'T'~
11. Number of occurrences of the nucleotide 'T'~
12. Nucleotide 'G'~
13. Number of occurrences of the nucleotide 'G'~
14. Nucleotide 'C'~
15. Number of occurrences of the nucleotide 'C'~

~ Empty if this is for the reference nucleotide

### Step 7: *OPTIONAL* Compute haplotype abundances

To compute the abundance of each unique variant of the amplicon, you can use mergeSeqs.pl from the CFF package.  Note, this trims all sequences to the supplied amplicon length and discards anything shorter, so you may wish to use a length slightly shorter than your amplicon length.  The following must be replaced with your personal parameters:

- `amplicon_reference.fa`
- `summary_outfile_name.txt`

```
mergeSeqs.pl -b amplicon_length -p '' -f amplicon_reference.fa -u summary_outfile_name.txt -o .fa -x .tab -i "*.fq" --verbose
```

Note that `"*.fq"` must be in quotes.

Output: Refer to the output of `mergeSeqs.pl --help`.

## Maturing Poly-A Abundance Analysis

The following steps assume you're starting from barcode-split Fastq files.

1. Import the Galaxy Workflows (`*.ga`) into your Galaxy account and install any missing tools noted by Galaxy upon import
2. Put all your demultiplexed samples' forward and reverse reads files into a list of dataset pairs.
3. Run the main workflow (`Mature RNA Abundance Analysis v4 (streamlined)`).
4. Select your sample collection (created in step 2) in the workflow form.
5. Enter all the workflow parameters as shown in this example using our parameters:
    - **read_length**: `250`
    - **forward_match_sequence**: `CCGTGTGTTCATTTTATGAATCTTGGTGTTGTATTCACAGCTACTTCTCCTAATGCCTTCGATGCATTTAGATAATTTTTGGAAACAT`
    - **revcomp_match_sequence**: `ATGTTTCCAAAAATTATCTAAATGCATCGAAGGCATTAGGAGAAGTAGCTGTGAATACAACACCAAGATTCATAAAATGAACACACGG`
    - **max_mismatch_density_for-rev_merge_0-1**: `0.1`
    - **max_error_rate_5p_template_0-1**: `0.1`
    - **three_prime_segment_to_trim**: `CTGTAGGCACCATCAATCGTTACGTAG`
    - **rc_three_prime_segment_to_trim**: `CTACGTAACGATTGATGGTGCCTACAG`

Note that the merged forward and reverse reads do not all need to be in the same orientation.  The workflow will flip them so that the forward match sequence is on the 5 prime end and the linker (i.e. 3 prime match sequence) is on the 3 prime end.  It will also trim the linker as many times as needed to account for multiple ligations.

When the workflow (and sub-workflows) are complete, you will end up with a number of items added to your galaxy history, the following of which are of note:

- **Merged Reads (Raw)** - These are the stitched together forward and reverse reads
- **Mapping Locations Summary** - This is a QC output to confirm that most sequences are mapping to your amplicon
- **FastQC** - A QC output, including over-represented sequences
- **TLC1 Match Info** - A QC output from cutadapt showing where TLC1 was trimmed off
- **Mature RNA Abundances (final output)** - Contains abundances of the maturing RNA states and the lengths and abundances of its Poly-A tail
- **Read Survival (MultiQC)** - This shows you a plot of data lost at each step of the analysis from the raw forward/reverse reads to the last trim of the Poly-A tail

# Authors

- Robert W. Leach
- Daniela Garcia

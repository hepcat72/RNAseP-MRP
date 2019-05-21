#!/bin/tcsh

# usage: count_snps.tcsh amplicon_sequence_name amplicon_length sample_number
# example: count_snps.tcsh ASH1 191 1

#This script must be run from a directory from which split_amplicons.tcsh was run.  I.e. it must contain directories matching "DG*-*.split" which must contain "*.vcf" files

set a=`echo $argv | cut -d " " -f 1`
set l=`echo $argv | cut -d " " -f 2`
set s=`echo $argv | cut -d " " -f 3`
cd $a
foreach n ( `seq 1 $l` )
perl -e 'print STDERR ("DOING DG",join(" ",@ARGV),"\r")' $s $a $n
perl -e 'print("DG",join("\t",@ARGV),"\t")' $s $a $n >> ../$a.DG$s.snpcounts
grep "$a.$n.\." DG$s-*.split/*.vcf | cut -f 4,5,10 | cut -d ":" -f 1,2,6 | perl -e 'while(<>){@d=split(/[:\t]/,$_,-1);$ref=$d[0];@alts=split(/,/,$d[1],-1);$dep+=$d[3];@cnts=split(/,/,$d[4],-1);unless(scalar(@alts) == scalar(@cnts)){print STDERR "ERROR\n"}foreach(0..$#alts){$any+=$cnts[$_];$sums->{$alts[$_]}+=$cnts[$_]}}print("$dep\t^$ref\t$any\t",join("\t",map {exists($sums->{$_}) ? "$_\t$sums->{$_}" : "\t"} qw(A T G C)),"\n")' >> ../$a.DG$s.snpcounts
end
echo DONE
#!/bin/tcsh

#Usage.  No parameters.  Must be run in a directory containing these directories with bam files and bam indexes inside each: ASH1 NME1 TLC1-1 TLC1-2 TLC1-3

foreach d ( ASH1 NME1 TLC1-1 TLC1-2 TLC1-3 )

cd $d
if ( $status ) then
  echo "Command 1 failed"
  exit 1
endif

foreach b ( *.bam )

if ( ! -e $b.split ) then
  mkdir $b.split
  if ( $status ) then
    echo "Command 2 failed"
    exit 2
  endif
endif

echo "Splitting $b and filtering unmapped"
perl -e 'my $splitsize=$ARGV[0];my $cnt=0;my $sfx=0;open(IN,"samtools view -q 1 $ARGV[1] |");while(<IN>){unless($cnt % $splitsize){$sfx++;if(defined(fileno(OUT))){close(OUT)}open(HD,"samtools view -H $ARGV[1] |");print STDERR ("Opening new output file: $ARGV[1].$sfx.bam\n");open(OUT,"| samtools view -b > $ARGV[1].split/$ARGV[1].$sfx.bam");select(OUT);print(<HD>);}$cnt++;print STDERR ("Printing input file $ARGV[1] line $cnt\r");print($_);}' 10000 $b
if ( $status ) then
  echo "Command 3 failed"
  exit 3
endif

cd $b.split

foreach s ( *.bam )
samtools index $s
if ( $status ) then
  echo "Command 4 failed"
  exit 4
endif
end

cd ..

end

echo "Preparing freebayes run on *.split/*.bam"
disEmbarrass.pl --de-split-auto --de-is-suffix --vcf /Genomics/grid/users/rleach/local/bin/freebayes -b "*.split/*.bam" --fasta-reference ../../REFERENCE/$d.fa --vcf .vcf --report-monomorphic --theta 0.00001 --ploidy 2 -K -i -X -u -n 0 --haplotype-length 0 --min-repeat-size 5 --min-repeat-entropy 0 -m 1 -q 0 -R 0 -Y 0 -e 1000 -F 0.0 -C 1 -G 1 --min-coverage 0 --min-alternate-qsum 0 --use-duplicate-reads --min-alternate-count 1 --min-alternate-fraction 0 > $d.freebayes.commands
if ( $status ) then
  echo "Command 5 failed"
  exit 5
endif

echo "Running freebayes on *.split/*.bam"
batchCommander.pl $d.freebayes.commands --mem 10000 --verbose --overwrite -s 0
if ( $status ) then
  echo "Command 6 failed"
  exit 6
endif

echo "Cleaning up"
\rm -f *.split/*.bam
if ( $status ) then
  echo "Command 7 failed"
  exit 7
endif

cd ..

end

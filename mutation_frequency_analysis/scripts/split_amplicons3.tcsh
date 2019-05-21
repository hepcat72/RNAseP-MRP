#!/bin/tcsh

#USAGE: split_amplicons3.tcsh reference_amplicon_fasta_file "forward_sample_fastq_files" "reverse_sample_fastq_files_same_order" 1
#EXAMPLE: split_amplicons3.tcsh amplicons.fasta "*forward.fastq" "*reverse.fastq" 1

#The last parameter is whether or not to clean up intermediate files as you go

#This script takes a set of expected amplicons in fasta format, and forward and reverse fastq files and splits up those fastq files based on blast matches


#DEPENDENCIES:
#Utilities:
#  blastall
#  formatdb
#Unix command line tools
#  cat,echo,perl,wc,seq,grep,cut
#Scripts:
#  convertSeq.pl
#  parseBlast.pl
#  rename.pl
#  disEmbarrass.pl
#  batchCommander.pl


setenv REF    `echo "$argv" | cut -d ' ' -f 1`
setenv FWDPAT `echo "$argv" | cut -d ' ' -f 2`
setenv REVPAT `echo "$argv" | cut -d ' ' -f 3`
setenv CLEAN  `echo "$argv" | cut -d ' ' -f 4`

setenv FWDFQS `echo $FWDPAT`
setenv REVFQS `echo $REVPAT`


echo
echo "RUNNING $0"
echo "REFERENCE:  $REF"
echo "FWD FASTQS: $FWDPAT"
echo "REV FASTQS: $REVPAT"
echo


#Get the amplicon names
echo
echo "Determining amplicon IDs"
set AMPLICON_NAMES=`grep \> $REF | cut -d ' ' -f 1 | cut -d '>' -f 2`
if ( $status ) then
  echo "Command 1 failed"
  exit 1
else
  echo SUCCESS
endif


#Calculate the number of samples:
@ n = 0
foreach f ( $FWDFQS )
 @ n = ( $n + 1 )
end

#Make sure there are the same number of forward and reverse fastq files.
echo
echo "Checking the number of paired end files"
@ m = 0
foreach f ( $REVFQS )
 @ m = ( $m + 1 )
end
if ( $n != $m ) then
  echo "ERROR: Different number of forward and reverse files"
  exit 2
else
  echo SUCCESS
endif



echo
echo "Formatting the amplicon reference file for nt blasting: $REF"
formatdb -p F -i $REF
if ( $status ) then
  echo "Command 3 failed"
  exit 3
else
  echo SUCCESS
endif



#For each sample
foreach s ( `seq 1 $n` )

  #Grab the forward and reverse fastq files
  set FWDFQ=`echo "$FWDFQS" | cut -d ' ' -f $s`
  set REVFQ=`echo "$REVFQS" | cut -d ' ' -f $s`


  #For each direction read (forward and reverse)'s fastq file
  foreach f ( "$FWDFQ" "$REVFQ" )


    echo
    echo "Converting $f to fasta for blasting"
    echo "~/pub/seqtools/convertSeq.pl -i '$f' --fasta-seq-suffix .fa --from-fastq --to-fasta --skip-format-check --overwrite"
    ~/pub/seqtools/convertSeq.pl -i "$f" --fasta-seq-suffix .fa --from-fastq --to-fasta --skip-format-check --overwrite
    if ( $status ) then
      echo "Command 4 failed"
      exit 4
    else
      echo SUCCESS
    endif


    echo
    echo "~/pub/filetools/grep.pl --split-group-size 100000 '$f.fa' -p '>' -t -o .split"
    ~/pub/filetools/grep.pl --split-group-size 100000 "$f.fa" -p '>' -t -o .split
    if ( $status ) then
      echo "Command 5 failed"
      exit 5
    else
      echo SUCCESS
    endif


    echo
    echo "~/pub/clustertools/disEmbarrass.pl --de-split-auto --de-is-stub -i --de-is-suffix -o blastall -p blastn -d '$REF' -i '$f.fa.[0-9]*.split' -v 1 -b 1 -o '.br' > $f.blastcommands"
    ~/pub/clustertools/disEmbarrass.pl --de-split-auto --de-is-stub -i --de-is-suffix -o blastall -p blastn -d "$REF" -i "$f.fa.[0-9]*.split" -v 1 -b 1 -o '.br' > $f.blastcommands
    if ( $status ) then
      echo "Command 6 failed"
      exit 6
    else
      echo SUCCESS
    endif


    echo
    echo "~/pub/clustertools/batchCommander.pl '$f.blastcommands' --pipeline-mode --verbose"
    ~/pub/clustertools/batchCommander.pl "$f.blastcommands" --pipeline-mode --verbose --overwrite
    if ( $status ) then
      echo "Command 7 failed"
      exit 7
    else
      echo SUCCESS
    endif


    echo
    echo "cat $f.fa.[0-9]*.split.br > $f.fa.br"
    cat $f.fa.[0-9]*.split.br > $f.fa.br
    if ( $status ) then
      echo "Command 8 failed"
      exit 8
    else
      echo SUCCESS
    endif

    if ( $CLEAN ) then
      rm -f "$f.fa" $f.fa.[0-9]*.split $f.fa.[0-9]*.split.br
    endif


    echo
    echo "parseBlast.pl '$f.fa.br' -o .tab --overwrite"
    parseBlast.pl "$f.fa.br" -o .tab --overwrite
    if ( $status ) then
      echo "Command 9 failed"
      exit 9
    else
      echo SUCCESS
    endif

    if ( $CLEAN ) then
      rm -f "$f.fa.br"
    endif

  end




  #Keep track of the number of rows just in case the grep matches are unique
  #We're only going to check the forward file - should be adequate
  @ c = 0


  #For each amplicon in the reference file
  foreach p ( $AMPLICON_NAMES )


    #For each direction read (forward and reverse)'s fastq file
    foreach f ( "$FWDFQ" "$REVFQ" )


      #grab all the blast result rows that contain the amplicon ID
      echo
      echo "grep '$p' '$f.fa.br.tab' > '$f.fa.br.tab.$p'"
      grep "$p" "$f.fa.br.tab" > "$f.fa.br.tab.$p"
      if ( $status ) then
        echo "Command 10 failed"
        exit 10
      else
        echo SUCCESS
      endif


      #Extract just the amplicon IDs instead of entire blast rows
      echo
      echo "cut -f 1 '$f.fa.br.tab.$p' | uniq > '$f.fa.br.tab.$p.ids'"
      cut -f 1 "$f.fa.br.tab.$p" | uniq > "$f.fa.br.tab.$p.ids"
      if ( $status ) then
        echo "Command 11 failed"
        exit 11
      else
        echo SUCCESS
      endif


    end


    echo
    echo "Summing hits in $FWDFQ.fa.br.tab.$p to ensure uniqueness"
    set NH=`cat "$FWDFQ.fa.br.tab.$p" | wc -l`
    if ( $status ) then
      echo "Command 12 failed"
      exit 12
    else
      echo SUCCESS
    endif
    @ c = ( $c + $NH )

    if ( $CLEAN ) then
      rm -f "$FWDFQ.fa.br.tab.$p" "$REVFQ.fa.br.tab.$p"
    endif


    #This ID file will contain IDs of sequences whose forward AND reverse
    #reads each hit the same amplicon in the blast (a file for each amplicon)
    set idfile="$FWDFQ.$p.ids"

    echo
    echo "Getting cross section of $FWDFQ.fa.br.tab.$p.ids and $REVFQ.fa.br.tab.$p.ids & saving in: $idfile"
    perl -e '$idf=$ARGV[0];$idf2=$ARGV[1];open(ID1,$idf);while(<ID1>){chomp;$h->{$_}=0}close(ID1);open(ID2,$idf2);while(<ID2>){$m=$_;chomp($m);if(exists($h->{$m})){print}}close(ID2);' $FWDFQ.fa.br.tab.$p.ids $REVFQ.fa.br.tab.$p.ids > $idfile
    if ( $status ) then
      echo "Command 13 failed"
      exit 13
    else
      echo SUCCESS
    endif

    if ( $CLEAN ) then
      rm -f "$FWDFQ.fa.br.tab.$p.ids" "$REVFQ.fa.br.tab.$p.ids"
    endif


  end


  echo
  echo "Comparing summed hits to $FWDFQ.fa.br.tab to ensure uniqueness"
  set NH=`cat "$FWDFQ.fa.br.tab" | wc -l`
  if ( $status ) then
    echo "Command 14 failed"
    exit 14
  else
    echo SUCCESS
  endif
  if ( $c > $NH ) then
    echo
    echo "ERROR: The Amplicon IDs ($AMPLICON_NAMES) are not uniquely identifying.  Using them to grep the blast output files is matching too many lines.  Unable to proceed.  Edit the deflines in $REF to ensure that the IDs cannot match each other (e.g. ID1 will also match ID10) and do not match other numbers or latters that can be found in the FASTQ or parsed blast files."
    exit 15
  else
    echo SUCCESS
  endif

  if ( $CLEAN ) then
    rm -f "$FWDFQ.fa.br.tab" "$REVFQ.fa.br.tab"
  endif


  #For each direction read (forward and reverse)'s fastq file
  foreach f ( "$FWDFQ" "$REVFQ" )


    #This file will hold IDs of all sequences whose forward AND reverse reads
    #each hit the same amplicon of any of the amplicons, so that later we can
    #generate a "nohit" (or not the same amplicon hit) file
    echo -n "" > $FWDFQ.ids


    #For each amplicon in the reference file
    foreach p ( $AMPLICON_NAMES )


      #This ID file contains IDs of sequences whose forward AND reverse reads
      #each hit the same amplicon in the blast (a file for each amplicon)
      set idfile="$FWDFQ.$p.ids"


      echo
      echo "Extracting dual matches for amplicon $p from fastq file: $f"
      perl -e '$idf=$ARGV[0];$fq=$ARGV[1];open(IDS,$idf);while(<IDS>){chomp;$h->{$_}=0}close(IDS);open(FQ,$fq);while(<FQ>){$m=$_;chomp($m);if(/^\@(\S+)/){$id=$1;if(exists($h->{$id})){print;print(scalar(<FQ>),scalar(<FQ>),scalar(<FQ>));}else{scalar(<FQ>);scalar(<FQ>);scalar(<FQ>)}}else{print STDERR "No defline: $_";}}close(FQ);' "$idfile" "$f" > "$f.$p"
      if ( $status ) then
        echo "Command 16 failed"
        exit 16
      else
        echo SUCCESS
      endif


      echo
      echo "~/pub/filetools/rename.pl -w .fastq -f $f.$p"
      ~/pub/filetools/rename.pl -w ".fastq" -f "$f.$p"
      if ( $status ) then
        echo "Command 17 failed"
        exit 17
      else
        echo SUCCESS
      endif

      #Append this amplicon's IDs to the global lookup file
      cat "$idfile" >> $FWDFQ.ids

      if ( $CLEAN ) then
        rm -f "$idfile"
      endif



    end


    #Generate fastq files where one or both of the amplicons had no hit (or they
    #didn't hit the same amplicon).
    echo
    echo "Generating a no-hit fastq file for read pairs that matched no or different amplicons"
    cat $FWDFQ.ids | perl -e '$idf="-";$fq=$ARGV[0];open(IDS,$idf);while(<IDS>){chomp;$h->{$_}=0}close(IDS);open(FQ,$fq);while(<FQ>){$m=$_;chomp($m);if(/^\@(\S+)/){if(exists($h->{$1})){scalar(<FQ>);scalar(<FQ>);scalar(<FQ>)}else{print;print(scalar(<FQ>),scalar(<FQ>),scalar(<FQ>))}}else{print STDERR "No defline: $_";}}close(FQ);' $f > $f.nohit
    if ( $status ) then
      echo "Command 18 failed"
      exit 18
    else
      echo SUCCESS
    endif

    if ( $CLEAN ) then
      rm -f "$FWDFQ.ids"
    endif



    #Rename the file to put .fastq at the end.
    echo
    echo "~/pub/filetools/rename.pl -w .fastq -f $f.nohit"
    ~/pub/filetools/rename.pl -w .fastq -f $f.nohit
    if ( $status ) then
      echo "Command 19 failed"
      exit 19
    else
      echo SUCCESS
    endif


  end


end


echo
echo "You can now upload the amplicon-split FastQ files to galaxy to run cutadapt (if necessary), merge the forward and reverse reads, map them to the reference amplicons, and run freeBayes."
echo
echo DONE
echo

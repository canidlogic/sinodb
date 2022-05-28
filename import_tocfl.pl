#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

import_tocfl.pl - Import data from TOCFL into the Sino database.

=head1 SYNOPSIS

  ./import_tocfl.pl nv1.csv nv2.csv l1.csv l2.csv l3.csv l4.csv l5.csv

=head1 DESCRIPTION

This script is used to fill a Sino database with information derived
from TOCFL vocabulary data files.  Uses Sino::DB and SinoConfig, so
you must configure those two correctly before using this script.  See
the documentation in C<Sino::DB> for further information.

This script should be your second step after using C<createdb.pl> to
create an empty Sino database.

As of the time of writing, the source vocabulary list can be downloaded
from the following site:

  https://tocfl.edu.tw/index.php/exam/download

The file you want is named something like C<8000zhuyin_202204.rar>.
(You may need to use an online converter to repackage this RAR archive
in a non-proprietary archive format before extracting.)

Within that archive, there should be a large Excel spreadsheet.  This
spreadsheet has the vocabulary lists, with one spreadsheet tab for each
vocabulary level.  Using LibreOffice Calc or some other spreadsheet
program, copy each vocabulary list B<excluding the header rows> to a new
spreadsheet and then save that spreadsheet copy in Comma-Separated Value
(CSV) format, using commas as the separator, no quoting, and UTF-8
encoding.  As a result, you should end up with seven CSV text files
corresponding to the vocabulary levels within the spreadsheet.  The CSV
files must B<not> have a header row with column names at the start; if
they do, delete the header rows.

Once you have the CSV files, pass the paths to all seven of them in
order of increasing difficulty level to this script.  This script will
parse the CSV data and import it into the Sino database.

=cut

# ==================
# Program entrypoint
# ==================

# Check that we got exactly seven arguments and each is a file
#
($#ARGV == 6) or die "Wrong number of arguments, stopped";
for my $fpath (@ARGV) {
  (-f $fpath) or die "Can't find file '$fpath', stopped";
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Define hash that will store mapping of word-class names to their
# numeric IDs
#
my %wcm;

# Get all existing word-class mappings in the database, checking the
# name format in the process
#
my $wcq = $dbh->selectall_arrayref(
            'SELECT wclassid, wclassname FROM wclass');
if (ref($wcq) eq 'ARRAY') {
  for my $wca (@$wcq) {
    # Get name and numeric id
    my $wcn = $wcq->[1];
    my $wci = $wcq->[0];
    
    # Verify the name format
    ($wcn =~ /\A[A-Z][a-z\-]*\z/) or
      die "Invalid existing word class name '$wcn', stopped";
    
    # Store the name -> ID mapping
    $wcm{$wcn} = $wci;
  }
}

# Process files level by level
#
for(my $vlevel = 1; $vlevel <= 7; $vlevel++) {
  # Open the file for reading in UTF-8 with CR+LF translation
  my $fpath = $ARGV[$vlevel - 1];
  open(my $fh, "< :encoding(UTF-8) :crlf", $fpath) or
    die "Failed to open '$fpath', stopped";
  
  # Now read line-by-line
  my $lnum = 0;
  while (my $ltext = readline($fh)) {
    # Increase line counter
    $lnum++;
    
    # If this is very first line of file, drop any UTF-8 Byte Order Mark
    # (BOM) from the start
    if ($lnum == 1) {
      $ltext =~ s/\A\x{feff}//;
    }
    
    # Drop line break if present
    chomp $ltext;
    
    # Normalize variant parentheses into ASCII parentheses
    $ltext =~ s/\x{ff08}/\(/g;
    $ltext =~ s/\x{ff09}/\)/g;
    
    # Drop ZWSP
    $ltext =~ s/\x{200b}//g;
    
    # Replace variant lowercase a with ASCII lowercase a
    $ltext =~ s/\x{251}/a/g;
    
    # Replace lowercase breves with lowercase carons
    $ltext =~ s/\x{103}/\x{1ce}/g;
    $ltext =~ s/\x{12d}/\x{1d0}/g;
    $ltext =~ s/\x{14f}/\x{1d2}/g;
    $ltext =~ s/\x{16d}/\x{1d4}/g;
    
    # Make sure no ? character used
    (not ($ltext =~ /\?/)) or
      die "File $vlevel line $lnum: Invalid ? character, stopped";
    
    # If row ends with a comma and optional whitespace, insert a ? at
    # end so we still split properly
    $ltext =~ s/,[ \t]*\z/,\?/;
    
    # Parse into three or four fields with comma separator
    my @rec = split /,/, $ltext;
    (($#rec == 2) or ($#rec == 3)) or
      die "File $vlevel line $lnum: Wrong number of fields, stopped";
    
    # If we got four fields, the first is the optional word topic, which
    # we will not be including, so drop it
    if ($#rec == 3) {
      shift @rec;
    }
    
    # If last field is the special ? we inserted, change to blank
    $rec[2] =~ s/\A[ \t]*\?[ \t]*\z//;
    
    # For each field, trim leading and trailing whitespace, then drop
    # leading and trailing quotes if present, then trim leading and
    # trailing whitespace again
    for my $fv (@rec) {
      $fv =~ s/\A[ \t]*(?:["'][ \t]*)?//;
      $fv =~ s/(?:[ \t]*["'])?[ \t]*\z//;
    }
  
    # Drop Bopomofo parentheticals and empty parentheticals in headword
    # and whitespace trim once again
    $rec[0] =~ s/\([ \t\x{2ca}-\x{2d9}\x{3100}-\x{3129}]*\)//g;
    $rec[0] =~ s/\A[ \t]+//;
    $rec[0] =~ s/[ \t+]\z//;
    
    # Get sequence of headwords, pinyin, and parts-of-speech by
    # splitting fields on forward slash
    my @hwsa  = split /\//, $rec[0];
    my @pnysa = split /\//, $rec[1];
    my @wcs   = split /\//, $rec[2];
    
    # For headwords and pinyin, elements that have a parenthetical
    # should be split into two separate entries, one with the
    # parenthetical and one without; we already dropped Bopomofo
    # parentheticals earlier so those won't be handled here; we will
    # create new arrays @hws and @pnys that store the expanded entries
    my @hws;
    my @pnys;
    for(my $i = 0; $i < 2; $i++) {
      # Get references to the source array and target array we are
      # handling here
      my $sa;
      my $ta;
      if ($i == 0) {
        $sa = \@hwsa;
        $ta = \@hws;
        
      } elsif ($i == 1) {
        $sa = \@pnysa;
        $ta = \@pnys;
        
      } else {
        die "Unexpected";
      }
      
      # Go through each element in the source array and either copy
      # as-is to target array or split into two elements in target
      # array; also, do duplication checks so that duplicates are never
      # inserted while decoding
      for my $sv (@$sa) {
        # Handle cases
        if ($sv =~ /\A
                      ([^\(\)]*)
                      \(
                      ([^\(\)]*)
                      \)
                      ([^\(\)]*)
                    \z/x) {
          # Single parenthetical, so split into prefix optional suffix
          my $prefix = $1;
          my $option = $2;
          my $suffix = $3;
          
          # Whitespace-trim each
          $prefix =~ s/\A[ \t]+//;
          $prefix =~ s/[ \t]+\z//;
          
          $option =~ s/\A[ \t]+//;
          $option =~ s/[ \t]+\z//;
          
          $suffix =~ s/\A[ \t]+//;
          $suffix =~ s/[ \t]+\z//;
          
          # Make sure option is not empty after trimming
          (length($option) > 0) or
            die "File $vlevel line $lnum: Empty optional, stopped";
          
          # Make sure either prefix or suffix (or both) is non-empty
          ((length($prefix) > 0) or (length($suffix) > 0)) or
            die "File $vlevel line $lnum: Invalid optional, stopped";
          
          # Insert both without and with the optional, but only if not
          # already in the target array
          for my $iv ($prefix . $suffix, $prefix . $option . $suffix) {
            my $dup_found = 0;
            for my $dvc (@$ta) {
              if ($iv eq $dvc) {
                $dup_found = 1;
                last;
              }
            }
            unless ($dup_found) {
              push @$ta, ($iv);
            }
          }
          
        } elsif ($sv =~ /\A[^\(\)]*\z/) {
          # No parentheticals, so begin by whitespace trimming
          $sv =~ s/\A[ \t]+//;
          $sv =~ s/[ \t]+\z//;
          
          # Make sure after trimming not empty
          (length($sv) > 0) or
            die "File $vlevel line $lnum: Empty component, stopped";
          
          # Push into target array, but only if not already in the
          # target array
          my $dup_found = 0;
          for my $dvc (@$ta) {
            if ($sv eq $dvc) {
              $dup_found = 1;
              last;
            }
          }
          unless ($dup_found) {
            push @$ta, ($sv);
          }
          
        } else {
          # Other cases are invalid
          die "File $vlevel line $lnum: Invalid record, stopped";
        }
      }
    }
  
    # We already did whitespace trimming and blank detection within @hws
    # and @pnys; now do whitespace trimming and blank detection within
    # @wcs
    for my $cv (@wcs) {
      $cv =~ s/\A[ \t]+//;
      $cv =~ s/[ \t]+\z//;
      (length($cv) > 0) or
        die "File $vlevel line $lnum: Blank word class, stopped";
    }
    
    # Go through all the headwords and make sure only characters of
    # General Category Letter-Other (Lo) are used
    for my $fv (@hws) {
      ($fv =~ /\A[\p{Lo}]+\z/) or
        die "File $vlevel line $lnum: Invalid headword char, stopped";
    }
    
    # Go through all the Pinyin, convert initial uppercase to lowercase
    # (only occurs in five records for religious names) and make sure
    # only the allowed lowercase letters and diacritic letters are used
    for my $fv (@pnys) {
      if ($fv =~ /\A[A-Z][^A-Z]*\z/) {
        $fv =~ tr/A-Z/a-z/;
      }
      
      for my $c (split //, $fv) {
        my $cpv = ord($c);
        ((($cpv >= ord('a')) and ($cpv <= ord('z'))) or
          ($cpv == 0xe0) or ($cpv == 0xe1) or
          ($cpv == 0xe8) or ($cpv == 0xe9) or
          ($cpv == 0xec) or ($cpv == 0xed) or
          ($cpv == 0xf2) or ($cpv == 0xf3) or
          ($cpv == 0xf9) or ($cpv == 0xfa) or
          ($cpv == 0x101) or ($cpv == 0x113) or ($cpv == 0x12b) or
            ($cpv == 0x14d) or ($cpv == 0x16b) or
          ($cpv == 0x1ce) or ($cpv == 0x11b) or ($cpv == 0x1d0) or
            ($cpv == 0x1d2) or ($cpv == 0x1d4) or
          ($cpv == 0xfc) or ($cpv == 0x1d6) or ($cpv == 0x1d8) or
            ($cpv == 0x1da) or ($cpv == 0x1dc)) or
          die "File $vlevel line $lnum: Invalid pinyin char, stopped";
      }
    }
    
    # Go through all the Word classes and make sure only ASCII letters
    # and hyphen are used, and that first character is letter; also,
    # normalize case within word classes, so that all word classes begin
    # with uppercase letter and any remaining characters are lowercase
    for my $fv (@wcs) {
      # Check format and split into prefix and suffix
      ($fv =~ /\A([A-Za-z])([A-Za-z\-]*)\z/) or
        die "File $vlevel line $lnum: Invalid class char, stopped";
      my $prefix = $1;
      my $suffix = $2;
      
      # Uppercase prefix and lowercase suffix
      $prefix =~ tr/a-z/A-Z/;
      $suffix =~ tr/A-Z/a-z/;
      
      # Update word class with normalized form
      $fv = $prefix . $suffix;
    }
    
    # Make sure at least one headword and at least one Pinyin, but there
    # are records where there are no word classes
    ($#hws >= 0) or
      die "File $vlevel line $lnum: No headword, stopped";
    ($#pnys >= 0) or
      die "File $vlevel line $lnum: No Pinyin, stopped";
    
    # Make sure within each field there are no duplicate components
    # remaining
    for(my $i = 0; $i < 3; $i++) {
      # Get source array reference
      my $sa;
      if ($i == 0) {
        $sa = \@hws;
      } elsif ($i == 1) {
        $sa = \@pnys;
      } elsif ($i == 2) {
        $sa = \@wcs;
      } else {
        die "Unexpected";
      }
      
      # Check everything but the last
      for(my $j = 0; $j < scalar(@$sa) - 1; $j++) {
        # Check against all elements that follow this one
        for(my $k = $j + 1; $k < scalar(@$sa); $k++) {
          ($sa->[$j] ne $sa->[$k]) or
            die "File $vlevel line $lnum: Duplicate values, stopped";
        }
      }
    }
    
    # We are now ready to start importing the record; begin by adding
    # any new word classes that we have encountered
    for my $wcn (@wcs) {
      # Add if unrecognized
      if (not defined $wcm{$wcn}) {
        # Insert new value
        $dbh->do(
                'INSERT INTO wclass(wclassname) VALUES (?)',
                undef,
                $wcn);
        
        # Get ID of new value and add to our mapping
        my $qr = $dbh->selectrow_arrayref(
                  'SELECT wclassid FROM wclass WHERE wclassname=?',
                  undef,
                  $wcn);
        (ref($qr) eq 'ARRAY') or die "Unexpected";
        $wcm{$wcn} = $qr->[0];
      }
    }
    
    # We now have all word classes, so go through the word class list
    # and replace everything with the numeric ID value
    for my $wcv (@wcs) {
      $wcv = $wcm{$wcv};
    }
    
    # Determine new word ID as one greater than greatest existing, or
    # 1 if this is the first
    my $wordid = $dbh->selectrow_arrayref(
                    'SELECT wordid FROM word ORDER BY wordid DESC');
    if (ref($wordid) eq 'ARRAY') {
      $wordid = $wordid->[0] + 1;
    } else {
      $wordid = 1;
    }
    
    # Add a new word record
    $dbh->do('INSERT INTO word(wordid, wordlevel) VALUES (?, ?)',
              undef, $wordid, $vlevel);
    
    # Add all the han records, leaving the simplified values NULL
    for(my $i = 0; $i <= $#hws; $i++) {
      $dbh->do(
              'INSERT INTO han(wordid, hanord, hantrad) VALUES (?,?,?)',
              undef,
                $wordid,
                $i + 1,
                encode('UTF-8', $hws[$i],
                        Encode::FB_CROAK | Encode::LEAVE_SRC));
    }
    
    # Add all the Pinyin records
    for(my $i = 0; $i <= $#pnys; $i++) {
      $dbh->do(
              'INSERT INTO pny(wordid, pnyord, pnytext) VALUES (?,?,?)',
              undef,
                $wordid,
                $i + 1,
                encode('UTF-8', $pnys[$i],
                        Encode::FB_CROAK | Encode::LEAVE_SRC));
    }
    
    # Add all the word class records
    for(my $i = 0; $i <= $#wcs; $i++) {
      $dbh->do(
              'INSERT INTO wc(wordid, wcord, wclassid) VALUES (?,?,?)',
              undef,
                $wordid,
                $i + 1,
                $wcs[$i]);
    }
  }
  
  # Close the file
  close($fh);
}

# If we got here, commit all our changes as a single transaction
#
$dbc->finishWork;

=head1 AUTHOR

Noah Johnson, C<noah.johnson@loupmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 Multimedia Data Technology Inc.

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut

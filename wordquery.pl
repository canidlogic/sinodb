#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

wordquery.pl - List all information about particular words.

=head1 SYNOPSIS

  ./wordquery.pl 526 1116 2561 4195
  ./wordquery.pl -

=head1 DESCRIPTION

This script reports all information about words with given ID numbers.
You can either pass the ID numbers directly as one or more program
arguments, or you can pass C<-> as the sole argument and the script will
read the ID numbers from standard input, with one word ID per line
(especially useful as a pipeline target for other scripts).

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Switch output to UTF-8
#
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Handle the different invocations
#
my @word_list;
if (($#ARGV == 0) and ($ARGV[0] eq '-')) { # ===========================
  # Read from standard input
  my $line_num = 0;
  while (not eof(STDIN)) {
    # Increment line number
    $line_num++;
    
    # Read a line
    my $ltext;
    (defined($ltext = <STDIN>)) or die "I/O error, stopped";
    
    # Drop line break
    chomp $ltext;
    
    # Skip if blank
    (not ($ltext =~ /^\s*$/)) or next;
    
    # Parse word ID
    ($ltext =~ /^\s*[0-9]+\s*$/) or
      die "Line $line_num: Invalid input line, stopped";
    my $word_id = int($ltext);
    
    # Add to array
    push @word_list, ($word_id);
  }
  
} elsif ($#ARGV >= 0) { # ==============================================
  # Read directly from program arguments
  for my $arg (@ARGV) {
    # Check format and parse
    ($arg =~ /^[0-9]+$/) or
      die "Invalid argument: '$arg', stopped";
    my $word_id = int($arg);
    
    # Add to array
    push @word_list, ($word_id);
  }
  
} else { # =============================================================
  # No arguments, print syntax summary
  print { \*STDERR } q{Syntax:

  wordquery.pl [id_1] [id_2] ... [id_n]
  wordquery.pl -

Pass a sequence of word IDs, either directly or on standard input with
the second invocation
};
  exit;
}

# Make sure we got at least one word
#
($#word_list >= 0) or die "No word IDs given, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Report each word
#
for my $word_id (@word_list) {
  # Print header
  print "=== Word $word_id:\n\n";
  
  # Look up the basic word record
  my $qr = $dbh->selectrow_arrayref(
              'SELECT wordlevel FROM word WHERE wordid=?',
              undef,
              $word_id);
  
  # If word not found, report that and skip rest of processing
  unless (ref($qr) eq 'ARRAY') {
    print "No records found.\n\n";
    next;
  }
  
  # If we got here, we now know the word level, so report that
  print "Level $qr->[0]\n\n";
  
  # Report any word classes
  $qr = $dbh->selectall_arrayref(
              'SELECT wclassname, wclassfull '
              . 'FROM wc '
              . 'INNER JOIN wclass ON wclass.wclassid = wc.wclassid '
              . 'WHERE wc.wordid = ? '
              . 'ORDER BY wcord ASC',
              undef,
              $word_id);
  if ((ref($qr) eq 'ARRAY') and (scalar(@$qr) > 0)) {
    for my $r (@$qr) {
      printf "%-8s %s\n", $r->[0], $r->[1];
    }
    print "\n";
    
  } else {
    print "No word class information.\n\n";
  }
  
  # Get all Han readings as subarrays of hanid and traditional rendering
  my @hans;
  $qr = $dbh->selectall_arrayref(
              'SELECT hanid, hantrad '
              . 'FROM han WHERE wordid=? '
              . 'ORDER BY hanord ASC',
              undef,
              $word_id);
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @hans, ([
            $r->[0],
            decode('UTF-8', $r->[1],
                    Encode::FB_CROAK | Encode::LEAVE_SRC)
            ]);
    }
  }
  
  # Now print each Han reading and information relating to it
  for my $hra (@hans) {
    
    # Get Han id and Han traditional
    my $han_id   = $hra->[0];
    my $han_trad = $hra->[1];
    
    # Print traditional rendering first, without a line break
    print "  -- $han_trad";
    
    # Get all Pinyin readings of this traditional reading
    $qr = $dbh->selectall_arrayref(
                'SELECT pnytext FROM pny '
                . 'WHERE hanid=? ORDER BY pnyord ASC',
                undef,
                $han_id);
    
    # Print any Pinyin readings after the Han reading and finish the
    # line
    if ((ref($qr) eq 'ARRAY') and (scalar(@$qr) > 0)) {
      print " (";
      my $first = 1;
      for my $r (@$qr) {
        if ($first) {
          $first = 0;
        } else {
          print ", ";
        }
        my $pny = decode('UTF-8', $r->[0],
                          Encode::FB_CROAK | Encode::LEAVE_SRC);
        print "$pny";
      }
      print ")\n";
    } else {
      print "\n";
    }
    
    # Get all major definitions of this Han reading
    my @mopy;
    $qr = $dbh->selectall_arrayref(
                'SELECT mpyid, mpysimp, mpypny '
                . 'FROM mpy WHERE hanid=? ORDER BY mpyord ASC',
                undef,
                $han_id);
    if (ref($qr) eq 'ARRAY') {
      for my $r (@$qr) {
        push @mopy, ([
            $r->[0],
            decode('UTF-8', $r->[1],
                    Encode::FB_CROAK | Encode::LEAVE_SRC),
            decode('UTF-8', $r->[2],
                    Encode::FB_CROAK | Encode::LEAVE_SRC)]);
      }
    }
    
    # Print all major definitions
    if ($#mopy >= 0) {
      for my $mpa (@mopy) {
        # Get major ID, simplified rendering, and Pinyin
        my $mpy_id   = $mpa->[0];
        my $mpy_simp = $mpa->[1];
        my $mpy_pny  = $mpa->[2];
        
        # Print major definition header
        print "    + $han_trad|$mpy_simp $mpy_pny\n";
        
        # Get all glosses for this major definition
        $qr = $dbh->selectall_arrayref(
                  'SELECT dfnosen, dfntext '
                  . 'FROM dfn WHERE mpyid=? '
                  . 'ORDER BY dfnosen ASC, dfnogls ASC',
                  undef,
                  $mpy_id);
        if (ref($qr) eq 'ARRAY') {
          my $first_gloss = 1;
          my $current_sense = 1;
          for my $r (@$qr) {
            # Get ordering and gloss
            my $ord_sense = $r->[0];
            my $dfn_text  = decode('UTF-8', $r->[1],
                              Encode::FB_CROAK | Encode::LEAVE_SRC);
            
            # If we have moved to a new sense, line break and reset
            # first_gloss
            if ($ord_sense != $current_sense) {
              print "\n";
              $current_sense = $ord_sense;
              $first_gloss = 1;
            }
            
            # If first_gloss flag is on, turn it off; else, print gloss
            # separator
            if ($first_gloss) {
              $first_gloss = 0;
            } else {
              print "; ";
            }
            
            # Print the gloss
            print "$dfn_text";
          }
          print "\n\n";
        }
      }
      
    } else {
      print "\n";
    }
    
    # @@TODO:
  }
  
  # @@TODO:
  
}

# If we got here, commit the transaction
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

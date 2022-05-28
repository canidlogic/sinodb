#!/usr/bin/env perl
use strict;
use warnings;

=head1 NAME

dupscan.pl - Scan through the CC-CEDICT data file and report all groups
of entries that have the exact same traditional character headword AND
Pinyin (case sensitive).

=head1 SYNOPSIS

  ./dupscan.pl cedict.txt

=head1 DESCRIPTION

Scans through the CC-CEDICT data file at the given path twice.  The
first time, records a mapping of traditional character strings and
Pinyin to all line numbers they are used on.  Then, builds a list of
just line numbers that are involved in a duplicate group.  The second
pass, maps all these chosen line numbers to their lines.  Finally,
outputs the groups, with a blank line between groups.

=cut

# ==================
# Program entrypoint
# ==================

# Switch input and output to UTF-8 and CR+LF decoding
#
binmode(STDIN,  ":encoding(UTF-8) :crlf") or
  die "Failed to set UTF-8 input, stopped";
binmode(STDERR, ":encoding(UTF-8) :crlf") or
  die "Failed to set UTF-8 output, stopped";
binmode(STDOUT, ":encoding(UTF-8) :crlf") or
  die "Failed to set UTF-8 output, stopped";

# Get argument and check that it is file
#
($#ARGV == 0) or die "Wrong number of parameters, stopped";
my $dict_path = $ARGV[0];
(-f $dict_path) or die "Can't find file '$dict_path', stopped";

# Open input file in UTF-8 with CR+LF decoding
#
open(my $fh, "< :encoding(UTF-8) :crlf", $dict_path) or
  die "Can't open file '$dict_path', stopped";

# On the first pass, build mapping of traditional headwords and
# lowercased Pinyin to line numbers
#
my $lnum = 0;
my %tcm;
while (my $ltext = readline($fh)) {
  # Increase line number
  $lnum++;
  
  # Drop line break
  chomp $ltext;
  
  # If first line, drop any UTF-8 Byte Order Mark (BOM)
  if ($lnum == 1) {
    $ltext =~ s/\A\x{feff}\z//;
  }
  
  # Skip if blank or starts with #
  if (($ltext =~ /\A[ \t]*\z/) or ($ltext =~ /\A#/)) {
    next;
  }
  
  # Get traditional headword and Pinyin
  ($ltext =~ /\A([^ ]+) [^\[]*\[([^\]]*)\]/) or
    die "Invalid dictionary line '$ltext', stopped";
  my $hword = $1;
  my $pny   = $2;
  
  # Define key
  my $kval = "$hword $pny";
  
  # Add into mapping
  if (defined $tcm{$kval}) {
    # Already defined, so push line number to end of list
    push @{$tcm{$kval}}, ($lnum);
    
  } else {
    # Not already defined, so start list with this line number
    $tcm{$kval} = [$lnum];
  }
}

# Only interested in cases where more than one line, so drop everything
# else
#
my @del_key;
for my $k (keys %tcm) {
  if (scalar(@{$tcm{$k}}) <= 1) {
    push @del_key, ($k);
  }
}
for my $k (@del_key) {
  delete $tcm{$k};
}
@del_key = ( );

# Build hash of line numbers of interest, currently all mapped to 1
#
my %lh;
for my $k (keys %tcm) {
  for my $ln (@{$tcm{$k}}) {
    $lh{"$ln"} = 1;
  }
}

# Rewind input file to beginning
#
seek($fh, 0, 0) or die "Failed to rewind file, stopped";

# Go through input file again, this time storing all lines of interest
# within the line numbers of interest hash
#
$lnum = 0;
while (my $ltext = readline($fh)) {
  # Increase line number
  $lnum++;
  
  # Drop line break
  chomp $ltext;
  
  # If first line, drop any UTF-8 Byte Order Mark (BOM)
  if ($lnum == 1) {
    $ltext =~ s/\A\x{feff}\z//;
  }
  
  # If line number of interest, record line
  if (defined $lh{"$lnum"}) {
    $lh{"$lnum"} = $ltext;
  }
}

# Close input file
#
close($fh);

# For each group, print out all lines
#
my $first_group = 1;
for my $k (sort keys %tcm) {
  if ($first_group) {
    $first_group = 0;
  } else {
    print "\n";
  }
  
  for my $ln (@{$tcm{$k}}) {
    my $lv = $lh{"$ln"};
    print "$lv\n";
  }
}

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

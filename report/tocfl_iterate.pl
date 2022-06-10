#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::TOCFL;
use SinoConfig;

=head1 NAME

tocfl_iterate.pl - Iterate through all records in the TOCFL dataset.

=head1 SYNOPSIS

  ./tocfl_iterate.pl > results.txt

=head1 DESCRIPTION

This script iterates through all TOCFL records using the parser module
C<Sino::TOCFL>.  The parsed representation of each record is reported to
standard output.  This allows you to see how the TOCFL dataset is seen
from the perspective of the parser.

=cut

# ==================
# Program entrypoint
# ==================

# Set output to UTF-8
#
binmode(STDOUT, ':encoding(UTF-8)') or
  die "Failed to set UTF-8 output, stopped";

# Load TOCFL data files and rewind
#
my $tvl = Sino::TOCFL->load($config_tocfl);
$tvl->rewind;

# Step through all TOCFL records
#
my $first_rec = 1;
my $rec_count = 0;

while ($tvl->advance) {
  # Get fields of this record
  my @han_readings = $tvl->han_readings;
  my @pinyins      = $tvl->pinyin_readings;
  my @word_classes = $tvl->word_classes;
  my $word_level   = $tvl->word_level;
  my $line_number  = $tvl->line_number;
  
  # Increase record count
  $rec_count++;
  
  # Line break before record unless first
  if ($first_rec) {
    $first_rec = 0;
  } else {
    print "\n";
  }
  
  # Report record
  print "Record $rec_count, level $word_level, line $line_number\n";
  
  for my $wc (@word_classes) {
    print "  $wc";
  }
  print "\n";
  
  for my $han (@han_readings) {
    print "  $han";
  }
  print "\n";
  
  for my $pny (@pinyins) {
    print "  $pny";
  }
  print "\n";
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

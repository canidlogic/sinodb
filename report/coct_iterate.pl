#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::COCT;
use SinoConfig;

=head1 NAME

coct_iterate.pl - Iterate through all records in the COCT dataset.

=head1 SYNOPSIS

  ./coct_iterate.pl > results.txt

=head1 DESCRIPTION

This script iterates through all COCT records using the parser module
C<Sino::COCT>.  The parsed representation of each record is reported to
standard output.  This allows you to see how the COCT dataset is seen
from the perspective of the parser.

Records on the blocklist will be skipped by this iteration.  This is
because the blocklist is integrated within the C<Sino::COCT> module, so
this script gets the filtered results.

=cut

# ==================
# Program entrypoint
# ==================

# Set output to UTF-8
#
binmode(STDOUT, ':encoding(UTF-8)') or
  die "Failed to set UTF-8 output, stopped";

# Load COCT data files and rewind
#
my $cvl = Sino::COCT->load($config_coctpath, $config_datasets);
$cvl->rewind;

# Step through all COCT records
#
my $first_rec = 1;
my $rec_count = 0;

while ($cvl->advance) {
  # Get fields of this record
  my $word_level  = $cvl->word_level;
  my @hws         = $cvl->han_readings;
  my $line_number = $cvl->line_number;
  
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
  
  for my $hw (@hws) {
    print "  $hw\n";
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

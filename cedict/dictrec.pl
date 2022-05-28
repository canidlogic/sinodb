#!/usr/bin/env perl
use strict;
use warnings;

# Dict modules
use Dict::Parse;
use DictConfig;

=head1 NAME

dictrec.pl - Print out a record at a given line number within the
dictionary file.

=head1 SYNOPSIS

  ./dictrec.pl 56806

=head1 DESCRIPTION

Seeks to the dictionary record at the given line number within the
dictionary file and prints a formatted display of the parsed record.

Requires the C<Dict::Parse> module, so see that module for how to set up
an appropriate configuration file and so forth.

=cut

# ==================
# Program entrypoint
# ==================

# Switch output to UTF-8
#
binmode(STDERR, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Get and check program argument
#
($#ARGV == 0) or die "Expecting one program argument, stopped";
my $lnum = $ARGV[0];
($lnum =~ /\A[1-9][0-9]*\z/) or die "Invalid argument, stopped";
$lnum = int($lnum);

# Open the parser
#
my $dict = Dict::Parse->load($config_dictpath);

# Seek to desired line
#
$dict->seek($lnum);

# Read the record at this line
#
$dict->advance or die "Given line number beyond end of file, stopped";
($dict->line_number == $lnum) or
  die "No record at given line number, stopped";

# Report the traditional and simplified readings, and the pinyin
#
printf "Traditional: %s\n", $dict->traditional;
printf "Simplified : %s\n", $dict->simplified;
print  'Pinyin     :';
for my $py ($dict->pinyin) {
  print " $py";
}
print "\n";

# Print each sense block
#
for my $sense ($dict->senses) {
  print "\n";
  for my $gloss (@$sense) {
    print ": $gloss\n";
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

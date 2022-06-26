#!/usr/bin/env perl
use strict;
use warnings;

# Core imports
use Encode qw(decode);

# Sino imports
use Sino::DB;
use Sino::Op qw(han_query);
use SinoConfig;

=head1 NAME

hanscan.pl - Report the word IDs of all words that match a given Han
query.

=head1 SYNOPSIS

  ./hanscan.pl '4e00...?*'
  ./hanscan.pl -strict '4e00...?*'

=head1 DESCRIPTION

This script runs a Han headword query against the Sino database.  This
is a simple front-end for the C<han_query()> function of C<Sino::Op>.
See the documentation of that module for further information.

The output is a list of word IDs that match the keyword query.

The query format can contain Unicode Han characters, Han characters
encoded as sequences of exactly four base-16 digits, and the wildcards
C<*> and C<?>.  Encoding a Han character in base-16 versus supplying the
character directly is equivalent.

Normally, matching is I<loose>, meaning that simplified and traditional
variants of the same character are equivalent.  If you want strict
matching where characters only match themselves, include the C<-strict>
option.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Parse program arguments
#
my $match_mode = 'loose';

(($#ARGV == 0) or ($#ARGV == 1)) or
  die "Wrong number of program arguments, stopped";

if ($#ARGV == 1) {
  my $arg = shift @ARGV;
  ($arg eq '-strict') or die "Invalid program invocation, stopped";
  $match_mode = 'strict';
}

my $enc_query = shift @ARGV;
$enc_query = decode('UTF-8', $enc_query, Encode::FB_CROAK);

# Decode the query
#
my $query = '';
  
($enc_query =~ /\A(?:[0-9a-fA-F]{4}|[\x{4e00}-\x{9fff}]|\*|\?)+\z/) or
  die "Invalid query, stopped";

while ($enc_query =~ /([0-9a-fA-F]{4}|[\x{4e00}-\x{9fff}]|\*|\?)/g) {
  if (length($1) == 4) {
    $query = $query . chr(hex($1));
  } else {
    $query = $query . $1;
  }
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Perform the Han query
#
my %attrib = (
  match_style => $match_mode
);
my $results = han_query($dbc, $query, \%attrib);

# Print all the results
#
for my $result (@$results) {
  printf "%d\n", $result->[0];
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

#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use Sino::Op qw(keyword_query);
use SinoConfig;

=head1 NAME

wordscan.pl - Report the word IDs of all words that match a given
keyword query.

=head1 SYNOPSIS

  ./wordscan.pl 'husky sled-dog'

=head1 DESCRIPTION

This script runs a keyword query against the Sino database.  This is a
simple front-end for the C<keyword_query()> function of C<Sino::Op>.
See the documentation of that module for further information.

Since using apostrophes in command-line arguments may be an issue, this
script will replace C<!> characters in the keyword query with
apostrophes before it is processed.  This is not part of standard
keyword processing, but provided solely for this script as a workaround
for the awkwardness otherwise of using single-quoted arguments that must
include apostrophes.

The output is a list of word IDs that match the keyword query.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Get the keyword query
#
($#ARGV == 0) or die "Wrong number of program arguments, stopped";
my $query = $ARGV[0];

# Replace exclamation mark with apostrophe
#
$query =~ s/!/'/g;

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Perform the keyword query
#
my $results = keyword_query($dbc, $query, undef);

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

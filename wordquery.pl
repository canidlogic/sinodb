#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use Sino::Op qw(words_xml);
use SinoConfig;

=head1 NAME

wordquery.pl - List all information about particular words.

=head1 SYNOPSIS

  ./wordquery.pl 526 1116 2561 4195
  ./wordquery.pl

=head1 DESCRIPTION

This script reports all information about words with given ID numbers.
You can either pass the ID numbers directly as one or more program
arguments, or you can pass no arguments and the script will read the ID
numbers from standard input, with one word ID per line (especially
useful as a pipeline target for other scripts).

The information returned about the words is in the descriptive XML
format documented in the C<Sino::Op> module.

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

if ($#ARGV < 0) { # ====================================================
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
  
} else { # =============================================================
  # Read directly from program arguments
  for my $arg (@ARGV) {
    # Check format and parse
    ($arg =~ /^[0-9]+$/) or
      die "Invalid argument: '$arg', stopped";
    my $word_id = int($arg);
    
    # Add to array
    push @word_list, ($word_id);
  }
}

# Make sure we got at least one word
#
($#word_list >= 0) or die "No word IDs given, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Get the full XML report
#
my $xml = words_xml($dbc, \@word_list);

# Print the report
#
print $xml;

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

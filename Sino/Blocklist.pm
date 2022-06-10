package Sino::Blocklist;
use strict;

=head1 NAME

Sino::Blocklist - Manage the blocklist.

=head1 SYNOPSIS

  use Sino::Blocklist;
  use SinoConfig;
  
  # Load the blocklist
  my $bl = Sino::Blocklist->load($config_datasets);
  
  # Check whether all given headwords are in the blocklist
  if ($bl->blocked(\@hws)) {
    ...
  }

=head1 DESCRIPTION

Loads and manages queries to the blocklist.

It is recommended that you get the path to the dataset directory from
the <SinoConfig> module, as shown in the synopsis.

Once the blocklist is loaded, you can use the C<blocked> function to
check whether a record is blocked from its headwords.

The blocklist is only loaded once and then cached in memory.  All
instances of the blocklist class will share the same cache.

See C<config.md> in the C<doc> directory for configuration you must do
before using this module.

=cut

# ===============
# Blocklist cache
# ===============

# The blocklist cache is shared between all instances.
#
# blocklist_cache is a hash reference if the cache is loaded, or undef
# if the cache has not been loaded yet.
#
# The keys in the hash are the headwords that are blocked and the values
# are all 1.  The hash therefore acts like a set.
#
my $blocklist_cache = undef;

# ===============
# Local functions
# ===============

# parse_blocklist($config_datasets)
#
# Given the path to the datasets directory, read the full blocklist file
# and return a hash reference where the keys are the headwords in the
# blocklist and the values are all one.
#
# This function does not make use of the blocklist cache, so it actually
# loads the blocklist each time it is called.
#
sub parse_blocklist {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $datasets_folder = shift;
  (not ref($datasets_folder)) or die "Wrong parameter type, stopped";
  
  # Get the path to the full blocklist
  my $blocklist_path = $datasets_folder . "blocklist.txt";
  
  # Make sure blocklist file exists
  (-f $blocklist_path) or
    die "Can't find blocklist '$blocklist_path', stopped";
  
  # Open blocklist for reading in UTF-8 and CR+LF translation mode
  open(my $fh, "< :encoding(UTF-8) :crlf", $blocklist_path) or
    die "Can't open blocklist file '$blocklist_path', stopped";
  
  # Read all records into a hash
  my %blocklist;
  my $lnum = 0;
  while (not eof($fh)) {
    
    # Increment line number
    $lnum++;
    
    # Read a line
    my $ltext = readline($fh);
    (defined $ltext) or die "I/O error, stopped";
    
    # Drop line breaks
    chomp $ltext;
    
    # If this is first line, drop any UTF-8 BOM
    if ($lnum == 1) {
      $ltext =~ s/\A\x{feff}//;
    }
    
    # Ignore blank lines
    (not ($ltext =~ /\A\s*\z/)) or next;
    
    # Drop leading and trailing whitespace
    $ltext =~ s/\A\s+//;
    $ltext =~ s/\s+\z//;
    
    # Make sure we just have a sequence of one or more Letter_other
    # category codepoints remaining
    ($ltext =~ /\A[\p{Lo}]+\z/) or
      die "Blocklist line $lnum: Invalid record, stopped";
    
    # Add to blocklist
    $blocklist{$ltext} = 1;
  }
  
  # Close blocklist file
  close($fh);
  
  # Return reference to blocklist
  return \%blocklist;
}

=head1 CONSTRUCTOR

=over 4

=item B<load(dataset_path)>

Construct a new blocklist object.

C<dataset_path> is the path to the directory containing Sino
supplemental datasets.  This path must end with a directory separator
slash.  The blocklist file C<blocklist.txt> will be loaded from this
directory.  Normally, you get this dataset path from the C<SinoConfig>
module, as shown in the synopsis.

If the blocklist has already been loaded by some other instance of this
object, this constructor will just use that shared instance rather than
reloading another copy of the blocklist.

=cut

sub load {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameter
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $dataset_paths = shift;
  (not ref($dataset_paths)) or die "Wrong parameter type, stopped";
  
  # If the blocklist has not been cached yet, cache it
  unless (defined $blocklist_cache) {
    $blocklist_cache = parse_blocklist($dataset_paths);
    (defined $blocklist_cache) or die "Unexpected";
  }
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_bl' property will store a hash reference to the shared
  # blocklist cache
  $self->{'_bl'} = $blocklist_cache;
  
  # Return the new object
  return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item B<blocked(\@hws)>

Given an array reference, check whether all headwords in the array are
present within the blocklist.

1 is returned if I<all> headwords are blocked, 0 otherwise.

The passed array reference may not be empty or a fatal error occurs.

=cut

sub blocked {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self and parameter
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $hws = shift;
  (ref($hws) eq 'ARRAY') or die "Wrong parameter type, stopped";
  
  (scalar(@$hws) > 0) or die "Empty parameter, stopped";
  for my $e (@$hws) {
    (not ref($e)) or die "Wrong parameter type, stopped";
  }
  
  # Start with block flag set
  my $block_flag = 1;
  
  # If any headwords are not on the blocklist, clear the flag
  for my $e (@$hws) {
    unless (defined $self->{'_bl'}->{$e}) {
      $block_flag = 0;
      last;
    }
  }
  
  # Return the resulting block flag
  return $block_flag;
}

=back

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

# End with something that evaluates to true
#
1;

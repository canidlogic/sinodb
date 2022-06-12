package Sino::COCT;
use strict;

# Sino modules
use Sino::Blocklist;
use Sino::Multifile;
use Sino::Util qw(parse_multifield);

=head1 NAME

Sino::COCT - Parse through the COCT data file.

=head1 SYNOPSIS

  use Sino::COCT;
  use SinoConfig;
  
  # Open the data file
  my $cvl = Sino::COCT->load($config_coctpath, $config_datasets);
  
  # (Re)start an iteration through the dataset
  $cvl->rewind;
  
  # Get current line number, or 0 if Beginning Of File (BOF)
  my $lnum = $cvl->line_number;
  
  # Read each COCT record
  while ($cvl->advance) {
    my $word_level = $cvl->word_level;
    my @hws        = $cvl->han_readings;
    ...
  }

=head1 DESCRIPTION

Module that opens and allows for parsed iteration through the COCT data
file.  It is recommended that you get the path to the data files from
the <SinoConfig> module, as shown in the synopsis.

See the synopsis for parsing operation.  This module only stores a
single entry in memory at a time, so it should have no trouble handling
large data files.

See C<config.md> in the C<doc> directory for configuration you must do
before using this module.

=cut

=head1 CONSTRUCTOR

=over 4

=item B<load(data_path, dataset_path)>

Construct a new COCT parser object.  C<data_path> is the path to the CSV
file storing the COCT data.  Normally, you get this path from the
C<SinoConfig> module, as shown in the synopsis.

C<dataset_path> is the path to the directory containing Sino
supplemental datasets.  This is passed through and used to get an
instance of C<Sino::Blocklist>.  See that module for further details.
Normally, you get this path from the C<SinoConfig> module, as shown in
the synopsis.

A read-only file handle to the COCT data file is kept open while the
object is constructed.  Undefined behavior occurs if the data file
changes while a parser object is opened.  The destructor of the internal
file reader object will close the file handle automatically.

This constructor does not actually read anything from the file yet.

=cut

sub load {
  
  # Check parameter count
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameters
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $data_path = shift;
  (not ref($data_path)) or die "Wrong parameter types, stopped";
  
  my $dataset_path = shift;
  (not ref($dataset_path)) or die "Wrong parameter types, stopped";
  
  # Get a blocklist instance
  my $bl = Sino::Blocklist->load($dataset_path);
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_mr' property will store a Sino::Multifile that iterates
  # through the COCT data file
  $self->{'_mr'} = Sino::Multifile->load([$data_path]);
  
  # The '_bl' property stores the blocklist object
  $self->{'_bl'} = $bl;
  
  # The '_state' property will be -1 for BOS, 0 for record, 1 for EOS
  $self->{'_state'} = -1;
  
  # When '_state' is 0, '_rec' stores the fields of the record just read
  $self->{'_rec'} = { };
  
  # Return the new object
  return $self;
}

=back

=head1 INSTANCE METHODS

=cut

# ========================
# Private instance methods
# ========================

# _force_advance()
#
# Has the same interface as the public advance() method, except that it
# does not consult the blocklist.
#
# The public advance() method is a wrapper around this private instance,
# which skips over results that are on the blocklist.
#
sub _force_advance {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Handle special state -- if we are already EOS, then just return
  # false without proceeding further
  if ($self->{'_state'} > 0) {
    # EOS
    return 0;
  }
  
  # Read lines from the multifile until we get one that is not blank, or
  # we hit End Of Stream (EOS)
  my $ltext = undef;
  while ($self->{'_mr'}->advance) {
    $ltext = $self->{'_mr'}->text;
    if ($ltext =~ /\A\s*\z/) {
      # Blank line
      $ltext = undef;
    } else {
      # Not a blank line
      last;
    }
  }
  
  # If we hit EOS, then update state to EOS and return false
  unless (defined $ltext) {
    # EOS reached
    $self->{'_state'} =   1;
    $self->{'_rec'  } = { };
    return 0;
  }
  
  # Get line number for diagnostic messages
  my $dline  = $self->{'_mr'}->line_number;
  
  # Parse line into two fields separated by a comma
  ($ltext =~ /\A([^,]+),([^,]+)\z/) or
    die "COCT line $dline has invalid record format, stopped";
  
  my $wlevel = $1;
  my $wvals  = $2;
  
  # Whitespace-trim word level and make sure it is an unsigned decimal
  # integer, then parse it
  $wlevel =~ s/\A\s+//;
  $wlevel =~ s/\s+\z//;
  ($wlevel =~ /\A[0-9]+\z/) or
    die "COCT line $dline has invalid word level field, stopped";
  $wlevel = int($wlevel);
  
  # Parse the record value as a multifield into headwords
  my @hws;
  eval {
    @hws = parse_multifield($wvals);
  };
  if ($@) {
    die "COCT line $dline headwords: $@";
  }
  
  # Drop any ASCII decimal integer suffixes from the end of headwords
  for my $hw (@hws) {
    $hw =~ s/\A([^0-9\s]+)\s*[0-9]+\z/$1/;
  }
  
  # Go through all the headwords and make sure only characters in the
  # main Unicode CJK block are used
  for my $fv (@hws) {
    ($fv =~ /\A[\x{4e00}-\x{9fff}]+\z/) or
      die "COCT line $dline: Invalid headword char, stopped";
  }
  
  # Make sure at least one headword
  ($#hws >= 0) or
    die "COCT line $dline: No headwords, stopped";
  
  # If we got here, then update state and return true
  $self->{'_state'} = 0;
  $self->{'_rec'  } = {
    wlevel => $wlevel,
    hws    => \@hws
  };
  
  return 1;
}

=over 4

=item B<rewind()>

Rewind the data file back to the beginning of the COCT dataset and
change the state of this parser to Beginning Of Stream (BOS).  This is
also the initial state of the parser object after construction.  No
record is currently loaded after calling this function.

=cut

sub rewind {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Rewind the underlying multifile
  $self->{'_mr'}->rewind;
  
  # Clear state to BOS
  $self->{'_state'  } =  -1;
  $self->{'_rec'    } = { };
}

=item B<line_number()>

Get the current line number in the COCT data file.  After construction
and also immediately following a rewind, this function will return zero.
After an advance operation that returns true, this will return the line
number of the record that was just read (where the first line is 1). 
After an advance operation that returns false, this will return zero.

=cut

sub line_number {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return line number from underlying multifile
  return $self->{'_mr'}->line_number;
}

=item B<advance()>

Read and parse a record from the data file.

Each call to this function loads a new record.  Note that when the
parser object is initially constructed, and also immediately following
a rewind operation, no record is loaded, so you must call this function
I<before> reading the first record in the dataset.

The return value is 1 if a new record was loaded, 0 if we have reached
End Of Stream (EOS) in the data file.  Once EOS is reached, subsequent
calls to this function will return EOS until a rewind operation is
performed.

Fatal errors occur if this function encounters a COCT record line that
it can't successfully parse.

The blocklist is consulted, and any COCT records for which I<all> 
headwords are on the blocklist will be silently skipped over by this
function.

=cut

sub advance {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Keep calling the internal advance function until we get a record
  # that is not blocked or we reach EOS
  my $retval;
  for($retval = $self->_force_advance;
      $retval;
      $retval = $self->_force_advance) {
    
    # We just loaded a new record; if the record is not on the
    # blocklist, then leave the loop
    unless ($self->{'_bl'}->blocked($self->{'_rec'}->{'hws'})) {
      last;
    }
  }
  
  # Pass through the return value we arrived at
  return $retval;
}

=item B<word_level()>

Get the COCT word level that we are currently examining.

B<Note:> COCT level 1 corresponds to TOCFL level 2, COCT level 2
corresponds to TOCFL level 3, and so forth.  The last COCT level is
beyond the last TOCFL level.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of Stream
(BOS) or End Of Stream (EOS) state.

=cut

sub word_level {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return $self->{'_rec'}->{'wlevel'};
}

=item B<han_readings()>

Return all the Han headwords for this record as an array in list
context.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of Stream
(BOS) or End Of Stream (EOS) state.

=cut

sub han_readings {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return @{$self->{'_rec'}->{'hws'}};
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

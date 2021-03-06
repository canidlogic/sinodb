package Sino::TOCFL;
use strict;

# UTF-8 used for extended characters in Pinyin in string literals.
#
use utf8;

# Sino modules
use Sino::Blocklist;
use Sino::Multifile;
use Sino::Util qw(parse_multifield match_pinyin tocfl_pinyin);

=head1 NAME

Sino::TOCFL - Parse through the TOCFL data files.

=head1 SYNOPSIS

  use Sino::TOCFL;
  use SinoConfig;
  
  # Open the data files
  my $tvl = Sino::TOCFL->load($config_tocfl, $config_datasets);
  
  # (Re)start an iteration through the dataset
  $tvl->rewind;
  
  # Get current vocabulary level
  my $level = $tvl->word_level;
  
  # Get current line number, or 0 if Beginning Of File (BOF)
  my $lnum = $tvl->line_number;
  
  # Read each TOCFL record
  while ($tvl->advance) {
    # Get record fields
    my @word_classes = $tvl->word_classes;
    my $word_level   = $tvl->word_level;
    my @entries      = $tvl->entries;
    
    # Iterate through all entries for this record
    for my $entry (@entries) {
      my $han_reading = $entry->[0];
      for my $pinyin (@{$entry->[1]}) {
        ...
      }
    }
  }

=head1 DESCRIPTION

Module that opens and allows for parsed iteration through the TOCFL data
files.  It is recommended that you get the path to the data files from
the <SinoConfig> module, as shown in the synopsis.

See the synopsis for parsing operation.  This module only stores a
single entry in memory at a time, so it should have no trouble handling
large data files.

See C<config.md> in the C<doc> directory for configuration you must do
before using this module.

=cut

# =========
# Constants
# =========

# Correction list that is used to add a few missing Pinyin abbreviated
# forms.
#
# This list only applies when there is exactly one Pinyin and exactly
# two headwords in the original record.
#
# The key is the Pinyin that must match in the original record.  This
# Pinyin is already normalized.
#
# The value is an array of two elements.  The first element is a string
# storing the missing Pinyin abbreviation that must be added to the
# Pinyin for this record.  The second element is 1 if the missing
# abbreviation should be added after the existing Pinyin element, or 0
# if it should be added before.
#
my %PNY_ABBREV = (
  'sh??ngy??n' => ['sh??ng', 1],
  'b??ozh??ng' => ['zh??ng', 1],
  'b??zh??'    => ['b??'   , 0],
  'f??ngw??n'  => ['f??ng' , 1],
  'g??j??'     => ['j??'   , 1],
  'ji??nji??n' => ['ji??n' , 1],
  'm??m??'     => ['m??'   , 1]
);

=head1 CONSTRUCTOR

=over 4

=item B<load(data_paths, dataset_path)>

Construct a new TOCFL parser object.  C<data_paths> is an array
reference to the paths to seven CSV files storing the TOCFL data, sorted
in increasing level of word difficulty.  Normally, you get this array
reference from the C<SinoConfig> module, as shown in the synopsis.

C<dataset_path> is the path to the directory containing Sino
supplemental datasets.  This is passed through and used to get an
instance of C<Sino::Blocklist>.  See that module for further details.
Normally, you get this path from the C<SinoConfig> module, as shown in
the synopsis.

Read-only file handles to the data files are kept open while the object
is constructed.  Undefined behavior occurs if the data files change 
while a parser object is opened.  The destructor of the internal file
reader object will close the file handles automatically.

This constructor does not actually read anything from the files yet.

=cut

sub load {
  
  # Check parameter count
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameters
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $data_paths = shift;
  (ref($data_paths) eq 'ARRAY') or die "Wrong parameter types, stopped";
  (scalar(@$data_paths) == 7) or die "Wrong parameter types, stopped";
  
  for my $path (@$data_paths) {
    (not ref($path)) or die "Wrong parameter typest, stopped";
    (-f $path) or die "Can't find TOCFL file '$path', stopped";
  }
  
  my $dataset_path = shift;
  (not ref($dataset_path)) or die "Wrong parameter types, stopped";
  
  # Get a blocklist instance
  my $bl = Sino::Blocklist->load($dataset_path);
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_mr' property will store a Sino::Multifile that can iterate
  # through all the TOCFL files
  $self->{'_mr'} = Sino::Multifile->load($data_paths);
  
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
  
  # Get level number and line number for diagnostic messages
  my $dlevel = $self->{'_mr'}->file_index + 1;
  my $dline  = $self->{'_mr'}->line_number;
  
  # We got a record line, so begin by normalizing variant parentheses
  # into ASCII parentheses
  $ltext =~ s/\x{ff08}/\(/g;
  $ltext =~ s/\x{ff09}/\)/g;
  
  # Drop ZWSP
  $ltext =~ s/\x{200b}//g;
  
  # Replace variant lowercase a with ASCII lowercase a
  $ltext =~ s/\x{251}/a/g;
  
  # Replace lowercase breves with lowercase carons
  $ltext =~ s/\x{103}/\x{1ce}/g;
  $ltext =~ s/\x{12d}/\x{1d0}/g;
  $ltext =~ s/\x{14f}/\x{1d2}/g;
  $ltext =~ s/\x{16d}/\x{1d4}/g;
  
  # Make sure no ? character used
  (not ($ltext =~ /\?/)) or
    die "TOCFL $dlevel line $dline: Invalid ? character, stopped";
  
  # If row ends with a comma and optional whitespace, insert a ? at
  # end so we still split properly
  $ltext =~ s/,[ \t]*\z/,\?/;
  
  # Parse into three or four fields with comma separator
  my @rec = split /,/, $ltext;
  (($#rec == 2) or ($#rec == 3)) or
    die "TOCFL $dlevel line $dline: Wrong number of fields, stopped";
  
  # If we got four fields, the first is the optional word topic, which
  # we will not be including, so drop it
  if ($#rec == 3) {
    shift @rec;
  }
  
  # If last field is the special ? we inserted, change to blank
  $rec[2] =~ s/\A[ \t]*\?[ \t]*\z//;
  
  # For each field, trim leading and trailing whitespace, then drop
  # leading and trailing quotes if present, then trim leading and
  # trailing whitespace again
  for my $fv (@rec) {
    $fv =~ s/\A[ \t]*(?:["'][ \t]*)?//;
    $fv =~ s/(?:[ \t]*["'])?[ \t]*\z//;
  }

  # Drop Bopomofo parentheticals and empty parentheticals in headword
  # and whitespace trim once again
  $rec[0] =~ s/\([ \t\x{2ca}-\x{2d9}\x{3100}-\x{3129}]*\)//g;
  $rec[0] =~ s/\A[ \t]+//;
  $rec[0] =~ s/[ \t+]\z//;
  
  # Make sure we don't have any parentheticals within the word classes
  # field
  (not ($rec[2] =~ /[\(\)]/)) or
    die "TOCFL $dlevel line $dline: Parenthetical word class, stopped";
  
  # Define the arrays that will store the headwords, the pinyin
  # readings, and the word classes
  my @hws;
  my @pnys;
  my @wcs;
  
  # Parse each of the multifields, but leave word classes empty if the
  # string is blank, for empty word classes ARE allowed
  eval {
    @hws = parse_multifield($rec[0]);
  };
  if ($@) {
    die "TOCFL $dlevel line $dline headwords: $@";
  }
  
  eval {
    @pnys = parse_multifield($rec[1]);
  };
  if ($@) {
    die "TOCFL $dlevel line $dline pinyins: $@";
  }
  
  unless ($rec[2] =~ /\A\s*\z/) {
    eval {
      @wcs = parse_multifield($rec[2]);
    };
    if ($@) {
      die "TOCFL $dlevel line $dline word classes: $@";
    }
  }
  
  # Go through all the headwords and make sure only characters in the
  # main Unicode CJK block are used
  for my $fv (@hws) {
    ($fv =~ /\A[\x{4e00}-\x{9fff}]+\z/) or
      die "File $dlevel line $dline: Invalid headword char, stopped";
  }
  
  # Go through all the Pinyin and normalize each entry
  for my $fv (@pnys) {
    eval {
      $fv = tocfl_pinyin($fv);
    };
    if ($@) {
      die "File $dlevel line $dline pinyin: $@";
    }
  }
  
  # Go through all the Word classes and make sure only ASCII letters and
  # hyphen are used, and that first character is letter; also, normalize
  # case within word classes, so that all word classes begin with
  # uppercase letter and any remaining characters are lowercase
  for my $fv (@wcs) {
    # Check format and split into prefix and suffix
    ($fv =~ /\A([A-Za-z])([A-Za-z\-]*)\z/) or
      die "File $dlevel line $dline: Invalid class char, stopped";
    my $prefix = $1;
    my $suffix = $2;
    
    # Uppercase prefix and lowercase suffix
    $prefix =~ tr/a-z/A-Z/;
    $suffix =~ tr/A-Z/a-z/;
    
    # Update word class with normalized form
    $fv = $prefix . $suffix;
  }
  
  # Make sure at least one headword and at least one Pinyin, but there
  # are records where there are no word classes
  ($#hws >= 0) or
    die "File $dlevel line $dline: No headword, stopped";
  ($#pnys >= 0) or
    die "File $dlevel line $dline: No Pinyin, stopped";
  
  # Make sure within each field there are no duplicate components
  # remaining
  for(my $i = 0; $i < 3; $i++) {
    # Get source array reference
    my $sa;
    if ($i == 0) {
      $sa = \@hws;
    } elsif ($i == 1) {
      $sa = \@pnys;
    } elsif ($i == 2) {
      $sa = \@wcs;
    } else {
      die "Unexpected";
    }
    
    # Check everything but the last
    for(my $j = 0; $j < scalar(@$sa) - 1; $j++) {
      # Check against all elements that follow this one
      for(my $k = $j + 1; $k < scalar(@$sa); $k++) {
        ($sa->[$j] ne $sa->[$k]) or
          die "File $dlevel line $dline: Duplicate values, stopped";
      }
    }
  }
  
  # If we have exactly one Pinyin and exactly two headwords, check if we
  # need to add a missing Pinyin abbreviated form and add it if
  # necessary
  if (($#hws == 1) and ($#pnys == 0)) {
    if (defined $PNY_ABBREV{$pnys[0]}) {
      # We need to add an abbreviation, so get the abbreviation
      my $abbrev = $PNY_ABBREV{$pnys[0]}->[0];
      
      # Based on the flag, add this abbreviation either after or before
      # the current Pinyin abbreviation
      if ($PNY_ABBREV{$pnys[0]}->[1]) {
        push @pnys, ($abbrev);
      } else {
        unshift @pnys, ($abbrev);
      }
    }
  }
  
  # Use intelligent matching to figure out which Pinyin goes with which
  # headwords
  my @matches;
  eval {
    @matches = match_pinyin(\@hws, \@pnys);
  };
  if ($@) {
    die "File $dlevel line $dline: $@";
  }
  
  # If we got here, then update state and return true
  $self->{'_state'} = 0;
  $self->{'_rec'  } = {
    matches => \@matches,
    wcs     => \@wcs
  };
  
  return 1;
}

=over 4

=item B<rewind()>

Rewind the data files back to the beginning of the whole TOCFL dataset
and change the state of this parser to Beginning Of Stream (BOS).  This
is also the initial state of the parser object after construction.  No
record is currently loaded after calling this function.

This rewinds all the way back to the start of the first vocabulary
level, regardless of which vocabulary level you are currently on.

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

=item B<word_level()>

Get the TOCFL word level that we are currently examining.  This property
is always available, even if a record is not currently loaded.  The
line_number() is located within the file indicated by this level.

The TOCFL word levels are 1-7, where 1 and 2 are Novice1 and Novice2,
and 3-7 are Level1-Level5.

=cut

sub word_level {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return one greater than the current file index of the underlying
  # multifile
  return $self->{'_mr'}->file_index + 1;
}

=item B<line_number()>

Get the current line number in the current vocabulary file.  After
construction and also immediately following a rewind, this function will
return zero.  After an advance operation that returns true, this will
return the line number of the record that was just read (where the first
line is 1).  After an advance operation that returns false, this will
return zero.

The line number is the line number within the current vocabulary level
file, as returned by word_level().

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

Read and parse a record from the data files.

Each call to this function loads a new record.  Note that when the
parser object is initially constructed, and also immediately following
a rewind operation, no record is loaded, so you must call this function
I<before> reading the first record in the dataset.

The return value is 1 if a new record was loaded, 0 if we have reached
End Of Stream (EOS) in the last vocabulary level.  Once EOS is reached,
subsequent calls to this function will return EOS until a rewind
operation is performed.

This function will read through the vocabulary levels from easiest to
most difficult, without any interruption between the levels.  The
function word_level() can be used to check which level has just been
read after a successful call to advance().

Fatal errors occur if this function encounters a TOCFL record line that
it can't successfully parse.

The blocklist is consulted, and any TOCFL records for which I<all>
headwords are on the blocklist will be silently skipped over by this
function.  Also, some corrections are transparently applied, as
described in C<TOCFL.md> and C<pinyin.md>.

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
    
    # We just loaded a new record; get a list of all the headwords
    my @hws;
    for my $match (@{$self->{'_rec'}->{'matches'}}) {
      push @hws, ($match->[0]);
    }
    
    # If the record is not on the blocklist, then leave the loop
    unless ($self->{'_bl'}->blocked(\@hws)) {
      last;
    }
  }
  
  # Pass through the return value we arrived at
  return $retval;
}

=item B<word_classes()>

Return all the word classes for this record as an array in list context.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of Stream
(BOS) or End Of Stream (EOS) state.

=cut

sub word_classes {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return @{$self->{'_rec'}->{'wcs'}};
}

=item B<entries()>

Return all the entries for this record as an array in list context.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of Stream
(BOS) or End Of Stream (EOS) state.

There is at least one entry for each word.  Each entry is an array
reference to an array of two elements.  The first element in the array
is a string containing the headword for the entry.  The second element
in the array is a subarray reference to a non-empty subarray storing all
the Pinyin readings for this headword.  Pinyin has already been
normalized into standard form with the C<tocfl_pinyin()> function of
C<Sino::Util>.

Everything returned from this function is a copy, so that changing
anything that was returned will not affect the internal state of the
parser.  This also means that you shouldn't call this function
excessively, since each call makes a new copy of everything.

=cut

sub entries {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Make a copy of the matches array
  my @results;
  for my $match (@{$self->{'_rec'}->{'matches'}}) {
    my $head_word = $match->[0];
    my @pny_array = map { $_ } @{$match->[1]};
    push @results, ([$head_word, \@pny_array]);
  }
  
  # Return copy of the matches array
  return @results;
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

package Sino::Dict;
use strict;

# Sino modules
use Sino::Multifile;
use Sino::Util qw(
                cedict_pinyin
                parse_measures
                extract_pronunciation
                extract_xref
                parse_cites);

=head1 NAME

Sino::Dict - Parse through the CC-CEDICT data file.

=head1 SYNOPSIS

  use Sino::Dict;
  use SinoConfig;
  
  # Open the data file
  my $dict = Sino::Dict->load($config_dictpath, $config_datasets);
  
  # (Re)start an iteration through the dictionary
  $dict->rewind;
  
  # Get current line number, or 0 if Beginning Of File (BOF)
  my $lnum = $dict->line_number;
  
  # You can quickly start reading at a specific line like this
  $dict->seek($lnum);
  
  # Read each dictionary record (skipping blank and comments)
  while ($dict->advance) {
    # Traditional and simplified headwords, already decoded in Unicode
    my $trad = $dict->traditional;
    my $simp = $dict->simplified;
    
    # Pinyin or undef if couldn't normalize
    my $pinyin = $dict->pinyin;
    
    # Record-level annotations
    my $rla = $dict->main_annote;
    for my $measure ($rla->{'measures'}) {
      my $trad = $measure->[0];
      my $simp = $measure->[1];
      my $pny;
      if (scalar(@$measure) >= 3) {
        $pny = $measure->[2];
      }
      ...
    }
    for my $pr ($rla->{'pronun'}) {
      my $pr_context = $pr->[0];
      for my $pny (@{$pr->[1]}) {
        ...
      }
      my $pr_condition = $pr->[2];
      ...
    }
    for my $xref ($rla->{'xref'}) {
      my $xr_description = $xref->[0];
      my $xr_type        = $xref->[1];
      for my $xrr (@{$xref->[2]}) {
        my $trad = $xrr->[0];
        my $simp = $xrr->[1];
        my $pny;
        if (scalar(@$xrr) >= 3) {
          $pny = $xrr->[2];
        }
      }
      my $xr_suffix      = $xref->[3];
    }
    
    # Entries
    for my $entry (@{$dict->entries}) {
      my $sense_number = $entry->{'sense'};
      my $gloss_text   = $entry->{'text'};
      my $cites        = $entry->{'cites'};
      for my $cite (@$cites) {
        # Within $gloss_text:
        my $starting_index = $cite->[0];
        my $cite_length    = $cite->[1];
        my $cite_trad      = $cite->[2];
        my $cite_simp      = $cite->[3];
        my $cite_pny;
        if (scalar(@$cite) >= 5) {
          $cite_pny = $cite->[4];
        }
      }
      
      # These properties same as the record-level annotation format
      my $gla_measures = $entry->{'measures'};
      my $gla_pronuns  = $entry->{'pronun'};
      my $gla_xrefs    = $entry->{'xref'};
    }
  }

=head1 DESCRIPTION

Module that opens and allows for parsed iteration through the CC-CEDICT
data file.  It is recommended that you get the path to the CC-CEDICT
dictionary file from the <SinoConfig> module, as shown in the synopsis.

See the synopsis for parsing operation.  This module only stores a
single entry in memory at a time, so it should have no trouble handling
the large data file.

See C<config.md> in the C<doc> directory for configuration you must do
before using this module.

=head1 CONSTRUCTOR

=over 4

=item B<load(data_path, dataset_path)>

Construct a new dictionary parser object.  C<data_path> is the path in
the local file system to the I<decompressed> CC-CEDICT data file.
Normally, you get this path from the C<SinoConfig> module, as shown in
the synopsis.

C<dataset_path> is the path to the directory containing Sino
supplemental datasets.  This path must end with a separator character so
that filenames can be directly appended to it.  This is used to get the
path to C<extradfn.txt> in that directory, which contains extra
definitions to consider added on to the end of the main dictionary file.
Normally, you get this path from the C<SinoConfig> module, as shown in
the synopsis.

An read-only file handle to the data files is kept open while the object
is constructed.  Undefined behavior occurs if the data files change
while a parser object is opened.  The destructor for the underlying
object managing the file handles will close the file handle
automatically.

This constructor does not actually read anything from the file yet.

=cut

sub load {
  
  # Check parameter count
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameter
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $data_path = shift;
  (not ref($data_path)) or die "Wrong parameter types, stopped";
  
  (-f $data_path) or die "Can't find file '$data_path', stopped";
  
  my $dataset_path = shift;
  (not ref($dataset_path)) or die "Wrong parameter types, stopped";
  
  my $supplement_path = $dataset_path . 'extradfn.txt';
  (-f $supplement_path) or
    die "Can't find file '$supplement_path', stopped";
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_mr' property will store a Sino::Multifile that iterates
  # through the CC-CEDICT data file and then the supplement
  $self->{'_mr'} = Sino::Multifile->load([
                          $data_path, $supplement_path]);
  
  # The '_state' property will be -1 for BOS, 0 for record, 1 for EOS
  $self->{'_state'} = -1;
  
  # When '_state' is 0, the '_rec' hash stores each of the properties
  # of the record that was just parsed; otherwise, it is an empty hash
  $self->{'_rec'} = { };
  
  # Return the new object
  return $self;
}

=back

=head1 INSTANCE METHODS

=over 4

=item B<rewind()>

Rewind the data file back to the beginning and change the state of this
parser to Beginning Of Stream (BOS).  This is also the initial state of
the parser object after construction.  No record is currently loaded
after calling this function.

This rewinds back to the very beginning of the main dictionary file,
even if you are currently in the supplement.

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

=item B<seek(n)>

Rewind the data file back to the beginning and skip to immediately
before a given line number, setting parser state to BOF.  Calling this
with a value of 1 is equivalent to calling the rewind function.  No
record is currently loaded after calling this function.

You can use negative values to select line numbers in the supplement.
-1 is the first line in the supplement, -2 is the second line, and so
forth.

First, this function performs a rewind operation.  Second, this function
reads zero or more lines until either the current line number advances
to one less than the given C<n> value, or EOS is reached.  When advance
is called, it will act as though the first line of the file were the
given line number.

C<n> must be an integer greater than zero or less than zero (if
selecting a line in the supplement).  Note that if advance successfully
reads a record, the line number of this record is I<not> necessarily the
same as the line selected by C<n>.  If C<n> refers to a comment line or
a blank line, advance will read the next line that is not a comment or
blank, or may even go to EOS.

This function is I<much> faster than just advancing over records,
because this function will not parse any of the lines it is skipping.

=cut

sub seek {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get self and parameter
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $n = shift;
  ((not ref($n)) and (int($n) == $n)) or
    die "Wrong parameter type, stopped";
  $n = int($n);
  (($n > 0) or ($n < 0)) or die "Parameter out of range, stopped";
  
  # Perform a rewind
  $self->rewind;
  
  # Main flag will be set to one by default, or cleared if we are
  # seeking into the supplement
  my $main_flag = 1;
  if ($n < 0) {
    $main_flag = 0;
  }
  
  # If n value is negative, then do a special rewindTo the start of the
  # supplement and set n to its absolute value
  if ($n < 0) {
    $self->{'_mr'}->rewindTo(1);
    $n = 0 - $n;
  }
  
  # If n is now 1, then we are in the correct position already, so do
  # nothing further
  if ($n == 1) {
    return;
  }
  
  # If we got here, then keep reading until either we are one less than
  # the desired line number OR we reach "end state"; end state is file
  # index no longer at zero if main flag is set, or EOS in underlying
  # multifile if main flag is clear
  my $found_it = 0;
  while (1) {
    # Begin by advancing to next line
    unless ($self->{'_mr'}->advance) {
      # We reached EOS, so leave loop
      last;
    }
    
    # If main flag is set and we reached the supplement, then leave loop
    if ($main_flag and ($self->{'_mr'}->file_index > 0)) {
      last;
    }
    
    # If we have reached one before desired n, then set found flag and
    # leave loop
    if ($self->{'_mr'}->line_number >= $n - 1) {
      $found_it = 1;
      last;
    }
  }
  
  # If we didn't find what we were looking for, keep reading until we
  # hit EOS
  unless ($found_it) {
    while ($self->{'_mr'}->advance) { }
  }
}

=item B<line_number()>

Get the current line number in the dictionary file.  After construction
and also immediately following a rewind, this function will return zero.
After an advance operation that returns true, this will return the line
number of the record that was just read (where the first line is 1).
After an advance operation that returns false, this will return the line
number of the last line in the file.

In the supplement file, line numbers will be negative.  -1 is first line
in supplement file, -2 is second line, and so forth.

=cut

sub line_number {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Determine line number
  my $result = $self->{'_mr'}->line_number;
  
  # If result is greater than zero and we are in supplement, make it
  # negative
  if (($result > 0) and ($self->{'_mr'}->file_index > 0)) {
    $result = 0 - $result;
  }
  
  # Return result
  return $result;
}

=item B<advance()>

Read and parse a record from the data file.

Each call to this function loads a new record.  Note that when the
parser object is initially constructed, and also immediately following
a rewind operation, no record is loaded, so you must call this function
I<before> reading the first record in the dictionary.

The return value is 1 if a new record was loaded, 0 if we have reached
End Of Stream (EOS).  Once EOS is reached, subsequent calls to this
function will return EOS until a rewind operation is performed.

This function will also seamlessly read through the supplement file
after reading through the main dictionary file.

=cut

sub advance {
  
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
  
  # Read lines from the multifile until we get one that is neither blank
  # nor a comment, or we hit End Of Stream (EOS)
  my $ltext = undef;
  while ($self->{'_mr'}->advance) {
    $ltext = $self->{'_mr'}->text;
    if ($ltext =~ /\A\s*\z/) {
      # Blank line
      $ltext = undef;
      
    } elsif ($ltext =~ /\A\s*#/) {
      # Comment line
      $ltext = undef;
      
    } else {
      # Not a blank line and not a comment
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
  
  # If we got here, then we have a record line; begin by storing the
  # line number for use in error reports
  my $lnum = $self->line_number;
  
  # Parse the basic structure of the record
  ($ltext =~ /\A
                  \s*
                (\S+)         # 1 - Traditional
                  \s+
                (\S+)         # 2 - Simplified
                  \s*
                  \[
                ([^\[\]]*)    # 3 - Pinyin
                  \]
                  \s*
                  \/
                (.*)          # 4 - Senses and glosses
                  \/
                  \s*
              \z/x) or
    die "Dictionary line $lnum: Invalid record format, stopped";
  
  my $trad   = $1;
  my $simp   = $2;
  my $pinyin = $3;
  my $defn   = $4;
  
  # Normalize Pinyin, or set to undef if this record has Pinyin that we
  # can't normalize (which does happen)
  $pinyin = cedict_pinyin($pinyin);
  
  # Trim definition of empty senses and whitespace at start and end
  $defn =~ s/\A[\s\/]+//;
  $defn =~ s/[\s\/]+\z//;
  
  # Make sure definition after trimming is not empty
  (length($defn) > 0) or
    die "Dictionary line $lnum: Empty definition, stopped";
  
  # Split definition into multiple slash-separated components
  my @comp = split /\//, $defn;
  ($#comp >= 0) or die "Unexpected";
  
  # Process each component, building the sense array
  my @senses;
  for my $ct (@comp) {
    # Trim leading and trailing whitespace and semicolons
    $ct =~ s/\A[\s;]+//;
    $ct =~ s/[\s;]+\z//;
    
    # If result after trimming is empty, skip this component
    (length($ct) > 0) or next;
    
    # Replace internal sequences of whitespace and semicolons with just
    # semicolons
    $ct =~ s/\s*;[\s;]*/;/g;
    
    # Split into semicolon-separated glosses
    my @glosses = split /;/, $ct;
    ($#glosses >= 0) or die "Unexpected";
    
    # Whitespace-trim each gloss and none should be blank
    for my $g (@glosses) {
      $g =~ s/\A\s+//;
      $g =~ s/\s+\z//;
      (length($g) > 0) or die "Unexpected";
    }
    
    # Add to the sense array
    push @senses, (\@glosses);
  }
  
  # Start an annotations hash for the main definition record
  my %mannote = (
    measures => [ ],
    pronun   => [ ],
    xref     => [ ]
  );
  
  # Start an array that will contain annotated entry hashes
  my @entries;
  
  # Now go through all the glosses, parsing them further with annotation
  # processing, and building up both %mannote and @entries
  my $sense_count = 0;
  for my $sense (@senses) {
    # Start sense processing by setting the first_gloss flag
    my $first_gloss = 1;
    
    # Go through all the glosses in the sense
    for my $cstr (@$sense) {
      
      # Get a copy of this component
      my $str = $cstr;
      
      # Extract any measures
      my @measures;
      
      my $retval = parse_measures($str);
      if (defined $retval) {
        $str = $retval->[0];
        @measures = map { $_ } @{$retval->[1]};
      }
      
      # Extract any pronunciations
      my @pronun;
      
      $retval = extract_pronunciation($str);
      if (defined $retval) {
        $str = $retval->[0];
        push @pronun, ([
            $retval->[1],
            $retval->[2],
            $retval->[3]
          ]);
      }
      
      # Extract any cross-references
      my @xref;
      
      $retval = extract_xref($str);
      if (defined $retval) {
        $str = $retval->[0];
        push @xref, ([
            $retval->[1],
            $retval->[2],
            $retval->[3],
            $retval->[4]
          ]);
      }
      
      # If after all that parsing we ended up with an empty string, add
      # any annotations to the main annotation hash; else, create a new
      # entry with these annotations
      if (length($str) > 0) {
        # String is not empty after parsing annotations, so we are going
        # to add an entry; if the first_gloss flag is set then increment
        # the sense count and clear that flag
        if ($first_gloss) {
          $sense_count++;
          $first_gloss = 0;
        }
        
        # Get a citations array on the remaining gloss text
        my @cites = parse_cites($str);
        
        # Push a new annotated entries hash to the entries array
        push @entries, ({
            sense    => $sense_count,
            measures => \@measures,
            pronun   => \@pronun,
            xref     => \@xref,
            cites    => \@cites,
            text     => $str
          });
        
      } else {
        # String is empty after parsing annotations, so add any parsed
        # annotations to the main entry annotations hash
        for my $e (@measures) {
          push @{$mannote{'measures'}}, ($e);
        }
        
        for my $e (@pronun) {
          push @{$mannote{'pronun'}}, ($e);
        }
        
        for my $e (@xref) {
          push @{$mannote{'xref'}}, ($e);
        }
      }
    }
  }
  
  # If we got here, then update state and return true
  $self->{'_state'} = 0;
  $self->{'_rec'  } = {
    traditional => $trad,
    simplified  => $simp,
    pinyin      => $pinyin,
    mannote => \%mannote,
    entries => \@entries
  };
  
  return 1;
}

=item B<traditional()>

Get the traditional-character rendering of the currently loaded
dictionary record.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of File
(BOF) or End Of File (EOF) state.

=cut

sub traditional {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return $self->{'_rec'}->{'traditional'};
}

=item B<simplified()>

Get the simplified-character rendering of the currently loaded
dictionary record.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of File
(BOF) or End Of File (EOF) state.

=cut

sub simplified {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return $self->{'_rec'}->{'simplified'};
}

=item B<pinyin()>

Return the normalized Pinyin for this record, or C<undef> if the Pinyin
could not be normalized.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of File
(BOF) or End Of File (EOF) state.

=cut

sub pinyin {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return $self->{'_rec'}->{'pinyin'};
}

=item B<main_annote()>

Return a reference to the main annotations hash for this record.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of File
(BOF) or End Of File (EOF) state.

The returned hash has three properties: C<measures> C<pronun> and
C<xref>.  Each of these are array references.  The measures array stores
subarrays consisting of the traditional han, simplified han, and
optionally the normalized Pinyin.  The pronunciations array stores
subarrays consisting of the context, a subarray of normalized Pinyin
readings, and a condition.  The cross-references array stores subarrays
consisting of the description, type, subarray, and suffix, where the
subarray has further xref subarrays with traditional han, simplified
han, and optionally normalized Pinyin.

B<Note:> This is not a copy, so modifications to this hash update the
main record state.

=cut

sub main_annote {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return $self->{'_rec'}->{'mannote'};
}

=item B<entries()>

Return a reference to the entries array for this record.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of File
(BOF) or End Of File (EOF) state.

Entries are each hash references.  They have properties C<measures>
C<pronun> and C<xref> with the same format as for C<main_annote()>.
They also have a C<sense> integer which gives the sense number this
gloss belongs to, a C<text> integer which stores the text of the gloss
(without any annotations), and a C<cites> array reference that stores
the citations within C<text>, in the same array format as is used by the
C<parse_cites()> function of C<Sino::Util>.

B<Note:> This is not a copy, so modifications to this array update the
main record state.

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
  
  # Return desired information
  return $self->{'_rec'}->{'entries'};
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

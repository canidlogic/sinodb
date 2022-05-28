package Dict::Parse;
use strict;

# Core dependencies
use Fcntl qw(:seek);

=head1 NAME

Dict::Parse - Parse through the CC-CEDICT data file.

=head1 SYNOPSIS

  use Dict::Parse;
  use DictConfig;
  
  # Open the data file
  my $dict = Dict::Parse->load($config_dictpath);
  
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
    
    # Array of Pinyin syllables, may include punctuation "syllables"
    my @pnya = $dict->pinyin;
    
    # Definition is array of sense subarrays
    for my $sense ($dict->senses) {
      # Sense subarrays contain glosses
      for my $gloss (@$sense) {
        ...
      }
    }
  }

=head1 DESCRIPTION

Module that opens and allows for parsed iteration through the CC-CEDICT
data file.  You can get the data file from the following website:

  https://www.mdbg.net/chinese/dictionary?page=cc-cedict

See the synopsis for parsing operation.  This module only stores a
single entry in memory at a time, so it should have no trouble handling
the large data file.

In order to use this module in a manner independent of specific system,
generate a configuration module that looks like this:

  package DictConfig;
  use parent qw(Exporter);
  
  our @EXPORT = qw($config_dictpath);
  
  $config_dictpath = '/example/path/to/cedict_ts.u8';
  
  1;

Replace the example path in the file contents shown above with the
absolute path on the file system to the I<decompressed> CC-CEDICT data
file.  You must name this module C<DictConfig.pm> and place it in some
directory that is in the Perl module include path of the scripts you
will be running.

=head1 CONSTRUCTOR

=over 4

=item B<load(data_path)>

Construct a new dictionary parser object.  C<data_path> is the path in
the local file system to the I<decompressed> CC-CEDICT data file.
Normally, you get this path from the C<DictConfig> module, as explained
earlier.

An read-only file handle to the data file is kept open while the object
is constructed.  Undefined behavior occurs if the data file changes
while a parser object is opened.  The destructor for this object will
close the file handle automatically.

This constructor does not actually read anything from the file yet.

=cut

sub load {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameter
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $data_path = shift;
  (not ref($data_path)) or die "Wrong parameter types, stopped";
  
  (-f $data_path) or die "Can't find file '$data_path', stopped";
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_fh' property will store the file handle
  open(my $fh, '< :encoding(UTF-8) :crlf', $data_path) or
    die "Failed to open file '$data_path', stopped";
  
  $self->{'_fh'} = $fh;
  
  # The '_state' property will be -1 for BOF, 0 for record, 1 for EOF
  $self->{'_state'} = -1;
  
  # The '_linenum' property is the line number of the last line that was
  # read (where 1 is the first line), or 0 when BOF
  $self->{'_linenum'} = 0;
  
  # When '_state' is 0, the '_rec' hash stores each of the properties
  # of the record that was just parsed; otherwise, it is an empty hash
  $self->{'_rec'} = { };
  
  # Return the new object
  return $self;
}

=back

=head1 DESTRUCTOR

The destructor for the parser object closes the file handle.

=cut

sub DESTROY {
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Close the file handle
  close($self->{'_fh'});
}

=head1 INSTANCE METHODS

=over 4

=item B<rewind()>

Rewind the data file back to the beginning and change the state of this
parser to Beginning Of File (BOF).  This is also the initial state of
the parser object after construction.  No record is currently loaded
after calling this function.

=cut

sub rewind {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Rewind to beginning of file
  seek($self->{'_fh'}, 0, SEEK_SET) or die "Seek failed, stopped";
  
  # Clear state to BOF
  $self->{'_state'  } =  -1;
  $self->{'_linenum'} =   0;
  $self->{'_rec'    } = { };
}

=item B<seek(n)>

Rewind the data file back to the beginning and skip to immediately
before a given line number, setting parser state to BOF.  Calling this
with a value of 1 is equivalent to calling the rewind function.  No
record is currently loaded after calling this function.

First, this function performs a rewind operation.  Second, this function
reads zero or more lines until either the current line number advances
to one less than the given C<n> value, or EOF is reached.  When advance
is called, it will act as though the first line of the file were the
given line number.

C<n> must be an integer greater than zero.  Note that if advance
successfully reads a record, the line number of this record is I<not>
necessarily the same as C<n>.  If C<n> refers to a comment line or a
blank line, advance will read the next line that is not a comment or
blank.

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
  ($n > 0) or die "Parameter out of range, stopped";
  
  # Perform a rewind
  $self->rewind;
  
  # Skip one less than the given line number, updating the line number
  # count along the way
  for(my $i = 1; $i < $n; $i++) {
    # If we have reached EOF, then leave loop
    (not eof($self->{'_fh'})) or last;
    
    # Read a line
    defined(readline $self->{'_fh'}) or die "I/O error, stopped";
    
    # Increase the line count
    $self->{'_linenum'} = $self->{'_linenum'} + 1;
  }
}

=item B<line_number()>

Get the current line number in the dictionary file.  After construction
and also immediately following a rewind, this function will return zero.
After an advance operation that returns true, this will return the line
number of the record that was just read (where the first line is 1).
After an advance operation that returns false, this will return the line
number of the last line in the file.

=cut

sub line_number {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return line number
  return $self->{'_linenum'};
}

=item B<advance()>

Read and parse a record from the data file.

Each call to this function loads a new record.  Note that when the
parser object is initially constructed, and also immediately following
a rewind operation, no record is loaded, so you must call this function
I<before> reading the first record in the dictionary.

The return value is 1 if a new record was loaded, 0 if we have reached
End Of File (EOF).  Once EOF is reached, subsequent calls to this
function will return EOF until a rewind operation is performed.

=cut

sub advance {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Handle special state -- if we are already EOF, then just return
  # false without proceeding further
  if ($self->{'_state'} > 0) {
    # EOF
    return 0;
  }
  
  # Read lines until we get one that is neither a comment nor blank, or
  # we reach EOF
  my $ltext = undef;
  
  while(not eof($self->{'_fh'})) {
    # Read a line
    defined($ltext = readline $self->{'_fh'}) or
      die "I/O error, stopped";
    
    # Increase the line count
    $self->{'_linenum'} = $self->{'_linenum'} + 1;
    
    # Drop line break
    chomp $ltext;
    
    # If this is the first line of the file, drop any UTF-8 Byte Order
    # Mark (BOM)
    if ($self->{'_linenum'} == 1) {
      $ltext =~ s/\A\x{feff}//;
    }
    
    # If this is a comment or blank line, set back to undef and continue
    # on reading; otherwise, leave the loop
    if (($ltext =~ /\A[ \t]*\z/) or ($ltext =~ /\A[ \t]*#/)) {
      # Blank line or comment
      $ltext = undef;
    
    } else {
      # Found a line that is neither comment nor blank
      last;
    }
  }
  
  # If we reached EOF, then set EOF state and return false
  unless (defined $ltext) {
    $self->{'_state'} = 1;
    $self->{'_rec'  } = { };
    return 0;
  }
  
  # If we got here, then we have a record line; begin by storing the
  # line number for use in error reports
  my $lnum = $self->{'_linenum'};
  
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
  
  # Trim Pinyin of leading and trailing whitespace
  $pinyin =~ s/\A\s+//;
  $pinyin =~ s/\s+\z//;
  
  # Make sure Pinyin after trimming is not empty
  (length($pinyin) > 0) or
    die "Dictionary line $lnum: Empty pinyin, stopped";
  
  # Split Pinyin into whitespace-separated tokens
  my @pnys = split ' ', $pinyin;
  ($#pnys >= 0) or die "Unexpected";
  
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
  
  # If we got here, then update state and return true
  $self->{'_state'} = 0;
  $self->{'_rec'  } = {
    traditional => $trad,
    simplified  => $simp,
    pinyin      => \@pnys,
    senses      => \@senses
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

Return each of the Pinyin syllables of the currently loaded dictionary
record.  The return is a list in list context.

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
  return map { $_ } @{$self->{'_rec'}->{'pinyin'}};
}

=item B<senses()>

Return all the definitions of the currently loaded dictionary record.
The return is a list in list context.  The elements of this list
represent the separate senses of the word.  Each element is an array
reference, and these subarrays store a sequence of gloss strings
representing glosses for the sense.

This function makes a copy of the arrays it returns, so modifying the
arrays will not affect the state of the parser object.

Note that CC-CEDICT stores various other kinds of information here, such
as variant references, Taiwan Pinyin, and more.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of File
(BOF) or End Of File (EOF) state.

=cut

sub senses {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return map {
    my $ar = $_;
    my @a = map { $_; } @$ar;
    \@a;
  } @{$self->{'_rec'}->{'senses'}};
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

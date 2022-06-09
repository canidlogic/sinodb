package Sino::Multifile;
use strict;

# Core dependencies
use Fcntl qw(:seek);

=head1 NAME

Sino::Multifile - Iterate through the lines in a sequence of files.

=head1 SYNOPSIS

  use Sino::Multifile;
  
  # Open the data files
  my $mr = Sino::Multifile->load($file_arrayref);
  
  # (Re)start an iteration through the files
  $mr->rewind;
  
  # Get current file index
  my $findex = $mr->file_index;
  
  # Get current line number, or 0 if Beginning Of Stream (BOS)
  my $lnum = $mr->line_number;
  
  # Read each file line
  while ($mr->advance) {
    # Get line just read
    my $ltext = $mr->text;
    ...
  }

=head1 DESCRIPTION

Module that opens and allows for iteration through all the lines in a
sequence of files.

See the synopsis for parsing operation.  This module only stores a
single line in memory at a time, so it should handle large data files.

However, the parser object will store open file handles to each of the
files, so don't attempt to open large numbers of files with this module
or you may run out of file handles.

=head1 CONSTRUCTOR

=over 4

=item B<load(file_paths)>

Construct a new file sequence reader object.  C<file_paths> is an array
reference to the paths of the files you want to read through, in the
order they should be read.

Read-only file handles to the data files are kept open while the object
is constructed.  Do not try to read through large numbers of files with
this module or you may run out of file handles.  Undefined behavior
occurs if the data files change while this reader object is opened on
them.  The destructor for this object will close the file handles
automatically.

The handles are opened in UTF-8 mode with CR+LF translation mode active.
Any UTF-8 Byte Order Mark (BOM) at the start of the files are skipped.

The provided array must have at least one file path.

This constructor does not actually read anything from the files yet.

=cut

sub load {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameter
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $data_paths = shift;
  (ref($data_paths) eq 'ARRAY') or die "Wrong parameter types, stopped";
  (scalar(@$data_paths) > 0) or die "Empty array parameter, stopped";
  
  for my $path (@$data_paths) {
    (not ref($path)) or die "Wrong parameter types, stopped";
    (-f $path) or die "Can't find file '$path', stopped";
  }
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_fha' property will store an array reference to an array of
  # file handles for reading each of the data files
  $self->{'_fha'} = [];
  for my $path (@$data_paths) {
    open(my $fh, '< :encoding(UTF-8) :crlf', $path) or
      die "Failed to open TOCFL file '$path', stopped";
    push @{$self->{'_fha'}}, ($fh);
  }
  (scalar(@{$self->{'_fha'}}) > 0) or die "Unexpected";
  
  # The '_state' property will be -1 for BOS, 0 for record, 1 for EOS
  $self->{'_state'} = -1;
  
  # The '_index' property is the current file index we are reading
  # through
  $self->{'_index'} = 0;
  
  # The '_linenum' property is the line number of the last line that was
  # read (where 1 is the first line), or 0 when BOS
  $self->{'_linenum'} = 0;
  
  # When '_state' is 0, '_ltext' stores the line just read, without any
  # line break at the end; else, it is an empty string
  $self->{'_rec'} = '';
  
  # Return the new object
  return $self;
}

=back

=head1 DESTRUCTOR

The destructor for the parser object closes the file handles.

=cut

sub DESTROY {
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Close the file handle(s)
  for my $fh (@{$self->{'_fha'}}) {
    close($fh);
  }
}

=head1 INSTANCE METHODS

=item B<rewind()>

Rewind the data files back to the beginning and change the state of this
reader to Beginning Of Stream (BOS).  This is also the initial state of
the reader object after construction.  No record is currently loaded
after calling this function.

This rewinds all the way back to the start of the first file, regardless
of which file you are currently reading.

=cut

sub rewind {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Rewind to beginning of file(s)
  for my $fh (@{$self->{'_fha'}}) {
    seek($fh, 0, SEEK_SET) or die "Seek failed, stopped";
  }
  
  # Clear state to BOS
  $self->{'_state'  } = -1;
  $self->{'_index'  } =  0;
  $self->{'_linenum'} =  0;
  $self->{'_rec'    } = '';
}

=item B<file_index()>

Get the index of the file we are currently reading through, where zero
is the first file.  This property is always available, even if a record
is not currently loaded.  The line_number() is located within the file
indicated by this level.

=cut

sub file_index {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return file index
  return $self->{'_index'};
}

=item B<line_number()>

Get the current line number in the current file.  After construction and
also immediately following a rewind, this function will return zero. 
After an advance operation that returns true, this will return the line
number of the record that was just read (where the first line is 1).
After an advance operation that returns false, the return value of this
function is zero.

The line number is the line number within the current file, as
determined by file_index().

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

Read the next line from the data files.

Each call to this function loads a new line.  Note that when the reader
object is initially constructed, and also immediately following a rewind
operation, no record is loaded, so you must call this function I<before>
reading the first line.

The return value is 1 if a new record was loaded, 0 if we have reached
End Of Stream (EOS) in the last file.  Once EOS is reached, subsequent
calls to this function will return EOS until a rewind operation is
performed.

This function will read through all the files in the order given in the
constructor, without any interruption between the files.  The function
file_index() can be used to check which file has just been read from
after a successful call to advance().

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
  
  # Increase the file index if necessary until we are at a non-EOF file
  # or we went past the last file; each time we advance a file, reset
  # the line number to zero
  for( ;
      $self->{'_index'} < scalar(@{$self->{'_fha'}});
      $self->{'_index'} = $self->{'_index'} + 1) {
    if (not eof $self->{'_fha'}->[$self->{'_index'}]) {
      last;
    } else {
      $self->{'_linenum'} = 0;
    }
  }
  
  # If we went past the last file on the previous step, then set EOS
  # state and return EOS
  unless ($self->{'_index'} < scalar(@{$self->{'_fha'}})) {
    # Set EOS state and return EOS
    $self->{'_state'  } =  1;
    $self->{'_index'  } =  scalar(@{$self->{'_fha'}}) - 1;
    $self->{'_linenum'} =  0;
    $self->{'_rec'    } = '';
    return 0;
  }
  
  # If we got here then the index is on a file handle that is not EOF,
  # so read the line
  my $ltext = readline($self->{'_fha'}->[$self->{'_index'}]);
  (defined $ltext) or die "I/O error reading file, stopped";
  
  # If this is the very first line read, then drop any leading UTF-8 BOM
  if ($self->{'_linenum'} == 0) {
    $ltext =~ s/\A\x{feff}//;
  }
  
  # Increase the line count
  $self->{'_linenum'} = $self->{'_linenum'} + 1;
  
  # Drop line break
  chomp $ltext;
  
  # Update state and record field, then return true
  $self->{'_state'} = 0;
  $self->{'_rec'  } = $ltext;
  
  return 1;
}

=item B<text()>

Get the line that was just read.

This may only be used after a successful call to the advance function.
A fatal error occurs if this function is called in Beginning Of Stream
(BOS) or End Of Stream (EOS) state.

The returned string may include Unicode codepoints.  Any UTF-8 Byte
Order Mark (BOM) will already be dropped, and any line break characters
at the end of the line will already be dropped also.

=cut

sub text {
  
  # Check parameter count
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check state
  ($self->{'_state'} == 0) or die "Invalid state, stopped";
  
  # Return desired information
  return $self->{'_rec'};
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

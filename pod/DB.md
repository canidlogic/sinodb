# NAME

Sino::DB - Manage the connection to the Sino database.

# SYNOPSIS

    use Sino::DB;
    use SinoConfig;
    
    my $dbc = Sino::DB->connect($config_dbpath, 0);
    
    my $dbh = $dbc->beginWork('rw');
    ...
    $dbc->finishWork;
    

# DESCRIPTION

Module that opens and manages a connection to the Sino database, which
is a SQLite database.  This module also supports a transaction system on
the database connection.

To get the database handle, you use the `beginWork` method and specify
whether this is a read-only transaction or a read-write transaction.  If
no transaction is currently active, this will start the appropriate kind
of database transaction.  If a transaction is currently active, this
will just use the existing transaction but increment an internal nesting
counter.  It is a fatal error, however, to start a read-write
transaction when a read-only transaction is currently active, though
starting a read-only transaction while a read-write transaction is
active is acceptable.

The database handle is configured to generate fatal errors if there are
any kind of database errors (RaiseError behavior is enabled).
Furthermore, the destructor of this class is configured to perform a
rollback if a transaction is still active when the script exits
(including in the event of stopping due to a fatal error).

Each call to `beginWork` should have a matching `finishWork` call
(except in the event of a fatal error).  If the internal nesting counter
indicates that this is not the outermost work block, then the internal
nesting counter is merely decremented.  If the internal nesting counter
indicates that this is the outermost work block, then `finishWork` will
commit the transaction.  (If a fatal error occurs during commit, the
result is a rollback.)

As shown in the synopsis, all you have to do is start with `beginWork`
to get the database handle and call `finishWork` once you are done with
the handle.  If any sort of fatal error occurs, rollback will
automatically happen.  Also, due to the nesting support of work blocks,
you can begin and end work blocks within procedure and library calls.

See `config.md` in the `doc` directory for configuration you must do
before using this module.

# CONSTRUCTOR

- **connect(db\_path, new\_db)**

    Construct a new database connection object.  `db_path` is the path in
    the local file system to the SQLite database file.  Normally, you get
    this from the `SinoConfig` module, as shown in the synopsis.

    The `new_db` parameter should normally be set to false (0).  In this
    normal mode of operation, the constructor will check that the given path
    exists as a regular file before connecting to it.  Otherwise, if you set
    it to true (1), then the constructor will check that the given path does
    _not_ currently exist before connecting to it.  Setting it to true
    should only be done for the `createdb.pl` script that creates a
    brand-new Sino database.

    Note that there is a race condition with the file existence check, such
    that the existence or non-existence of the database file may change
    between the time that the check is made and the time that the connection
    is opened.

    The work block nesting count starts out at zero in the constructed
    object.

# DESTRUCTOR

The destructor for the connection object performs a rollback if the work
block nesting counter is greater than zero.  Then, it closes the
database handle.

# INSTANCE METHODS

- **beginWork(mode)**

    Begin a work block and return a DBI database handle for working with the
    database.

    The `mode` argument must be either the string value `r` or the string
    value `rw`.  If it is `r` then only read operations are needed.  If it
    is `rw` then both read and write operations are needed.

    If the nesting counter of this object is in its initial state of zero,
    then a new transaction will be declared on the database, with deferred
    transactions used for read-only and immediate transactions used for both
    read-write modes.  In all cases, the nesting counter will then be
    incremented to one.

    If the nesting counter of this object is already greater than zero when
    this function is called, then the nesting counter will just be
    incremented and the currently active database transaction will continue
    to be used.  A fatal error occurs if `beginWork` is called for one of
    the read-write modes but there is an active transaction that is
    read-only.

    The returned DBI handle will be to the database that was opened by the
    constructor.  This handle will always be to a SQLite database, though
    nothing is guaranteed about the structure of this database by this
    module.  The handle will be set up with `RaiseError` enabled.  The
    SQLite driver will be configured to use binary string encoding.
    Undefined behavior occurs if you change fundamental configuration
    settings of the returned handle, issue transaction control SQL commands,
    call disconnect on the handle, or do anything else that would disrupt
    the way this module is managing the database handle.

    **Important:** Since the string mode is set to binary, you must manually
    encode Unicode strings to UTF-8 binary strings before using them in SQL,
    and you must manually decode UTF-8 binary strings to Unicode after
    receiving them from SQL.

    Note that in order for changes to the database to actually take effect,
    you have to match each `beginWork` call with a later call to 
    `finishWork`.

- **finishWork(mode)**

    Finish a work block.

    This function decrements the nesting counter of the object.  The nesting
    counter must not already be zero or a fatal error will occur.

    If this decrement causes the nesting counter to fall to zero, then the
    active database transaction will be committed to the database.

    Each call to `beginWork` should have a matching call to `finishWork`
    and once you call `finishWork` you should forget about the database
    handle that was returned by the `beginWork` call.

# AUTHOR

Noah Johnson, `noah.johnson@loupmail.com`

# COPYRIGHT AND LICENSE

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

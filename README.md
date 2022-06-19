# Sino Database

Utilities for parsing Chinese dictionary files.  This project allows a highly structured SQLite database to be constructed that compiles information from various Chinese dictionary sources.

See the `config.md` file in the `doc` directory for information about how to configure the scripts so they will run, and make sure you have the dependencies documented in `depends.md`.

After proper configuration, you do the following to build the SQLite database:

    ./createdb.pl
    ./import_tocfl.pl
    ./import_coct.pl
    ./import_extra.pl
    ./import_cedict.pl
    ./tokenize.pl

These scripts may take quite a while!  Also, be sure to run the scripts in the exact order shown above.

The result of that will be a SQLite database generated at the location you specified in the configuration module you created during the configuration process.  (See `config.md`)

See the POD documentation of `createdb` in the `pod` directory for the specifics of the database structure.

You can use `wordscan.pl` to query keywords in the glosses within the SQLite database, and you can use `wordquery.pl` to print out information about specific words.  Pipe the results of `wordscan.pl` into `wordquery.pl` for a full lookup system.

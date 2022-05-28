# Sino dependencies

This document describes the external code dependencies of the Sino scripts that are not part of the core Perl modules.  (In addition to external code dependencies, there are also dependencies on external data files, see `config.md` for more about those.)

The full set of non-core code dependencies is as follows:

- `DBI`
- `DBD::SQLite`

You can satistfy both of these dependencies by just installing `DBD::SQLite` since that will automatically bring in `DBI` as a dependency.

You can use cpanminus to grab these dependencies.  See the documentation at the start of the script available at the website `cpanmin.us` for further details.  Once you have that script, pass `DBD::SQLite` as an argument to it to install all you need.

If cpanminus installs dependencies into your home directory, then you will need to add this install location into the Perl include path for the Sino scripts.  See near the end of `config.md` for further information.

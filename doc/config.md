# Sino database configuration

Before using the main scripts provided by this project, you must configure the scripts.  This involves three steps:

1. Assemble data files
2. Generate `SinoConfig.pm`
3. Add Sino to the Perl include path

## Step 1: Assembling data files

The data files you need are the TOCFL vocabulary list (8000-word list), the COCT vocabulary list (14,470 words), the CC-CEDICT dictionary, and the supplemental datasets.  

The easiest way to get the data files is to use the [Sinodata mirror](https://canidlogic.github.io/sinodata/).  You will need the mirrored ZIP archive of CC-CEDICT, the reformatted CSV mirror of TOCFL, and the reformatted CSV mirror of COCT.  Simply decompress each of these archives to get all the needed data files.

You will also need the supplemental datasets, which are contained within the `dataset` directory of this project and are already in the correct format.

If you want to directly gather the third-party datasets yourself, see the following subsection:

### Direct sourcing

The import process needs extensive manual adjustments, so you should use the specific versions of each of the datasets shown here:

- __TOCFL:__ April 11, 2022 version
- __COCT:__ December 2, 2020 version
- __CC-CEDICT:__ May 24, 2022 version

You may attempt to use other versions of these datasets, but note that additional adjustments may need to be made to the Sino scripts if there were substantial updates to relevant records.

The CC-CEDICT dataset is distributed in a structured plain-text format that the Sino scripts can directly read.  You must, however, decompress the plain-text file before using it with the scripts.

The TOCFL and COCT datasets are distributed in proprietary office formats.  You must export them to CSV format before the Sino scripts can use them.  The CSV format should use UTF-8, comma separators, no quoting of values, and no header row.  For TOCFL, each vocabulary level should be in a separate CSV file.  For COCT, there is a single CSV file, in UTF-8 format with comma separators, no quoting of values, and no header row.  For the COCT CSV file, each record has two columns.  The first column is an unsigned decimal integer storing the COCT level of the word.  The second column is the headword(s) from the COCT file.  The word processor version of the COCT vocabulary list is the one that is used, rather than the spreadsheet version (even though both should have the same words).

## Step 2: Generating the config module

Once you have assembled all the data files as described in the previous step, you need to create a configuration Perl module that will let Sino know where all of these files are located, and also where you want the SQLite database to be.

The configuration file should look like this:

    package SinoConfig;
    use parent qw(Exporter);
    
    our @EXPORT = qw(
                    $config_dbpath
                    $config_datasets
                    $config_dictpath
                    $config_coctpath
                    $config_tocfl);
    
    $config_dbpath = '/example/path/to/db.sqlite';
    $config_datasets = '/example/path/to/dataset/';
    $config_dictpath = '/example/path/to/cedict.txt';
    $config_coctpath = '/example/path/to/coct.csv';
    $config_tocfl = [
      '/example/path/to/tocfl/Novice1.csv',
      '/example/path/to/tocfl/Novice2.csv',
      '/example/path/to/tocfl/Level1.csv',
      '/example/path/to/tocfl/Level2.csv',
      '/example/path/to/tocfl/Level3.csv',
      '/example/path/to/tocfl/Level4.csv',
      '/example/path/to/tocfl/Level5.csv'
    ]
    
    1;

Replace all the example paths in the module shown above with the absolute paths to the data files that you assembled in the preceding step, and set `config_dbpath` to the path where you want the Sino SQLite database to be generated.  The `config_datasets` variable should lead to the `dataset` folder of this project where the supplemental datasets within must have the names defined by this project.  The path in the `config_datasets` variable must include a trailing path separator so that filenames can be directly appended.

You must name this configuration file `SinoConfig.pm`

## Step 3: Update Perl include path

You must make sure that the `SinoConfig.pm` configuration file you generated in the previous step is somewhere in the Perl include path when you are running the Sino scripts, and you must also make sure that the `Sino` directory containing the Sino modules is also in the Perl include path.

You can do this by modifying the shebang line at the start of each of the Sino scripts.  The scripts as provided all use the following shebang line:

    #!/usr/bin/env perl

For each script, modify this shebang line so that it is the appropriate path to the Perl interpreter on your system, and pass an include option that references the directory that includes `Sino` as a subdirectory:

    #!/usr/bin/perl -I/example/path/to

In this example, the `Sino` subdirectory would be located at `/example/path/to/Sino`

You should then also make sure the `SinoConfig.pm` configuration module that you generated is in that include directory.  In the previous example, you would place it at `/example/path/to/SinoConfig.pm`

If you are using a system such as `cpanm` to install non-core Perl dependencies without registering them in the whole system, this is also a great place to add your local `cpanm` directory to the include path:

    #!/usr/bin/perl -I/home/example/perl5/lib/perl5 -I/example/path/to

Last step before you can use the scripts is make sure they have execute permission by running `chmod +x` on each of them.

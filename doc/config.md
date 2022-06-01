# Sino database configuration

Before using the main scripts provided by this project, you must configure the scripts.  This involves three steps:

1. Assemble data files
2. Generate `SinoConfig.pm`
3. Add Sino to the Perl include path

## Step 1: Assembling data files

The data files you need are the TOCFL vocabulary list (8000-word list), the COCT vocabulary list (14,470 words), the CC-CEDICT dictionary, and the supplemental datasets.  The following subsections describe how to obtain these data files in further detail.

### TOCFL vocabulary list

The TOCFL source vocabulary list can be downloaded from the following site:

    https://tocfl.edu.tw/index.php/exam/download

Follow the link 華語八千詞表 (Chinese language 8000 word list) to download an archive named something like `8000zhuyin_202204.rar`  The archive uses the proprietary RAR archive format, so you may need to use an online converter to convert the file into a non-proprietary archive format if you have troubles opening the archive.

Within this archive, there should be a large Excel spreadsheet.  This spreadsheet has the TOCFL "8000-word" vocabulary lists, with one spreadsheet tab for each vocabulary level.  Using LibreOffice Calc or some other spreadsheet program, copy each vocabulary list /excluding the header rows/ to a new spreadsheet and then save that spreadsheet copy in Comma-Separated Value (CSV) format, using commas as the separator, no quoting, and UTF-8 encoding.  As a result, you should end up with seven CSV text files corresponding to each of the vocabulary levels within the spreadsheet.  The CSV files must /not/ have a header row with column names; if they do, manually delete the header rows.

### COCT vocabulary list

See `COCT.md` for instructions about obtaining the COCT vocabulary list and preparing it in a CSV format that can be imported by Sino.

### CC-CEDICT dictionary

The CC-CEDICT dictionary data file can be downloaded from the following site:

    https://www.mdbg.net/chinese/dictionary?page=cc-cedict

There should be links to a file named something like `cedict_1_0_ts_utf-8_mdbg`, and then some file extension for a compressed file (either `zip` for Zip or `txt.gz` for a plain-text file compressed with GZip).

Once you download this file, you need to decompress it into a simple plain-text file.  The Sino scripts will /not/ work on a compressed file.

### Supplemental datasets

The supplemental datasets are contained within the `dataset` directory of this project and are already in the correct format.

## Step 2: Generating the config module

Once you have assembled all the data files as described in the previous step, you need to create a configuration Perl module that will let Sino know where all of these files are located, and also where you want the SQLite database to be.

The configuration file should look like this:

    package SinoConfig;
    use parent qw(Exporter);
    
    our @EXPORT = qw(
                    $config_dbpath
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

You should then also make sure the `SinoConfig.pm` configuratio module that you generated is in that include directory.  In the previous example, you would place it at `/example/path/to/SinoConfig.pm`

If you are using a system such as `cpanm` to install non-core Perl dependencies without registering them in the whole system, this is also a great place to add your local `cpanm` directory to the include path:

    #!/usr/bin/perl -I/home/example/perl5/lib/perl5 -I/example/path/to

Last step before you can use the scripts is make sure they have execute permission by running `chmod +x` on each of them.

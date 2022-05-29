# Import notes for COCT dataset

The COCT files are available at the following site:

    https://coct.naer.edu.tw/download/tech_report/

Look for the heading 字詞表 under which there should be links to three Word documents and one Excel spreadsheet to download.  The word list is contained in both the Word document and the Excel spreadsheet that have the name 國教院三等七級詞表.

(There are also Word documents named 國教院三等七級字表 and 國教院語法點分級表 which contain a character list and a grammar structure list.  Neither of these are used by Sino.)

You can use either the Word or Excel version of 國教院三等七級詞表, depending on which export method you are using (see next section).

## Exporting the word list

The COCT word list can be exported in three different ways.  The first two ways use the same Excel spreadsheet (國教院三等七級詞表).  This Excel spreadsheet contains separate pages for each vocabulary level (the first way), as well as a single page that lists all words from all levels in a single sheet (the second way).  The third way is to use a Word document (also called 國教院三等七級詞表) that has the COCT word list.

### First way: Separate Excel sheets

Using a spreadsheet program such as LibreOffice Calc, save each vocabulary level sheet as a Comma-Separated-Value (CSV) file, UTF-8 encoding, comma as separator, and no value quoting.  Do _not_ include the header row with the column names.  Also, do _not_ include the third and fourth columns; only the first two columns must be present in the exported CSV.

Once you have all the CSV files, merge them all into a single file with the records from each one.  You can use the `cat` program for this.

__Important:__ You must not include any header row and you must not include the third or fourth columns.

### Second way: Single Excel sheet

Using a spreadsheet program such as LibreOffice Calc, save the combined vocabulary sheet as a Comma-Separated-Value (CSV) file, UTF-8 encoding, comma as separator, and no value quoting.  Do _not_ include the header row with the column names.  Also, do _not_ include the third and fourth columns; only the first two columns must be present in the exported CSV.

__Important:__ You must not include any header row and you must not include the third or fourth columns.

### Third way: Word file

Using a word processor program such as LibreOffice Writer, get the Word document containing the vocabulary words.  Note that there are very similarly named and similarly looking Word files that you must _not_ use.  You want the one named 國教院三等七級詞表, which will have a word list organized in seven levels.

Open the Word document in the word processor and then export it as a UTF-8 plain-text file.  It is important that this exported plain-text file uses one line per paragraph; this export method will __not__ work if you export it with paragraphs broken across multiple lines.  Note that some of these plain-text lines will be gigantic in length, so you should probably not try to open it with a regular plain-text editor.

Run this exported UTF-8 plain-text file through the `expandtext.pl` reporting script provided by this project to get a CSV file containing the COCT vocabulary list.

__Note:__ Only this third export method has been tested so far.  The Excel spreadsheet was so large that it kept crashing the spreadsheet program, so the Word document alternative had to be used instead.

## Vocabulary list format

Given the CSV file exported above, the first column will contain the level number.  If using the Excel export method, there might be additional text in this column besides just the number.  Look for a single decimal digit that has the level number and ignore everything else.

According to a technical note distributed along with the TOCFL data, COCT level 1 corresponds to TOCFL level Novice 2, the levels track each other until COCT level 6 corresponds to TOCFL 5, and then COCT level 7 is one beyond the last TOCFL level.  Therefore, each of the COCT levels should be increased by one when integrating with TOCFL data.

Within the word data field, variant parentheses `U+FF08` and `U+FF09` must be changed to regular ASCII parentheses `(` and `)` respectively, and variant slash `U+FF0F` must be changed to regular ASCII forward slash `/`

Each word data field might expand to multiple words.  First of all, if there are forward slashes, divide into separate components using the forward slash.  Second of all, if there is a character in parentheses within any component, expand that component into two alternatives, one without the character in parentheses and the other with.

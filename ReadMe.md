# bzimport.pl - Upload Issues From a CSV File to a Bugzilla Server #

Many people have asked how they can import bugs in a CSV file into a Bugzilla installation. The standard answer is to use [importxml.pl](https://www.bugzilla.org/docs/3.0/html/api/importxml.html). But that implies that you have shell access to your Bugzilla server (to run the import on the server). This is often not the case, however. The other suggestion is to use the [REST interface introduced with Bugzilla 5](https://bugzilla.readthedocs.io/en/5.0/api/index.html), and simply write a script to import the bugs. Nice and fine, but I couldn't find such a script anywhere. Hence, I sat down an wrote one.

## Prerequisites ##

* An installation of [Perl 5](https://www.perl.org), with the following modules installed (`cpan install...`):
    * REST::Client
    * Cpanel::JSON::XS
    * Text::CSV_XS
    * Term::Prompt
* Your new issues in a CSV file using format as described below
* An account on a Bugzilla server that will allow you to create and edit bugs

## Import Format ##

The script uses [Text::CSV_XS](https://metacpan.org/pod/Text::CSV_XS) with UTF-8 encoding to read the CSV file, so should be able to cope with CSV files from most sources.

Your CSV file must have the following 10 columns (all strings):

1. Product (name of the product; **must not be empty**)
2. Component (name of the product's component; **must not be empty**)
3. Summary (the headline of the bug; **must not be empty**)
4. Description (a prose description of the problem; **must not be empty**)
5. Severity (how severe the bug is; e.g. "trivial")
6. Priority (priority of this bug relative to other bugs; e.g. "P1")
7. Blocks (comma separated list of the bugs that this bug blocks; e.g. "1234,1543,2016"; can be empty)
8. Depends On (comma separated list of the bugs that this bug depends on; e.g. "1234,1543,2016"; can be empty)
9. Target Milestone (name of the target milestone for which this bug is to be fixed; can be empty)
10. Version (product/component version that this bug applies to; can be empty)
11. OS (operating system for which this bug is relevant; can be empty)
12. Platform (hardware platform for which this bug is relevant; can be empty)

Except for summary and description, all field contents must match something that already exists in Bugzilla (e.g. a bug id, a configured version, a configure milestone, etc.). Before attempting an import, consult your Bugzilla installation for any customised values that can or must appear in fields. Otherwise Bugzilla will respond with an error, and import will halt.

Lines with a product name of "Product" (usually the table header row) and an empty product name are ignored. Bugzilla does auto-linkification on the imported texts as usual; so if "bug 1234" occurs in the description, Bugzilla will convert it to a hyperlink to that bug (provided that a bug with that id exists).

## Licence ##

You may run the bzimport.pl script for any purpose, be it commercial or not. If you make modifications to it which might be useful for others, please consider submitting a pull request.

If you want to distribute copies to others, you may do so under the [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).

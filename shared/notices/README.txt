This directory contains boilerplate notices for books that are released in sync with the stack
versioning. 

page_header-maintenance.html contains the notice for the live "maintenance version" from the
previous major release stream. (The last minor of the previous major.) 

page_header-EOL.html contains the notice for all versions that have reached their 
end of life (EOL) date. For the official Elastic product EOL schedule, 
see https://www.elastic.co/support/eol. 

These notices need to be set explicitly by adding a file named `page_header.html` to the same
directory as the `index.asciidoc` file used to build each book. Edit the EOL notice to specify
the appropriate product and version.

If no page_header.html file is specified for a version older than current, the default 
"out of maintenance" notice is displayed:

IMPORTANT: No additional bug fixes or documentation updates will be released for this version. 
For the latest information, see the current release documentation.

Note that you can create a custom page header for any version of a book.
This is useful for beta versions and when books are superseded by entirely new books.
The header must be valid HTML and cannot contain comments.
# NAME

Mail::SpamAssassin::Plugin::PDFInfo2 - Improved PDF Plugin for SpamAssassin

# AUTHORS

Kent Oyer (kent@mxguardian.net)

# ACKNOWLEGEMENTS

This plugin is loosely based on Mail::SpamAssassin::Plugin::PDFInfo by Dallas Engelken however it is not a drop-in
replacement as it works completely different. The tag and test names have been chosen so that both plugins can be run
simultaneously, if desired.

Encryption routines were made possible by borrowing some code from CAM::PDF by Chris Dolan

Links to the official PDF specification:

- Version 1.6: [https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.6.pdf](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/pdfreference1.6.pdf)
- Version 1.7: [https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000\_2008.pdf](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf)

# DISCLAIMERS

This code has been tested and **should** function fine in a production environment. However, use it at your own risk.
The author of this package is not affiliated with SpamAssassin or the Apache Software Foundation

# REQUIREMENTS

This plugin requires the following non-core perl modules:

- Crypt::RC4
- Crypt::Mode::CBC
- Convert::Ascii85

# INSTALLATION

### Manual method

Copy all the files in the `dist/` directory to your site rules directory (e.g. `/etc/mail/spamassassin`)

### Automatic method

TBD

# SYNOPSIS

    loadplugin     Mail::SpamAssassin::Plugin::PDFInfo2

# RULE DEFINITIONS

    pdf2_count()

       body RULENAME  eval:pdf2_count(<min>,[max])
          min: required, message contains at least x PDF attachments
          max: optional, if specified, must not contain more than x PDF attachments

    pdf2_page_count()

       body RULENAME  eval:pdf2_page_count(<min>,[max])
          min: required, message contains at least x pages in PDF attachments.
          max: optional, if specified, must not contain more than x PDF pages

    pdf2_link_count()

       body RULENAME  eval:pdf2_link_count(<min>,[max])
          min: required, message contains at least x links in PDF attachments.
          max: optional, if specified, must not contain more than x PDF links

          Note: Multiple links to the same URL are counted multiple times

    pdf2_word_count()

       body RULENAME  eval:pdf2_page_count(<min>,[max])
          min: required, message contains at least x words in PDF attachments.
          max: optional, if specified, must not contain more than x PDF words

          Note: This plugin does not extract text from PDF's. In order for pdf2_word_count to work the text
          must be extracted by another plugin such as ExtractText.pm

    pdf2_match_md5()

       body RULENAME  eval:pdf2_match_md5(<string>)
          string: 32-byte md5 hex

          Fires if any PDF attachment matches the given MD5 checksum

    pdf2_match_fuzzy_md5()

       body RULENAME  eval:pdf2_match_fuzzy_md5(<string>)
          string: 32-byte md5 hex string

          Fires if any PDF attachment matches the given fuzzy MD5 checksum

    pdf2_match_details()

       body RULENAME  eval:pdf2_match_details(<detail>,<regex>);
          detail: Any standard PDF attribute: Author, Creator, Producer, Title, CreationDate, ModDate, etc..
          regex: regular expression

          Fires if any PDF attachment has the given attribute and it's value matches the given regular
          expression

    pdf2_is_encrypted()

       body RULENAME eval:pdf2_is_encrypted()

          Fires if any PDF attachment is encrypted

          Note: PDF's can be encrypted with a blank password which allows them to be opened with any standard
          viewer. This plugin attempts to decrypt PDF's with a blank password. However, pdf2_is_encrypted still
          returns true.

    pdf2_is_protected()

       body RULENAME eval:pdf2_is_protected()

          Fires if any PDF attachment is encrypted with a non-blank password

          Note: Although it's not possible to inspect the contents of password-protected PDF's, the following
          tests still provide meaningful data: pdf2_count, pdf2_page_count, pdf2_match_md5,
          pdf2_match_fuzzy_md5, and pdf2_match_details('Version'). All other values will be empty/zero.

The following rules only inspect the first page of each document

    pdf2_image_count()

       body RULENAME  eval:pdf2_image_count(<min>,[max])
          min: required, message contains at least x images on page 1 (all attachments combined).
          max: optional, if specified, must not contain more than x images on page 1

    pdf2_color_image_count()

       body RULENAME  eval:pdf2_color_image_count(<min>,[max])
          min: required, message contains at least x color images on page 1 (all attachments combined).
          max: optional, if specified, must not contain more than x color images on page 1

    pdf2_image_ratio()

       body RULENAME  eval:pdf2_image_ratio(<min>,[max])
          min: required, images consume at least x percent of page 1 on any PDF attachment
          max: optional, if specified, images do not consume more than x percent of page 1

          Note: Percent values range from 0-100

    pdf2_click_ratio()

       body RULENAME  eval:pdf2_click_ratio(<min>,[max])
          min: required, at least x percent of page 1 is clickable on any PDF attachment
          max: optional, if specified, not more than x percent of page 1 is clickable on any PDF attachment

          Note: Percent values range from 0-100

# TAGS

The following tags can be defined in an `add_header` line:

    _PDF22COUNT_      - total number of pdf mime parts in the email
    _PDF2PAGECOUNT_   - total number of pages in all pdf attachments
    _PDF2WORDCOUNT_   - total number of words in all pdf attachments
    _PDF2LINKCOUNT_   - total number of links in all pdf attachments
    _PDF2IMAGECOUNT_  - total number of images found on page 1 inside all pdf attachments
    _PDF2CIMAGECOUNT_ - total number of color images found on page 1 inside all pdf attachments
    _PDF2VERSION_     - PDF Version, space seperated if there are > 1 pdf attachments
    _PDF2IMAGERATIO_  - Percent of first page that is consumed by images - per attachment, space separated
    _PDF2CLICKRATIO_  - Percent of first page that is clickable - per attachment, space separated
    _PDF2NAME_        - Filenames as found in the mime headers of PDF parts
    _PDF2PRODUCER_    - Producer/Application that created the PDF(s)
    _PDF2AUTHOR_      - Author of the PDF
    _PDF2CREATOR_     - Creator/Program that created the PDF(s)
    _PDF2TITLE_       - Title of the PDF File, if available
    _PDF2MD5_         - MD5 checksum of PDF(s) - space seperated
    _PDF2MD5FUZZY1_   - Fuzzy1 MD5 checksum of PDF(s) - space seperated
    _PDF2MD5FUZZY2_   - Fuzzy2 MD5 checksum of PDF(s) - space seperated

Example `add_header` lines:

    add_header all PDF-Info pdf=_PDF2COUNT_, ver=_PDF2VERSION_, name=_PDF2NAME_
    add_header all PDF-Details producer=_PDF2PRODUCER_, author=_PDF2AUTHOR_, creator=_PDF2CREATOR_, title=_PDF2TITLE_
    add_header all PDF-ImageInfo images=_PDF2IMAGECOUNT_ cimages=_PDF2CIMAGECOUNT_ ratios=_PDF2IMAGERATIO_
    add_header all PDF-LinkInfo links=_PDF2LINKCOUNT_, ratios=_PDF2CLICKRATIO_
    add_header all PDF-Md5 md5=_PDF2MD5_, fuzzy1=_PDF2MD5FUZZY1_

# MD5 CHECKSUMS

To view the MD5 checksums for a message you can run:

    cat msg.eml | spamassassin -D -L |& grep PDF2MD5

The Fuzzy 1 checksum is calculated using tags from every object that is traversed which is essentially pages,
images, and the document trailer. You should expect a match if two PDF's were created by the same author/program
and have the same structure with the same or slightly different content.

The Fuzzy 2 checksum only includes the comment lines at the beginning of the document plus the first object. The
Fuzzy 2 checksum is generally an indicator of what software created the PDF but the contents could be totally
different.

# URI DETAILS

This plugin creates a new "pdf" URI type. You can detect URI's in PDF's using the URIDetail.pm plugin. For example:

    uri-detail RULENAME  type =~ /^pdf$/  raw =~ /^https?:\/\/bit\.ly\//

This will detect a bit.ly link inside a PDF document

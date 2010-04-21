This is a temporary place holder for the Laika code that dealt with import/export and validation of CCR/CCD documents in Laika.  It is checked in as an unpacked gem in the vendor/gems section of the Rails repo.  Eventually it will need to be pushed up to github as an actual gem.

Changes are likely to require a regeneration of the .specification file.  To do this, you need to:

 $ rake build
 $ gem specification pkg/laika-medical-document-<VERSION>.gem > .specification

= Laika Medical Document

The goal of this gem is to allow the validation and transformation of medical documents in either the CCR or C32/CCD XML formats.

One way it does this is by working with the document data in a neutral hash representation which is more readily used by other systems seeking to interact with a document, such as Laika itself.

However the validation process works almost entirely with the original XML, except for content comparison, which requires a hash of the idealized golden version of the document to compare values against those found in the XML.

Being able to parse the XML into a hash graph, however, allows us to store documents granularly by section and value within a relational database, such as that used by the Laika Rails applications.  Laika may then be used to clone or adjust documents on a field by field basis.

It also should allow us to import a document in C32 format and export it in CCR format or vice versa, once import and export routines are completed for both formats.

This library has the following components:

* laika-medical-document
** document-model
** importers
*** hash
*** c32
*** ccr
** exporters
*** hash
*** c32
*** ccr
** validators
*** c32
*** ccr
*** schema
*** schematron
*** umls
*** xds
** errors

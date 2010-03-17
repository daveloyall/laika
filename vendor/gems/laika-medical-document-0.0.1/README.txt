This is a temporary place holder for the Laika code that dealt with import/export and validation of CCR/CCD documents in Laika.  It is checked in as an unpacked gem in the vendor/gems section of the Rails repo.  Eventually it will need to be pushed up to github as an actual gem.

Changes are likely to require a regeneration of the .specification file.  To do this, you need to:

 $ rake build
 $ gem specification pkg/laika-medical-document-<VERSION>.gem > .specification

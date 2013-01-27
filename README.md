repareAliases
========

A command line tool for OSX that fixes the **external file references** in an iPhoto library (after files have been moved). (10.7+).

###usage

    repareAlias [OPTIONS] <arguments> [...]
    
    The arguments must be RULES. A rule is a VERB ARG 1 ARG2. Currently the rules 'path' and 'volume' exist.

- a path rule takes two path fragements to exchange (e.g. replace /dominik with /dpich - the second path of each pair is the new path!)

- a volume rule does the same but with volume UUIDs. (e.g. replace 04D0C367-7A0D-3784-8233-42D2F2646391 with 5B2BE939-94D3-32E0-BC6D-212CE341D087 -- the two volumes must be known to iPhoto (launch the app two make a volume known)

###example call

this is  the call I just used to fix my iPhoto library after moving to a new mac: 

    ./repareAlias --verbose --directory /Users/dpich/Pictures/ PATH Users/dominik/ Users/dpich/ VOLUME 04D0C367-7A0D-3784-8233-42D2F2646391 5B2BE939-94D3-32E0-BC6D-212CE341D087

--

*note: even if it might have a limited use, this is a great sample project, showing off interesting technologies.*

The Tool uses:
- the DDCLI classes by Dave Dribin for parsing the command line arguments.
- the FMDB library by August Mueller to read/write iPhoto's sqlite database
- The NSString+SymLinksAndAliases category by Matt Gallagher to deal with aliases/symbolic links


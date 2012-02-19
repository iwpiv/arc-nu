How to run
==========

This is a program for generating .xspf playlists from S-expressions.

It is assumed that all your playlist files will be kept in a single folder.

For the sake of this README, I'll assume that folder is called "Templates".

Here is the basic usage of the program. First, you navigate to the folder
which contains all your music, then you run the program with the path to the
"Templates" folder as the first argument:

    cd path/to/Music
    playlist path/to/Templates

If you give a second argument to the playlist program, it will store the
.xspf files there instead of in the current directory:

    playlist path/to/Templates path/to/Playlists

This will cause the program to scan through the "Templates" folder and use
the S-expression playlists defined within to generate .xspf equivalents.
It will then store those .xspf playlists in the "Playlists" folder.


The S-expression Playlist Format
================================

All playlists are composed of one or more S-expressions. The only required
S-expression is `title`. The playlist can then optionally include files via
the `include` or `playlist` expressions. Here's an example of a simple
playlist:

    (title "foo")

    (playlist
      "bar"
      "qux"
      ...
      "corge")

The `title` element is used as the filename. So, the above playlist will have
a filename of "foo.xspf". In addition, it's used when including other
playlists, which will be discussed later.

The `playlist` element is used to specify which files will be included into
the playlist. The program uses sub-string matching, so the pattern `"bar"` can
match "path/to/bar.mp3" as well as "path/to/foo - bar 3.wav"


There are three error conditions:

 1. If a pattern matches two or more different files, an error will be raised:
    you will then need to make the pattern more specific.

 2. If a file is matched by two or more different patterns, an error will be
    raised: you will need to change the patterns to refer to different files.

 3. If a pattern does not match any file, an error will be raised.


To create a playlist, simply create a new file in the "Templates" folder,
place a `title` expression inside the file, then add an `include` or
`playlist` expression (or both): that's it! Now just run the program as
specified in "How to run".


Including other playlists
=========================

If you wish to combine multiple different playlists into a single one, you can
use the `include` S-expression at the top level:

    (include "bar"
             "qux")

The above will find the playlists "bar" and "qux" and include them into the
current playlist. If any of the included playlists do not exist, an error will
be raised.

It is also possible to *selectively* include only parts of another playlist by
using the `w/playlist` form:

    (playlist
      (w/playlist "foo"
        "qux"
        "corge")

      (w/playlist "bar"
        "nou"
        "yes"))

The above will include the files `"qux"` and `"corge"` from the `"foo"`
playlist, in addition to the `"nou"` and `"yes"` files from the `"bar"`
playlist. Just like normal file matching, you can use sub-strings when adding
files from a playlist.

One caveat when including files from another playlist: the program will always
correctly include files regardless of what order the templates are loaded in.
But the program can't handle infinite loops:

    (title "foo")
    (include "bar")

    (title "bar")
    (include "foo")

The above two playlists will cause the program to never terminate.


Limiting the scope of a pattern
===============================

Because patterns use sub-string matching, sometimes they are more lenient than
you would like. A simple way to be more strict is to include the file's path
in the pattern:

    (playlist
      "path/to/foo"
      "path/to/bar"
      "path/to/qux"
      "other/path/to/foo"
      "other/path/to/bar"
      "other/path/to/qux")

But that is verbose and tedious. As an alternative, inside the `playlist`
S-expression, you can use the `w/folder` S-expression:

    (playlist
      (w/folder "path/to"
        "foo"
        "bar"
        "qux")

      (w/folder "other/path/to"
        "foo"
        "bar"
        "qux"))


Examples
========

I have included a few of my own playlists in the "examples" subdirectory.
These demonstrate how to write playlists, and also clearly show how much
shorter and easier to read the S-expression format is, compared to .xspf.

This makes managing playlists a much more pleasant experience.
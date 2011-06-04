What is SyncDAV?
================

It's a couple of classes for Cocoa which attempt to replicate the syncing behavior of DropBox, but over Apache or MobileMe WebDAV servers.

You instanticate a SDManager class and point one end of it it at a local bundle (such as a VoodooPad document), and then point the other end at a folder on a WebDAV server.  It'll hopefully do the rest.

But it'll really just delete your important data.  It's a work in progress.

Check out the SyncDAV example application for how it works, or the tests in the jstests folder.
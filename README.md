aether
==========
[![Build Status](https://travis-ci.org/openfl/aether.png)](https://travis-ci.org/openfl/aether)


Introduction
-------

Aether is a common set of build tools for Haxe projects. Aether helps manage assets, asset libraries, 
binaries, icon generation and other aspects of the update, build, package, install and run process
for web, desktop and mobile platforms.


Development Build
-----------------

    haxelib install format
    haxelib install svg
    git clone https://github.com/openfl/aether
    haxelib dev aether aether

To rebuild the tools, use:

    aether rebuild tools

To return to release builds:

    haxelib dev aether


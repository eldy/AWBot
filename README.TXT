
------------- AWBot --------------
         Advanced Web Bot
----------------------------------

Advanced Web Bot (AWBot) is an easy tool to emulate a visitor activity on a
web server. It allows you to prepare some "configuration" of test (list of
actions to do before and after a test, list of URLs to test with the
expected or unexpected result). You can use then this configuration files
for several major goals:
- Test a change in your web server (development, new web server version...)
to be sure that all your site is still working
- Found broken links
- Make benchmarks and/or found the maximum number of users your site can
support
- etc...

License: GNU GPL (GNU General Public License. See LICENSE file)
Version : 1.0
Release date: June 2002
Platforms: All (Linux, NT, SCO, BSD, Solaris and other *NIX's, BeOS, OS/2...)
Author: Laurent Destailleur <eldy@users.sourceforge.net>
AWBot official web site and latest version: http://awbot.sourceforge.net

I   - Features and requirements of AWBot
	  I - 1) Features, what AWBot can do
	  I - 2) Requirements for using AWBot
	  I - 3) Files
II  - How to use AWBot
III - About the author, license and support



I - FEATURES AND REQUIREMENTS
------------------------------------

I - 1) Features

	* Support sites requiring Basic HTTP authentication.
	* Can make different pre-post tasks before-after a test (external script, SQL commands...).
	* Can check each HTML page resulting of HTTP requests to verify if contents contains/does not contains particular keywords or to extract values.
	* URL or params to use in test can be dynamically defined (using values catched from previous page).
	* A multi-session test launcher to run several simultaneous tests for load benchmarking.
	* Report errors, response time for each page and average response time.
	* A lot of other feature to match your test needs.
	* Absolutely free with sources (GNU General Public License)
	* AWBot has a XML Portable Application Description.


I - 2) Requirements

	To use AWBot, you need the following requirements:
	* Your operating system must be able to run perl scripts (.pl files).
	  If not, you can solve this by downloading last Perl version at:
	  http://www.activestate.com/ActivePerl/ (Win32)
	  http://www.perl.com/pub/language/info/software.html (Unix/Linux/Other)
	* The following perl modules must also be installed:
	  Time::HiRes
	  

I - 3) Files

	The distribution of AWBot package includes the following files:
	README.TXT                          This file
	docs/LICENSE                        GNU General Public Licence
	docs/*                              AWBot documentation (setup/usage...)
	bin/awbot.pl                        AWBot main script
	bin/awbotlauncher.pl                AWBot launcher to launch several
	                                    simultaneous sessions
	bin/awbot.test.conf                 An example of AWBot test/config file



II - HOW TO INSTALL AND USE AWBOT
---------------------------------

The documentation available as of the date of this release is included, in
HTML format, in the docs/ directory.
You can find a most up-to-date documentation on:
http://awbot.sourceforge.net



III - ABOUT THE AUTHOR, LICENSE AND SUPPORT
-------------------------------------------
Copyright (C) 2000-2001 - Laurent Destailleur - eldy@users.sourceforge.net

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
version 2 as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, in COPYING.TXT file.

If you have not received a copy of this file along with this program, write to
the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

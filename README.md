pydevsh
=========

Simple bash script to help Python project development.

Should be placed on the projects root directory. To the same directory where
setup.py is usually located.

This script uses [distribute](https://pypi.python.org/pypi/distribute) develop
command to create a development environment where python project under the same
directory as this script can be imported and should be preferred for import
before installed packages with the same name.

If package with same name is also installed then this does not always work and
the installed package is imported instead. This can happen, for example, if
distribution package contains namespace packages.

Basically this script just installs development version of the package under
/tmp/ and adds this path to PYTHONPATH. All additional code is there just to
provide ease of use.


Usage
-----

Just source the script (with bash) and after that you should be able to import
projects modules.

    . project_dir/dev.sh

By default uses "python" binary. To use with binary named "python2" argument
"-2" can be provided.

    . project_dir/dev.sh -2


Depends
-------

* [bash](https://www.gnu.org/software/bash/)
* [distribute](https://pypi.python.org/pypi/distribute/)
* [python](http://www.python.org/)

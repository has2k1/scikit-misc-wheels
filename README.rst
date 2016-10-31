##########################################
Building and uploading scikit-misc wheels
##########################################

We automate wheel building using this custom github repository that builds on
the travis-ci OSX machines and the travis-ci Linux machines.

The travis-ci interface for the builds is
https://travis-ci.org/MacPython/scikit-misc-wheels

The driving github repository is
https://github.com/MacPython/scikit-misc-wheels

How it works
============

The wheel-building repository:

* does a fresh build of any required C / C++ libraries;
* builds a scikit-misc wheel, linking against these fresh builds;
* processes the wheel using delocate_ (OSX) or auditwheel_ ``repair``
  (Manylinux1_).  ``delocate`` and ``auditwheel`` copy the required dynamic
  libraries into the wheel and relinks the extension modules against the
  copied libraries;
* commits the built wheels to the wheels branch at
  https://github.com/has2k1/scikit-misc-wheels

The resulting wheels are therefore self-contained and do not need any external
dynamic libraries apart from those provided as standard by OSX / Linux as
defined by the manylinux1 standard.

Triggering a build
==================

You will likely want to edit the ``.travis.yml`` file to specify the
``BUILD_COMMIT`` before triggering a build - see below.

You will need write permission to the github repository to trigger new builds
on the travis-ci interface.  Contact us on the mailing list if you need this.

You can trigger a build by:

* making a commit to the `scikit-misc-wheels` repository (e.g. with `git
  commit --allow-empty`); or
* clicking on the circular arrow icon towards the top right of the travis-ci
  page, to rerun the previous build.

In general, it is better to trigger a build with a commit, because this makes
a new set of build products and logs, keeping the old ones for reference.
Keeping the old build logs helps us keep track of previous problems and
successful builds.

Which scikit-misc commit does the repository build?
====================================================

The `scikit-misc-wheels` repository will build the commit specified in the
``BUILD_COMMIT`` at the top of the ``.travis.yml`` file.  This can be any
naming of a commit, including branch name, tag name or commit hash.

Uploading the built wheels to pypi
==================================

To be implemented

.. _manylinux1: https://www.python.org/dev/peps/pep-0513
.. _delocate: https://pypi.python.org/pypi/delocate
.. _auditwheel: https://pypi.python.org/pypi/auditwheel

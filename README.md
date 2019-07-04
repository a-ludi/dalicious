dalicious
=========

[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

> General purpose utility suite with a tendency towards genome assembly.

This library mainly includes additional general purpose functions that are
absent from Phobos but also includes some functions related to genome assembly.


Table of Contents
-----------------

- [Install](#install)
- [Usage](#usage)
- [Maintainer](#maintainer)
- [Contributing](#contributing)
- [License](#license)


Install
--------

Install using [`dub`](https://code.dlang.org/)

```sh
dub add dalicious
```

or by manually adding the dependency:

```
# dub.json:
"dalicious": "~>1.0.0"

# dub.sdl:
dependency "dalicious" version="~>1.0.0"
```


Usage
-----

Look into the [online documentation](https://dalicious.dpldocs.info/dalicious.html)
or browse the code for an overview of the functionalities.


Maintainer
----------

Arne Ludwig &lt;<arne.ludwig@posteo.de>&gt;


Contributing
------------

Contributions are warmly welcome. Just create an [issue][gh-issues] or [pull request][gh-pr] on GitHub. If you submit a pull request please make sure that:

- the code compiles on Linux using the current release of [dmd][dmd-download],
- your code is covered with unit tests (if feasible) and
- `dub test` runs successfully.


[gh-issues]: https://github.com/a-ludi/dentist/issues
[gh-pr]: https://github.com/a-ludi/dentist/pulls
[dmd-download]: https://dlang.org/download.html#dmd


License
-------

This project is licensed under MIT License (see license in [LICENSE](./LICENSE).

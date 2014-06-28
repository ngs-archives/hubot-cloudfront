hubot-cloudfront
===========

[![Build Status][travis-badge]][travis]
[![npm-version][npm-badge]][npm]

A [Hubot] script to list and invalidate [Amazon CloudFront] distributions.

```
me > hubot cloudfront list distributions
hubot > - 0: E2SO336F6AMQ08 --------------------
          domain: d1ood20dgya2ll.cloudfront.net
          status: InProgress
          comment: Distribution for static.liap.us

        - 1: E29XRZTZN1VOAV --------------------
          domain: d290rn73xc4vfg.cloudfront.net
          status: Deployed
          invalidation batches in progress: 10

me > hubot cloudfront list invalidates 1
hubot > I14NJQR76VVQAT - InProgress
        I3MAZE9OBGZ05X - Completed

me > hubot cloudfront invalidate 1 /index.html /atom.xml /images/*.png
hubot > Invalidation I14NJQR76VVQAT on distribution E29XRZTZN1VOAV created.
        It might take 10 to 15 minutes until all files are invalidated.
```

Commands
--------

```
hubot cloudfront list distributions
hubot cloudfront list invalidations <distribution id or index>
hubot cloudfront invalidate <distribution id or index> <path0> <path1> ...
```

Installation
------------

1. Add `hubot-cloudfront` to dependencies.

  ```bash
  npm install --save hubot-cloudfront
  ```

2. Update `external-scripts.json`

  ```json
  ["hubot-cloudfront"]
  ```

Configuration
-------------

```
HUBOT_AWS_ACCESS_KEY_ID
HUBOT_AWS_SECRET_ACCESS_KEY
```

Author
------

[Atsushi Nagase]

License
-------

[MIT License]


[Hubot]: https://hubot.github.com/
[Atsushi Nagase]: http://ngs.io/
[MIT License]: LICENSE
[travis-badge]: https://travis-ci.org/ngs/hubot-cloudfront.svg?branch=master
[npm-badge]: http://img.shields.io/npm/v/hubot-cloudfront.svg
[travis]: https://travis-ci.org/ngs/hubot-cloudfront
[npm]: https://www.npmjs.org/package/hubot-cloudfront
[Amazon CloudFront]: http://aws.amazon.com/cloudfront/

# XbrlXML.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://robfs.github.io/XbrlXML.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://robfs.github.io/XbrlXML.jl/dev)
[![Build Status](https://travis-ci.com/robfs/XbrlXML.jl.svg?branch=main)](https://travis-ci.com/robfs/XbrlXML.jl)
[![Coverage](https://codecov.io/gh/robfs/XbrlXML.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/robfs/XbrlXML.jl)
[![Coverage](https://coveralls.io/repos/github/robfs/XbrlXML.jl/badge.svg?branch=main)](https://coveralls.io/github/robfs/XbrlXML.jl?branch=main)

This is a pure Julia implementation of the [`py-xbrl`](https://pypi.org/project/py-xbrl/) python package. [`EzXML.jl`](https://juliapackages.com/p/ezxml) is used to parse the raw XML.

See Python documentation for now - docstrings and documentation being written. 

```julia
using XbrlXML

cache = HttpCache()
cacheheader!(cache, "User-Agent" => "You, yourname@domain.com")

url = "https://www.sec.gov/Archives/edgar/data/0000789019/000156459021002316/msft-10q_20201231.htm"

xbrlinstance = parseinstance(cache, url)
```


# XbrlXML.jl
[![forthebadge](https://forthebadge.com/images/badges/made-with-julia.svg)](https://forthebadge.com)

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://robfs.github.io/XbrlXML.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://robfs.github.io/XbrlXML.jl/dev)
[![Build Status](https://travis-ci.com/robfs/XbrlXML.jl.svg?branch=main)](https://travis-ci.com/robfs/XbrlXML.jl)
[![Coverage](https://codecov.io/gh/robfs/XbrlXML.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/robfs/XbrlXML.jl)

A pure Julia implementation of the [`py-xbrl`](https://github.com/manusimidt/py-xbrl) Python package by [Manuel Schmidt](https://github.com/manusimidt).

## Installation
```julia-repl
julia> using Pkg

julia> Pkg.add("XbrlXML")
```

## Usage
```julia-repl
julia> using XbrlXML

julia> cache = HttpCache("/Users/robsimms/cache/")
/Users/robsimms/cache/

julia> header!(cache, "User-Agent" => "You, yourname@domain.com")
Dict{String, String} with 1 entry:
  "User-Agent" => "You, yourname@domain.com"

julia> url = "https://www.sec.gov/Archives/edgar/data/0000789019/000156459021002316/msft-10q_20201231.htm";

julia> xbrl = parseinstance(cache, url)
msft-10q_20201231.htm with 1574 facts

julia> msft = facts(xbrl);

julia> msft[4]
EntityCommonStockSharesOutstanding: 7,542,215,767
```
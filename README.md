# XbrlXML.jl

This is a pure `Julia` implementation of the [`py-xbrl`](https://pypi.org/project/py-xbrl/) python package using [`EzXML.jl`](https://juliapackages.com/p/ezxml) to parse the raw XML.

See `Python` documentation for now - docstrings and documentation being written. 

```julia
using XbrlXML

cache = HttpCache("./cache")
cache.headers = Dict("User-Agent" => "Your Name, yourname@domain.com")

xbrl_parser = XbrlParser(cache)
url = "https://www.sec.gov/Archives/edgar/data/0000789019/000156459021002316/msft-10q_20201231.htm"

xbrl_instance = parse_instance(xbrl_parser, url);
```


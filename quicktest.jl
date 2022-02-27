using Pkg

Pkg.activate(".")

using XbrlXML

url = "https://www.sec.gov/Archives/edgar/data/789019/000156459017014900/msft-20170630.xml"
cache = HttpCache("~/cache/", Dict{AbstractString,AbstractString}())
cache.headers = Dict(["User-Agent" => "RFS rfs@rfs.com"])

inst = parse_instance(cache, url)

println(inst.facts)

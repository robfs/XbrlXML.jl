module XbrlXML

using EzXML

include("Cache.jl")
using .Cache

include("Linkbases.jl")
using .Linkbases

include("Taxonomy.jl")
using .Taxonomy

include("Instance.jl")
using .Instance

export HttpCache, XbrlParser, parse_instance

end

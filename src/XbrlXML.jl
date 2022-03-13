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

include("Exceptions.jl")
using .Exceptions

export HttpCache, cache_edgar_enclosure, cachefile, purgefile, urltopath
export cacheheader!, cacheheaders!, cacheheaders, cachedir
export XbrlInstance, parseinstance, parseinstance_locally
export facts
export parsexbrl, parseixbrl, parsexbrl_url, parseixbrl_url
export parselinkbase, parselinkbase_url
export parsetaxonomy, parsecommontaxonomy, parsetaxonomy_url, gettaxonomy

end

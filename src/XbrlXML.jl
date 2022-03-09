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

export HttpCache, cache_edgar_enclosure, cache_file, purge_file, url_to_path
export XbrlInstance, parse_instance, parse_instance_locally
export parse_xbrl, parse_ixbrl, parse_xbrl_url, parse_ixbrl_url
export parse_linkbase, parse_linkbase_url
export parse_taxonomy, parse_common_taxonomy, parse_taxonomy_url, get_taxonomy

end

module Taxonomy

using Memoize, LRUCache

include("uri_helper.jl")

using ..EzXML, ..Cache, ..Linkbases

export Concept, TaxonomySchema, parse_taxonomy, parse_common_taxonomy, parse_taxonomy_url, get_taxonomy

NAME_SPACES = Dict([
    "xsd" => "http://www.w3.org/2001/XMLSchema",
    "link" => "http://www.xbrl.org/2003/linkbase",
    "xlink" => "http://www.w3.org/1999/xlink",
    "xbrldt" => "http://xbrl.org/2005/xbrldt"
])

NS_SCHEMA_MAP = Dict([
        "http://fasb.org/srt/2018-01-31" => "http://xbrl.fasb.org/srt/2018/elts/srt-2018-01-31.xsd",
        "http://fasb.org/srt/2019-01-31" => "http://xbrl.fasb.org/srt/2019/elts/srt-2019-01-31.xsd",
        "http://fasb.org/srt/2020-01-31" => "http://xbrl.fasb.org/srt/2020/elts/srt-2020-01-31.xsd",

        "http://xbrl.sec.gov/stpr/2018-01-31" => "https://xbrl.sec.gov/stpr/2018/stpr-2018-01-31.xsd",

        "http://xbrl.sec.gov/country/2017-01-31" => "https://xbrl.sec.gov/country/2017/country-2017-01-31.xsd",
        "http://xbrl.sec.gov/country/2020-01-31" => "https://xbrl.sec.gov/country/2020/country-2020-01-31.xsd",

        "http://xbrl.us/invest/2009-01-31" => "https://taxonomies.xbrl.us/us-gaap/2009/non-gaap/invest-2009-01-31.xsd",
        "http://xbrl.sec.gov/invest/2011-01-31" => "https://xbrl.sec.gov/invest/2011/invest-2011-01-31.xsd",
        "http://xbrl.sec.gov/invest/2012-01-31" => "https://xbrl.sec.gov/invest/2012/invest-2012-01-31.xsd",
        "http://xbrl.sec.gov/invest/2013-01-31" => "https://xbrl.sec.gov/invest/2013/invest-2013-01-31.xsd",

        "http://xbrl.sec.gov/dei/2011-01-31" => "https://xbrl.sec.gov/dei/2011/dei-2011-01-31.xsd",
        "http://xbrl.sec.gov/dei/2012-01-31" => "https://xbrl.sec.gov/dei/2012/dei-2012-01-31.xsd",
        "http://xbrl.sec.gov/dei/2013-01-31" => "https://xbrl.sec.gov/dei/2013/dei-2013-01-31.xsd",
        "http://xbrl.sec.gov/dei/2014-01-31" => "https://xbrl.sec.gov/dei/2014/dei-2014-01-31.xsd",
        "http://xbrl.sec.gov/dei/2018-01-31" => "https://xbrl.sec.gov/dei/2018/dei-2018-01-31.xsd",
        "http://xbrl.sec.gov/dei/2019-01-31" => "https://xbrl.sec.gov/dei/2019/dei-2019-01-31.xsd",
        "http://xbrl.sec.gov/dei/2020-01-31" => "https://xbrl.sec.gov/dei/2020/dei-2020-01-31.xsd",
        "http://xbrl.sec.gov/dei/2021" => "https://xbrl.sec.gov/dei/2021/dei-2021.xsd",

        "http://fasb.org/us-gaap/2011-01-31" => "http://xbrl.fasb.org/us-gaap/2011/elts/us-gaap-2011-01-31.xsd",
        "http://fasb.org/us-gaap/2012-01-31" => "http://xbrl.fasb.org/us-gaap/2012/elts/us-gaap-2012-01-31.xsd",
        "http://fasb.org/us-gaap/2013-01-31" => "http://xbrl.fasb.org/us-gaap/2013/elts/us-gaap-2013-01-31.xsd",
        "http://fasb.org/us-gaap/2014-01-31" => "http://xbrl.fasb.org/us-gaap/2014/elts/us-gaap-2014-01-31.xsd",
        "http://fasb.org/us-gaap/2015-01-31" => "http://xbrl.fasb.org/us-gaap/2015/elts/us-gaap-2015-01-31.xsd",
        "http://fasb.org/us-gaap/2016-01-31" => "http://xbrl.fasb.org/us-gaap/2016/elts/us-gaap-2016-01-31.xsd",
        "http://fasb.org/us-gaap/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/elts/us-gaap-2017-01-31.xsd",
        "http://fasb.org/us-gaap/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/elts/us-gaap-2018-01-31.xsd",
        "http://fasb.org/us-gaap/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/elts/us-gaap-2019-01-31.xsd",
        "http://fasb.org/us-gaap/2020-01-31" => "http://xbrl.fasb.org/us-gaap/2020/elts/us-gaap-2020-01-31.xsd",
        "http://fasb.org/us-gaap/2021-01-31" => "http://xbrl.fasb.org/us-gaap/2021/elts/us-gaap-2021-01-31.xsd",
    ])

mutable struct Concept
    xml_id::AbstractString
    schema_url::Union{AbstractString,Nothing}
    name::AbstractString
    type::Union{String,Nothing}
    substitution_group::Union{AbstractString, Nothing}
    concept_type::Union{AbstractString, Nothing}
    abstract::Union{Bool, Nothing}
    nillable::Union{Bool, Nothing}
    period_type::Union{AbstractString, Nothing}
    balance::Union{AbstractString, Nothing}
    labels::Vector{Label}

    Concept(role_id::AbstractString, uri::Union{AbstractString,Nothing}, definition::AbstractString) = new(
        role_id, uri, definition, nothing, nothing, nothing, nothing, nothing, nothing, nothing, []
    )
end

mutable struct ExtendedLinkRole
    xml_id::AbstractString
    uri::AbstractString
    definition::AbstractString
    definition_link::Union{ExtendedLink, Nothing}
    presentation_link::Union{ExtendedLink, Nothing}
    calculation_link::Union{ExtendedLink, Nothing}

    ExtendedLinkRole(role_id::AbstractString, uri::AbstractString, definition::AbstractString) = new(
        role_id, uri, definition, nothing, nothing, nothing
    )
end

mutable struct TaxonomySchema
    schema_url::AbstractString
    namespace::AbstractString
    imports::Vector{TaxonomySchema}
    link_roles::Vector{ExtendedLinkRole}
    lab_linkbases::Vector{Linkbase}
    def_linkbases::Vector{Linkbase}
    cal_linkbases::Vector{Linkbase}
    pre_linkbases::Vector{Linkbase}
    concepts::Dict{AbstractString, Concept}
    name_id_map::Dict{AbstractString, AbstractString}

    TaxonomySchema(schema_url::AbstractString, namespace::AbstractString) = new(
        schema_url, namespace, [], [], [], [], [], [], Dict(), Dict()
    )
end

function get_taxonomy(schema::TaxonomySchema, url::AbstractString)::Union{TaxonomySchema, Nothing}
    if compare_uri(schema.namespace, url) || compare_uri(schema.schema_url, url)
        return schema
    end
    for imported_tax in schema.imports
        result::Union{TaxonomySchema, Nothing} = get_taxonomy(imported_tax, url)
        !(result isa Nothing) && return result
    end
    return nothing
end

function parse_common_taxonomy(cache::HttpCache, namespace::AbstractString)::Union{TaxonomySchema, Nothing}
    ns_map::Dict{String,String} = NS_SCHEMA_MAP
    haskey(ns_map, namespace) && return parse_taxonomy_url(ns_map[namespace], cache)
    return nothing
end

@memoize LRU{Tuple{AbstractString, HttpCache}, TaxonomySchema}(maxsize=60) function parse_taxonomy_url(schema_url::AbstractString, cache::HttpCache)::TaxonomySchema
    !startswith(schema_url, "http") && throw("This function only parses remotely saved taxonomies.")
    schema_path::AbstractString = cache_file(cache, schema_url)
    return parse_taxonomy(schema_path, cache, schema_url)
end


function parse_taxonomy(schema_path::String, cache::HttpCache, schema_url::Union{String,Nothing}=nothing)::TaxonomySchema

    # Implement errors

    doc::EzXML.Document = readxml(schema_path)
    root::EzXML.Node = doc.root
    target_ns::AbstractString = root["targetNamespace"]

    taxonomy::TaxonomySchema = schema_url isa Nothing ? TaxonomySchema(schema_path, target_ns) : TaxonomySchema(schema_url, target_ns)

    import_elements::Vector{EzXML.Node} = findall("xsd:import", root, NAME_SPACES)

    for import_element in import_elements
        import_uri = import_element["schemaLocation"]
        if startswith(import_uri, "http")
            push!(taxonomy.imports, parse_taxonomy_url(import_uri, cache))
        elseif !(schema_url isa Nothing)
            import_url = resolve_uri(schema_url, import_uri)
            push!(taxonomy.imports, parse_taxonomy_url(import_url, cache))
        else
            import_path = resolve_uri(schema_path, import_uri)
            push!(taxonomy.imports, parse_taxonomy(import_path, cache))
        end
    end

    role_type_elements::Vector{EzXML.Node} = findall("xsd:annotation/xsd:appinfo/link:roleType", root, NAME_SPACES)

    for elr in role_type_elements
        elr_definition = findfirst("link:definition", elr, NAME_SPACES)
        (elr_definition isa Nothing || elr_definition.content == "") && continue
        push!(taxonomy.link_roles, ExtendedLinkRole(elr["id"], elr["roleURI"], strip(elr_definition.content)))
    end

    for element in findall("xsd:element", root, NAME_SPACES)
        (!haskey(element, "id") || !(haskey(element, "name"))) && continue
        el_id::String = element["id"]
        el_name::String = element["name"]

        concept::Concept = Concept(el_id, schema_url, el_name)
        concept.type = haskey(element, "type") ? element["type"] : nothing
        concept.nillable = haskey(element, "nillable") ? parse(Bool, element["nillable"]) : false
        concept.abstract = haskey(element, "abstract") ? parse(Bool, element["abstract"]) : false
        concept.period_type = haskey(element, "xbrli:periodType") ? element["xbrli:periodType"] : nothing
        concept.balance = haskey(element, "xbrli:balance") ? element["xbrli:balance"] : nothing
        concept.substitution_group = haskey(element, "substitutionGroup") ? split(element["substitutionGroup"], ":")[end] : nothing

        taxonomy.concepts[concept.xml_id] = concept
        taxonomy.name_id_map[concept.name] = concept.xml_id
    end

    linkbase_ref_elements::Vector{EzXML.Node} = findall("xsd:annotation/xsd:appinfo/link:linkbaseRef", root, NAME_SPACES)
    for linkbase_ref in linkbase_ref_elements
        linkbase_uri = linkbase_ref["xlink:href"]
        role = haskey(linkbase_ref, "xlink:role") ? linkbase_ref["xlink:role"] : nothing
        linkbase_type = role isa Nothing ? Linkbases.guess_linkbase_role(linkbase_uri) : Linkbases.get_type_from_role(role)

        if startswith(linkbase_uri, "http")
            linkbase = parse_linkbase_url(linkbase_uri, linkbase_type, cache)
        elseif !(schema_url isa Nothing)
            linkbase_url = resolve_uri(schema_url, linkbase_uri)
            linkbase = parse_linkbase_url(linkbase_url, linkbase_type, cache)
        else
            linkbase_path = resolve_uri(schema_path, linkbase_uri)
            linkbase = parse_linkbase(linkbase_path, linkbase_type)
        end

        linkbase_type == DEFINITION && push!(taxonomy.def_linkbases, linkbase)
        linkbase_type == CALCULATION && push!(taxonomy.cal_linkbases, linkbase)
        linkbase_type == PRESENTATION && push!(taxonomy.pre_linkbases, linkbase)
        linkbase_type == LABEL && push!(taxonomy.lab_linkbases, linkbase)

    end

    for elr in taxonomy.link_roles
        for extended_def_links in [def_linkbase.extended_links for def_linkbase in taxonomy.def_linkbases]
            for extended_def_link in extended_def_links
                if split(extended_def_link.elr_id, "#")[2] == elr.xml_id
                    elr.definition_link = extended_def_link
                    break
                end
            end
        end
        for extended_pre_links in [pre_linkbase.extended_links for pre_linkbase in taxonomy.pre_linkbases]
            for extended_pre_link in extended_pre_links
                if split(extended_pre_link.elr_id, "#")[2] == elr.xml_id
                    elr.presentation_link = extended_pre_link
                    break
                end
            end
        end
        for extended_cal_links in [cal_linkbase.extended_links for cal_linkbase in taxonomy.cal_linkbases]
            for extended_cal_link in extended_cal_links
                if split(extended_cal_link.elr_id, "#")[2] == elr.xml_id
                    elr.calculation_link = extended_cal_link
                    break
                end
            end
        end
    end

    for label_linkbase in taxonomy.lab_linkbases
        for extended_link in label_linkbase.extended_links
            for root_locator in extended_link.root_locators
                (schema_url, concept_id) = split(root_locator.href, "#")
                c_taxonomy::Union{TaxonomySchema,Nothing} = get_taxonomy(taxonomy, schema_url)
                c_taxonomy isa Nothing && continue
                concept::Concept = c_taxonomy.concepts[concept_id]

                for label_arc in root_locator.children
                    for label in label_arc.labels
                        push!(concept.labels, label)
                    end
                end
            end
        end
    end

    return taxonomy
end


end # Module

module Instance

include("uri_helper.jl")
include("transformation.jl")

using ..EzXML, ..Cache, ..Taxonomy, Dates

export XbrlInstance, parse_instance

NAME_SPACES = [
    "xsd" => "http://www.w3.org/2001/XMLSchema",
    "link" => "http://www.xbrl.org/2003/linkbase",
    "xlink" => "http://www.w3.org/1999/xlink",
    "xbrldt" => "http://xbrl.org/2005/xbrldt",
    "xbrli" => "http://www.xbrl.org/2003/instance",
    "xbrldi" => "http://xbrl.org/2006/xbrldi"
]

function node_get(node::EzXML.Node, key, default)
    haskey(node, key) && return node[key]
    return default
end
struct ExplicitMember
    dimension::Concept
    member::Concept
end

Base.show(io::IO, m::ExplicitMember) = print(
    io, "$(m.member.name) on dimension $(m.dimension.name)"
)

abstract type AbstractContext end

mutable struct InstantContext <: AbstractContext
    xml_id::AbstractString
    entity::AbstractString
    segments::Vector{ExplicitMember}
    instant_date::Date

    InstantContext(xml_id::AbstractString, entity::AbstractString, instant_date::AbstractString) = new(
        xml_id, entity, [], Date(instant_date)
    )

    InstantContext(xml_id::AbstractString, entity::AbstractString, instant_date::Date) = new(
        xml_id, entity, [], Date(instant_date)
    )

end

Base.show(io::IO, c::InstantContext) = print(
    io, "$(c.instant_date) $(length(c.segments)) dimension"
)

mutable struct TimeFrameContext <: AbstractContext
    xml_id::AbstractString
    entity::AbstractString
    segments::Vector{ExplicitMember}
    start_date::Date
    end_date::Date

    TimeFrameContext(xml_id::AbstractString, entity::AbstractString, start_date::AbstractString, end_date::AbstractString) = new(
        xml_id, entity, [], Date(start_date), Date(end_date)
    )

    TimeFrameContext(xml_id::AbstractString, entity::AbstractString, start_date::Date, end_date::Date) = new(
        xml_id, entity, [], start_date, end_date
    )
end

Base.show(io::IO, c::TimeFrameContext) = print(
    io, "$(c.start_date) to $(c.end_date) $(length(c.segments)) dimension"
)

mutable struct ForeverContext <: AbstractContext
    xml_id::AbstractString
    entity::AbstractString
    segments::Vector{ExplicitMember}

    ForeverContext(xml_id::AbstractString, entity::AbstractString) = new(xml_id, entity, [])
end

abstract type AbstractUnit end

struct SimpleUnit <: AbstractUnit
    unit_id::AbstractString
    unit::AbstractString
end

Base.show(io::IO, u::SimpleUnit) = print(io, self.unit)

struct DivideUnit <: AbstractUnit
    unit_id::AbstractString
    numerator::AbstractString
    denominator::AbstractString
end

Base.show(io::IO, u::DivideUnit) = print(io, u.numerator, "/", u.denominator)

struct Footnote
    content::AbstractString
    lang::AbstractString
end


abstract type AbstractFact end

Base.show(io::IO, f::AbstractFact) = print(
    io, f.concept.name, ": ", f.value
)

struct NumericFact <: AbstractFact
    concept::Concept
    context::AbstractContext
    value::Union{Real,Nothing}
    footnote::Union{Footnote,Nothing}
    unit::AbstractUnit
    decimals::Union{Int,Nothing}

    NumericFact(concept, context, value, unit, decimals) = new(
        concept, context, value, nothing, unit, decimals
    )
end

struct TextFact <: AbstractFact
    concept::Concept
    context::AbstractContext
    value::AbstractString
    footnote::Union{Footnote,Nothing}

    TextFact(concept, context, value) = new(concept, context, value, nothing)
end

struct XbrlInstance
    instance_url::AbstractString
    taxonomy::TaxonomySchema
    facts::Vector{AbstractFact}
    context_map::Dict
    unit_map::Dict
end

Base.show(io::IO, i::XbrlInstance) = print(
    io,
    split(i.instance_url, Base.Filesystem.path_separator)[end],
    " with ", length(i.facts), " facts"
)

function parse_xbrl_url(instance_url::AbstractString, cache::HttpCache)::XbrlInstance
    instance_path::AbstractString = cache_file(cache, instance_url)
    return parse_xbrl(instance_path, cache, instance_url)
end

function parse_xbrl(instance_path::AbstractString, cache::HttpCache, instance_url::Union{AbstractString,Nothing} = nothing)::XbrlInstance
    doc::EzXML.Document = readxml(instance_path)
    root::EzXML.Node = doc.root

    ns_map::Dict{AbstractString,AbstractString} = Dict(namespaces(root))
    delete!(ns_map, "")
    ns_map["default"] = namespace(root)

    schema_ref::EzXML.Node = findfirst("link:schemaRef", root, NAME_SPACES)
    schema_uri::AbstractString = schema_ref["xlink:href"]

    if startswith(schema_uri, "http")
        taxonomy::TaxonomySchema = parse_taxonomy_url(schema_uri, cache)
    elseif !(instance_url isa Nothing)
        schema_url = resolve_uri(instance_url, schema_uri)
        taxonomy = parse_taxonomy_url(schema_url, cache)
    else
        schema_path = resolve_uri(instance_path, schema_uri)
        taxonomy = parse_taxonomy(schema_path, cache)
    end

    context_dir = _parse_context_elements(findall("xbrli:context", root, NAME_SPACES), ns_map, taxonomy, cache)
    unit_dir = _parse_unit_elements(findall("xbrli:unit", root, NAME_SPACES))

    facts::Vector{AbstractFact} = []
    for fact_elem in eachelement(root)

        if occursin("context", fact_elem.name) || occursin("unit", fact_elem.name) || occursin("schemaRef", fact_elem.name)
            continue
        end
        if !haskey(fact_elem, "contextRef")
            continue
        end
        if fact_elem.content == "" || length(strip(fact_elem.content)) == 0
            continue
        end

        taxonomy_ns::AbstractString = namespace(fact_elem)
        concept_name::AbstractString = fact_elem.name
        tax = get_taxonomy(taxonomy, taxonomy_ns)
        if tax isa Nothing
            tax = _load_common_taxonomy(cache, taxonomy_ns, taxonomy)
        end

        concept::Concept = tax.concepts[tax.name_id_map[concept_name]]
        context::AbstractContext = context_dir[fact_elem["contextRef"]]

        if haskey(fact_elem, "unitRef")
            unit::AbstractUnit = unit_dir[fact_elem["unitRef"]]
            decimals_text::AbstractString = strip(fact_elem["decimals"])
            decimals::Union{Int,Nothing} = lowercase(decimals_text) == "inf" ? nothing : trunc(Int, parse(Float64, decimals_text))
            fact::AbstractFact = NumericFact(concept, context, parse(Float64, strip(fact_elem.content)), unit, decimals)
        else
            fact = TextFact(concept, context, strip(fact_elem.content))
        end

        push!(facts, fact)

    end

    return XbrlInstance(instance_url isa Nothing ? instance_path : instance_url, taxonomy, facts, context_dir, unit_dir)

end

function parse_ixbrl_url(instance_url::AbstractString, cache::HttpCache)::XbrlInstance
    instance_path::AbstractString = cache_file(cache, instance_url)
    return parse_ixbrl(instance_path, cache, instance_url)
end

function parse_ixbrl(instance_path::AbstractString, cache::HttpCache, instance_url::Union{AbstractString,Nothing} = nothing)::XbrlInstance

    doc::EzXML.Document = readxml(instance_path)
    root::EzXML.Node = doc.root

    ns_map::Dict{AbstractString,AbstractString} = Dict(namespaces(root))
    delete!(ns_map, "")
    ns_map["default"] = namespace(root)

    schema_ref::EzXML.Node = findfirst(".//link:schemaRef", root, NAME_SPACES)
    schema_uri::AbstractString = schema_ref["xlink:href"]

    if startswith(schema_uri, "http")
        taxonomy::TaxonomySchema = parse_taxonomy_url(schema_uri, cache)
    elseif !(instance_url isa Nothing)
        schema_url::AbstractString = resolve_uri(instance_url, schema_uri)
        taxonomy = parse_taxonomy_url(schema_url, cache)
    else
        schema_path::AbstractString = resolve_uri(instance_path, schema_uri)
        taxonomy = parse_taxonomy(schema_path, cache)
    end

    xbrl_resources::EzXML.Node = findfirst(".//ix:resources", root, ns_map)
    xbrl_resources isa Nothing && throw(error("No resources"))

    context_dir = _parse_context_elements(findall("xbrli:context", xbrl_resources, NAME_SPACES), ns_map, taxonomy, cache)
    unit_dir = _parse_unit_elements(findall("xbrli:unit", xbrl_resources, NAME_SPACES))

    facts::Vector{AbstractFact} = []
    fact_elements::Vector{EzXML.Node} = findall(".//ix:nonFraction", root, ns_map)
    append!(fact_elements, findall(".//ix:nonNumeric", root, ns_map))

    for fact_elem in fact_elements
        _update_ns_map!(ns_map, namespaces(fact_elem))
        (taxonomy_prefix, concept_name) = split(fact_elem["name"], ":")
        tax = get_taxonomy(taxonomy, ns_map[taxonomy_prefix])
        if tax isa Nothing
            tax = _load_common_taxonomy(cache, ns_map[taxonomy_prefix], taxonomy)
        end
        concept::Concept = tax.concepts[tax.name_id_map[concept_name]]
        context::AbstractContext = context_dir[fact_elem["contextRef"]]

        if fact_elem.name == "nonFraction"
            fact_value::Union{Real,AbstractString,Nothing} = _extract_non_fraction_value(fact_elem)

            unit::AbstractUnit = unit_dir[fact_elem["unitRef"]]
            decimals_text::AbstractString = node_get(fact_elem, "decimals", "0")
            decimals::Union{Integer,Nothing} = lowercase(decimals_text) == "inf" ? nothing : parse(Int, decimals_text)

            push!(facts, NumericFact(concept, context, fact_value, unit, decimals))

        elseif fact_elem.name == "nonNumeric"
            fact_value = _extract_non_numeric_value(fact_elem)
            push!(facts, TextFact(concept, context, fact_value))

        end
    end

    return XbrlInstance(instance_url isa Nothing ? instance_path : instance_url, taxonomy, facts, context_dir, unit_dir)
end


function _extract_non_numeric_value(fact_elem::EzXML.Node)::AbstractString

    fact_value::AbstractString = fact_elem.content

    for child in eachelement(fact_elem)
        fact_value *= _extract_text_value(child)
    end

    fact_format::Union{AbstractString,Nothing} = node_get(fact_elem, "format", nothing)
    if !(fact_format isa Nothing)
        if startswith(fact_format, "ixt:")
            fact_value = transform_ixt(fact_value, split(fact_format, ":")[2])
        elseif startswith(fact_format, "ixt-sec")
            fact_value = transform_ixt_sec(fact_value, split(fact_format, ":")[2])
        end
    end

    return fact_value
end

function _extract_non_fraction_value(fact_elem::EzXML.Node)::Union{Real,Nothing}

    node_get(fact_elem, "xsi:nil", "false") == "true" && return nothing

    haselement(fact_elem) && return nothing

    fact_value::AbstractString = fact_elem.content

    for child in eachelement(fact_elem)
        fact_value *= _extract_text_value(child)
    end

    fact_format::Union{AbstractString,Nothing} = node_get(fact_elem, "format", nothing)
    value_scale::Integer = parse(Int, node_get(fact_elem, "scale", "0"))
    value_sign::Union{AbstractString,Nothing} = node_get(fact_elem, "sign", nothing)

    if !(fact_format isa Nothing)
        if startswith(fact_format, "ixt:")
            fact_value = transform_ixt(fact_value, split(fact_format, ":")[2])
        elseif startswith(fact_format, "ixt-sec")
            fact_value = transform_ixt_sec(fact_value, split(fact_format, ":")[2])
        end
    end

    scaled_value::Real = parse(Float64, fact_value) * (10.0 ^ value_scale)

    if abs(scaled_value) > 1e6
        scaled_value = round(scaled_value)
    end
    if value_sign == "-"
        scaled_value *= -1
    end

    return scaled_value
end


function _extract_text_value(element::EzXML.Node)::AbstractString
    text::AbstractString = element.content
    for child in eachelement(element)
        text *= _extract_text_value(child)
    end
    return text
end


function _parse_context_elements(
    context_elements::Vector{EzXML.Node},
    ns_map::Dict{AbstractString,AbstractString},
    taxonomy::TaxonomySchema,
    cache::HttpCache,
)::Dict{AbstractString,AbstractContext}
    context_dict::Dict{AbstractString,AbstractContext} = Dict()
    for context_elem in context_elements
        context_id::AbstractString = context_elem["id"]
        entity::AbstractString = strip(findfirst("xbrli:entity/xbrli:identifier", context_elem, NAME_SPACES).content)
        instant_date::Union{EzXML.Node,Nothing} = findfirst("xbrli:period/xbrli:instant", context_elem, NAME_SPACES)
        start_date::Union{EzXML.Node,Nothing} = findfirst("xbrli:period/xbrli:startDate", context_elem, NAME_SPACES)
        end_date::Union{EzXML.Node,Nothing} = findfirst("xbrli:period/xbrli:endDate", context_elem, NAME_SPACES)
        forever::Union{EzXML.Node,Nothing} = findfirst("xbrli:period/xbrli:forever", context_elem, NAME_SPACES)

        if !(instant_date isa Nothing)
            context::AbstractContext = InstantContext(context_id, entity, Date(strip(instant_date.content), "y-m-d"))
        elseif !(forever isa Nothing)
            context = ForeverContext(context_id, entity)
        else
            context = TimeFrameContext(context_id, entity, Date(strip(start_date.content), "y-m-d"), Date(strip(end_date.content), "y-m-d"))
        end

        segment::Union{EzXML.Node,Nothing} = findfirst("xbrli:entity/xbrli:segment", context_elem, NAME_SPACES)
        if !(segment isa Nothing)
            for explicit_member_elem in findall("xbrldi:explicitMember", segment, NAME_SPACES)
                _update_ns_map!(ns_map, namespaces(explicit_member_elem))
                (dimension_prefix, dimension_concept_name) = split(strip(explicit_member_elem["dimension"]), ":")
                (member_prefix, member_concept_name) = split(strip(explicit_member_elem.content), ":")
                dimension_tax = get_taxonomy(taxonomy, ns_map[dimension_prefix])
                if dimension_tax isa Nothing
                    dimension_tax = _load_common_taxonomy(cache, ns_map[dimension_prefix], taxonomy)
                end
                member_tax = member_prefix == dimension_prefix ? dimension_tax : get_taxonomy(taxonomy, ns_map[member_prefix])
                if member_tax isa Nothing
                    member_tax = _load_common_taxonomy(cache, ns_map[member_prefix], taxonomy)
                end
                dimension_concept::Concept = dimension_tax.concepts[dimension_tax.name_id_map[dimension_concept_name]]
                member_concept::Concept = member_tax.concepts[member_tax.name_id_map[member_concept_name]]

                push!(context.segments, ExplicitMember(dimension_concept, member_concept))
            end
        end

        context_dict[context_id] = context

    end

    return context_dict

end

function _update_ns_map!(ns_map::Dict{AbstractString,AbstractString}, new_ns_map::Vector{Pair{T,T}}) where {T <: AbstractString}
    for (prefix, ns) in new_ns_map
        if !haskey(ns_map, prefix) && prefix != ""
            ns_map[prefix] = ns
        end
    end
end

function _parse_unit_elements(unit_elements::Vector{EzXML.Node})::Dict{AbstractString,AbstractUnit}
    unit_dict::Dict{AbstractString,AbstractUnit} = Dict()
    for unit_elem in unit_elements
        unit_id::AbstractString = unit_elem["id"]

        simple_unit::Union{EzXML.Node,Nothing} = findfirst("xbrli:measure", unit_elem, NAME_SPACES)
        divide::Union{EzXML.Node,Nothing} = findfirst("xbrli:divide", unit_elem, NAME_SPACES)

        if !(simple_unit isa Nothing)
            unit::AbstractUnit = SimpleUnit(unit_id, strip(simple_unit.content))
        else
            unit = DivideUnit(
                unit_id,
                strip(findfirst("xbrli:unitNumerator/xbrli:measure", divide, NAME_SPACES).content),
                strip(findfirst("xbrli:unitDenominator/xbrli:measure", divide, NAME_SPACES).content)
            )
        end
        unit_dict[unit_id] = unit
    end
    return unit_dict
end

function _load_common_taxonomy(cache::HttpCache, namespace::AbstractString, taxonomy::TaxonomySchema)::TaxonomySchema
    tax = parse_common_taxonomy(cache, namespace)
    tax isa Nothing && throw(error("Taxonomy not found"))
    push!(taxonomy.imports, tax)
    return tax
end

function parse_instance(cache::HttpCache, url::AbstractString)::XbrlInstance
    filetype::SubString = split(url, ".")[end]
    if filetype == "xml" || filetype == "xbrl"
        return parse_xbrl_url(url, cache)
    else
        return parse_ixbrl_url(url, cache)
    end
end

function parse_instance_locally(cache::HttpCache, path::AbstractString, instance_url::Union{AbstractString,Nothing}=nothing)::XbrlInstance
    filetype::SubString = split(path, ".")[end]
    if filetype == "xml" || filetype == "xbrl"
        return parse_xbrl(path, cache, instance_url)
    else
        return parse_ixbrl(path, cache, instance_url)
    end
end


end # Module

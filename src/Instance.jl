module Instance

include("uri_resolver.jl")

using ..EzXML, ..Cache, ..Taxonomy, Dates

export parse_instance

NAME_SPACES = [
    "xsd" => "http://www.w3.org/2001/XMLSchema",
    "link" => "http://www.xbrl.org/2003/linkbase",
    "xlink" => "http://www.w3.org/1999/xlink",
    "xbrldt" => "http://xbrl.org/2005/xbrldt",
    "xbrli" => "http://www.xbrl.org/2003/instance",
    "xbrldi" => "http://xbrl.org/2006/xbrldi"
]

struct ExplicitMember
    dimension::Concept
    member::Concept
end


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

struct DivideUnit <: AbstractUnit
    unit_id::AbstractString
    numerator::AbstractString
    denominator::AbstractString
end

struct Footnote
    content::AbstractString
    lang::AbstractString
end


abstract type AbstractFact end

struct NumericFact <: AbstractFact
    concept::Concept
    context::AbstractContext
    value::Real
    footnote::Union{Footnote,Nothing}
    unit::AbstractUnit
    decimals::Union{Int,Nothing}
end

struct TextFact <: AbstractFact
    concept::Concept
    context::AbstractContext
    value::AbstractString
    footnote::Union{Footnote,Nothing}
end

struct XbrlInstance
    instance_url::AbstractString
    taxonomy::TaxonomySchema
    facts::Vector{AbstractFact}
    context_map::Dict
    unit_map::Dict
end

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
        if !(occursin("contextRef", fact_elem.name))
            continue
        end
        if fact_elem.content == "" || length(strip(fact_elem.content)) == 0
            continue
        end

        (taxonomy_ns, concept_name) = split(fact_elem.name, "}")
        taxonomy_ns = replace(taxonomy_ns, "{" => "")
        tax = get_taxonomy(taxonomy, taxonomy_ns)
        if tax isa Nothing
            tax = _load_common_taxonomy(cache, taxonomy_ns, taxonomy)
        end

        concept::Concept = tax.concepts[tax.name_id_map[concept_name]]
        context::AbstractContext = context_dir[fact_elem["contextRef"]]

        if haskey(fact_elem, "unitRef")
            unit::AbstractUnit = unit_dir[fact_elem["unitRef"]]
            decimals_text::AbstractString = strip(fact_elem["decimals"])
            decimals::Int = lowercase(decimals_text) == "inf" ? nothing : trunc(Int, parse(Float64, decimals_text))
            fact::AbstractFact = NumericFact(concept, context, strip(fact_elem.content), nothing, unit, decimals)
        else
            fact = TextFact(concept, context, strip(fact_elem.content), nothing)
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
        if fact_elem.content == "" || length(strip(fact_elem.content)) == 0
            continue
        end
        (taxonomy_prefix, concept_name) = split(fact_elem["name"], ":")
        tax = get_taxonomy(taxonomy, ns_map[taxonomy_prefix])
        if tax isa Nothing
            tax = _load_common_taxonomy(cache, ns_map[taxonomy_prefix], taxonomy)
        end
        concept::Concept = tax.concepts[tax.name_id_map[concept_name]]
        context::AbstractContext = context_dir[fact_elem["contextRef"]]
        fact_value::Union{AbstractString,Real} = _extract_ixbrl_value(fact_elem)

        if fact_value isa Real && haskey(fact_elem, "unitRef")
            unit::AbstractUnit = unit_dir[fact_elem["unitRef"]]
            decimals_text::AbstractString = strip(fact_elem["decimals"])
            decimals::Union{Int,Nothing} = lowercase(decimals_text) == "inf" ? nothing : trunc(Int, parse(Float64, decimals_text))

            fact::AbstractFact = NumericFact(concept, context, fact_value, nothing, unit, decimals)
        else
            fact = TextFact(concept, context, "$(fact_value)", nothing)
        end
        push!(facts, fact)
    end

    return XbrlInstance(instance_url isa Nothing ? instance_path : instance_url, taxonomy, facts, context_dir, unit_dir)
end

function _extract_ixbrl_value(fact_elem::EzXML.Node)::Union{Real,AbstractString}
    value_scale::Int = haskey(fact_elem, "scale") ? trunc(Int, parse(Float64, fact_elem["scale"])) : 0
    value_sign::Union{AbstractString,Nothing} = haskey(fact_elem, "sign") ? fact_elem["sign"] : nothing

    if !(haskey(fact_elem, "format"))
        haskey(fact_elem, "unitRef") && return strip(fact_elem.content)
        try
            raw_value::Union{AbstractString,Real} = parse(Float64, fact_elem.content)
        catch
            raw_value = strip(fact_elem.content)
        end
    else
        value_format::AbstractString = split(fact_elem["format"], ":")[2]
        if value_format == "numcommadecimal"
            raw_value = parse(Float64, replace(replace(replace(strip(fact_elem.content), " " => ""), "." => ""), "," => "."))
        elseif value_format == "numdotdecimal"
            raw_value = parse(Float64, replace(replace(strip(fact_elem.content), " " => ""), "," => ""))
        elseif value_format == "datemonthdayen"
            raw_value = Dates.format(Date(fact_elem.content, dateformat"U d"), "--m-dd")
        else
            raw_value = strip(fact_elem.content)
        end
    end

    if raw_value isa Float64
        raw_value *= (10 ^ value_scale)
        if abs(raw_value) > 1e6
            raw_value = round(raw_value)
        end
        if value_sign == "-"
            raw_value *= -1
        end
    end

    return raw_value
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

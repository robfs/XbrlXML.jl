module Linkbases

include("uri_resolver.jl")

using ..EzXML, ..Cache

export Linkbase, ExtendedLink, parse_linkbase, parse_linkbase_url, DEFINITION, CALCULATION, PRESENTATION, LABEL

@enum LinkbaseType DEFINITION=1 CALCULATION PRESENTATION LABEL

function get_type_from_role(role::AbstractString)::Union{LinkbaseType, Nothing}
    d::Dict{AbstractString, LinkbaseType} = Dict([
        "http://www.xbrl.org/2003/role/definitionLinkbaseRef" => DEFINITION,
        "http://www.xbrl.org/2003/role/calculationLinkbaseRef" => CALCULATION,
        "http://www.xbrl.org/2003/role/presentationLinkbaseRef" => PRESENTATION,
        "http://www.xbrl.org/2003/role/labelLinkbaseRef" => LABEL,
    ])
    return get(d, role, nothing)
end

function guess_linkbase_role(href::AbstractString)::Union{LinkbaseType, Nothing}
    if occursin("_def", href)
        return DEFINITION
    elseif occursin("_cal", href)
        return CALCULATION
    elseif occursin("_pre", href)
        return PRESENTATION
    elseif occursin("_lab", href)
        return LABEL
    else
        return nothing
    end
end

abstract type AbstractArcElement end

mutable struct Locator
    href::AbstractString
    name::AbstractString
    concept_id::AbstractString
    parents::Vector{Locator}
    children::Vector{AbstractArcElement}

    Locator(href::AbstractString, name::AbstractString) = new(
        href,
        name,
        split(href, "#")[2],
        [],
        []
    )
end

function to_dict(locator::Locator)::Dict{String, Any}
    ps::Vector{Pair{String, Any}} = [
        "name" => locator.name,
        "href" => locator.href,
        "concept_id" => locator.concept_id,
        "children" => [to_dict(arc_element) for arc_element in locator.children]
    ]
    return Dict(ps)
end

function to_simple_dict(locator::Locator)::Dict{String, Any}
    ps::Vector{Pair{String, Any}} = [
        "concept_id" => locator.concept_id,
        "children" => [to_simple_dict(arc_element.to_locator) for arc_element in locator.children]
    ]
    return Dict(ps)
end



struct RelationArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::AbstractString
    order::Int
end

struct DefinitionArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::AbstractString
    order::Int
    closed::Union{Bool, Nothing}
    context_element::Union{AbstractString, Nothing}

    DefinitionArc(
        from_locator::Locator,
        to_locator::Locator,
        arcrole::AbstractString,
        order::Int,
        closed::Union{Bool, Nothing}=nothing,
        context_element::Union{AbstractString, Nothing}=nothing) = new(
            from_locator, to_locator, arcrole, order, closed, context_element
        )
end

function to_dict(arc::RelationArc)::Dict{String, Any}
    ps::Vector{Pair{String, Any}} = [
        "arcrole" => arc.arcrole,
        "order" => arc.order,
        "closed" => arc.order,
        "contextElement" => arc.context_element,
        "locator" => arc.to_locator |> to_dict
    ]
    return Dict(ps)
end

struct CalculationArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::AbstractString
    order::Int
    weight::Real
    
    CalculationArc(
        from_locator::Locator,
        to_locator::Locator,
        order::Int,
        weight::Real) = new(
            from_locator, to_locator, "http://www.xbrl.org/2003/arcrole/summation-item", order, weight
        )
end

function to_dict(arc::CalculationArc)::Dict{String, Any}
    ps::Vector{Pair{String, Any}} = [
        "arcrole" => arc.arcrole,
        "order" => arc.order,
        "weight" => arc.weight,
        "locator" => arc.to_locator |> to_dict
    ]
    return Dict(ps)
end

struct PresentationArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::AbstractString
    order::Int
    priority::Int
    preferred_label::Union{AbstractString, Nothing}

    PresentationArc(
        from_locator::Locator,
        to_locator::Locator,
        order::Int,
        priority::Int,
        preferred_label::Union{AbstractString, Nothing}=nothing) = new(
            from_locator,
            to_locator,
            "http://www.xbrl.org/2003/arcrole/parent-child",
            order,
            priority,
            preferred_label
        )
end

function to_dict(arc::PresentationArc)::Dict{String, Any}
    ps::Vector{Pair{String, Any}} = [
        "arcrole" => arc.arcrole,
        "order" => arc.order,
        "preferredLabel" => arc.preferred_label,
        "locator" => arc.to_locator |> to_dict
    ]
    return Dict(ps)
end

struct Label
    label::AbstractString
    label_type::AbstractString
    language::AbstractString
    text::Union{AbstractString, Nothing}

    Label(
        label::AbstractString,
        label_type::AbstractString,
        language::AbstractString,
        text::AbstractString
    ) = new(
        label,
        label_type,
        language,
        text isa Nothing ? text : strip(text)
    )
end

struct LabelArc <: AbstractArcElement
    from_locator::Locator
    arcrole::AbstractString
    order::Int
    labels::Vector{Label}

    LabelArc(
        from_locator::Locator,
        order::Int,
        labels::Vector{Label}
    ) = new(from_locator, "http://www.xbrl.org/2003/arcrole/concept-label", order, labels)
end

function to_dict(arc::LabelArc)::Dict{AbstractString, Any}
    ps::Vector{Pair{AbstractString, Union{AbstractString, nothing}}} = []
    for l in arc.labels
        push!(ps, l.label_type => l.text)
    end
    return Dict(ps)
end

struct ExtendedLink
    role::AbstractString
    elr_id::Union{AbstractString, Nothing}
    root_locators::Vector{Locator}
end

function to_dict(link::ExtendedLink)::Dict{String, Any}
    ps::Vector{Pair{String, Any}} = [
        "role" => link.role,
        "elr_id" => link.elr_id,
        "root_locators" => [to_dict(loc) for loc in self.root_locators]
    ]
    return Dict(ps)
end

function to_simple_dict(link::ExtendedLink)::Dict{String, Any}
    ps::Vector{Pair{String, Any}} = [
        "role" => link.role,
        "children" => [to_simple_dict(loc) for loc in link.root_locators]
    ]
    return Dict(ps)
end


struct Linkbase
    extended_links::Vector{ExtendedLink}
    type::LinkbaseType
end

function to_dict(linkbase::Linkbase)::Dict{String, Vector{Dict{String, Any}}}
    p::Pair{String, Vector{Dict{String, Any}}} = "standardExtendedLinkElements" => [to_dict(el) for el in linkbase.extended_links]
    return Dict(p)
end

function to_simple_dict(linkbase::Linkbase)::Dict{String, Vector{Dict{String, Any}}}
    p::Pair{String, Vector{Dict{String, Any}}} = "standardExtendedLinkElements" => [to_simple_dict(el) for el in linkbase.extended_links]
    return Dict(p)
end

function parse_linkbase_url(linkbase_url::AbstractString, linkbase_type::LinkbaseType, cache::HttpCache)::Linkbase

    if startswith(linkbase_url, "http") 
        linkbase_path = cache_file(cache, linkbase_url)
        return parse_linkbase(linkbase_path, linkbase_type)
    else
        throw("This function only parses remotely saved linkbases.")
    end

end


function get_extended_link_tag(linkbase_type::LinkbaseType)::String
    linkbase_type == DEFINITION && return "definitionLink"
    linkbase_type == CALCULATION && return "calculationLink"
    linkbase_type == PRESENTATION && return "presentationLink"
    return "labelLink"
end

function get_arc_type(linkbase_type::LinkbaseType)::String
    linkbase_type == DEFINITION && return "definitionArc"
    linkbase_type == CALCULATION && return "calculationArc"
    linkbase_type == PRESENTATION && return "presentationArc"
    return "LabelArc"
end

function create_arc_object(linkbase_type::LinkbaseType, locator_map::Dict{AbstractString, Locator}, arc_from::AbstractString, arc_to::AbstractString, arc_role::AbstractString, arc_order::Union{Int, Nothing}, arc_closed::Union{Bool, Nothing}, arc_context_element::Union{AbstractString, Nothing}, arc_weight::Union{Real, Nothing}, arc_prority::Union{Int, Nothing}, arc_preferred_label::Union{AbstractString, Nothing}, label_map::Dict{String, Vector{Label}})::AbstractArcElement
    linkbase_type == DEFINITION && return DefinitionArc(locator_map[arc_from], locator_map[arc_to], arc_role, arc_order, arc_closed, arc_context_element)
    linkbase_type == CALCULATION && return CalculationArc(locator_map[arc_from], locator_map[arc_to], arc_order, arc_weight)
    linkbase_type == PRESENTATION && return PresentationArc(locator_map[arc_from], locator_map[arc_to], arc_order, arc_prority, arc_preferred_label)
    return LabelArc(locator_map[arc_from], arc_order, label_map[arc_to])
end


function parse_linkbase(linkbase_path::AbstractString, linkbase_type::LinkbaseType):: Linkbase

    startswith(linkbase_path, "http") && throw("This function only parses locally saved linkbases.")

    !isfile(linkbase_path) && throw("Could not find linkbase $(linkbase_path)")

    doc::EzXML.Document = readxml(linkbase_path)

    role_refs::Dict{AbstractString, AbstractString} = Dict()
    for role_ref in findall("link:roleRef", doc.root)
        role_refs[role_ref["roleURI"]] = role_ref["xlink:href"]
    end

    extended_links::Vector{ExtendedLink} = []

    extended_link_tag::String = get_extended_link_tag(linkbase_type)
    arc_type::String = get_arc_type(linkbase_type)

    for extended_link in findall("link:$(extended_link_tag)", doc.root)
        extended_link_role::AbstractString = extended_link["xlink:role"]
        locators::Vector{EzXML.Node} = findall("link:loc", extended_link)
        arc_elements::Vector{EzXML.Node} = findall("link:$(arc_type)", extended_link)

        locator_map::Dict{AbstractString, Locator} = Dict()
        for loc in locators
            loc_label::AbstractString = loc["xlink:label"]
            locator_href::AbstractString = loc["xlink:href"]
            if !startswith(locator_href, "http") 
                locator_href = resolve_uri(linkbase_path, locator_href)
            end
            locator_map[loc_label] = Locator(locator_href, loc_label)
        end

        label_map::Dict{String, Vector{Label}} = Dict()
        if linkbase_type == LABEL
            for label_element in findall("link:label", extended_link)
                label_name::AbstractString = label_element["xlink:label"]
                label_role::AbstractString = label_element["xlink:role"]
                label_lang::AbstractString = label_element["xml:lang"]
                label_obj::Label = Label(label_name, label_role, label_lang, nodecontent(label_element))
                haskey(label_map, label_name) ? push!(label_map[label_name], label_obj) : label_map[label_name] = [label_obj]
            end
        end

        for arc_element in arc_elements
            if haskey(arc_element, "use") 
                arc_element["use"] == "prohibited" && continue
            end
            arc_from::AbstractString = arc_element["xlink:from"]
            arc_to::AbstractString = arc_element["xlink:to"]
            arc_role::AbstractString = arc_element["xlink:arcrole"]
            arc_order::Union{Int, Nothing} = haskey(arc_element, "order") ? trunc(Int, parse(Float64, arc_element["order"])) : nothing
            arc_closed::Union{Bool, Nothing} = haskey(arc_element, "xbrldt:weight") ? parse(Bool, arc_element["xbrldt:closed"]) : nothing
            arc_context_element::Union{AbstractString, Nothing} = haskey(arc_element, "xbrldt:contextElement") ? arc_element["xbrldt:contextElement"] : nothing
            arc_weight::Union{Real, Nothing} = haskey(arc_element, "weight") ? parse(Float64,arc_element["weight"]) : nothing
            arc_priority::Union{Int, Nothing} = haskey(arc_element, "priority") ? trunc(Int, parse(Float64, arc_element["priority"])) : nothing
            arc_preferred_label::Union{AbstractString, Nothing} = haskey(arc_element, "preferredLabel") ? arc_element["preferredLabel"] : nothing

            arc_object::AbstractArcElement = create_arc_object(linkbase_type, locator_map, arc_from, arc_to, arc_role, arc_order, arc_closed, arc_context_element, arc_weight, arc_priority, arc_preferred_label, label_map)

            linkbase_type != LABEL && push!(locator_map[arc_to].parents, locator_map[arc_from])
        end

        root_locators::Vector{Locator} = []
        for locator in values(locator_map)
            length(locator.parents) == 0 && push!(root_locators, locator)
        end

        if haskey(role_refs, extended_link_role)
            push!(extended_links, ExtendedLink(extended_link_role, role_refs[extended_link_role], root_locators))
        elseif linkbase_type == LABEL
            push!(extended_links, ExtendedLink(extended_link_role, nothing, root_locators))
        end

    end

    return Linkbase(extended_links, linkbase_type)

end

end # Module
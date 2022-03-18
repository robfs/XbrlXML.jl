module Linkbases

include("uri_helper.jl")

using ..EzXML, ..Cache, ..Exceptions

export Linkbase, ExtendedLink, Locator, Label
export parselinkbase, parselinkbase_url
export RelationArc,
    DefinitionArc, CalculationArc, PresentationArc, LabelArc, AbstractArcElement

const NAME_SPACES = [
    "xsd" => "http://www.w3.org/2001/XMLSchema",
    "link" => "http://www.xbrl.org/2003/linkbase",
    "xlink" => "http://www.w3.org/1999/xlink",
    "xbrldt" => "http://xbrl.org/2005/xbrldt",
    "xbrli" => "http://www.xbrl.org/2003/instance",
    "xbrldi" => "http://xbrl.org/2006/xbrldi",
]

@enum LinkbaseType DEFINITION = 1 CALCULATION PRESENTATION LABEL

abstract type AbstractArcElement end

mutable struct Locator
    href::String
    name::String
    concept_id::String
    parents::Vector{Locator}
    children::Vector{AbstractArcElement}

    Locator(href, name) = new(href, name, split(href, "#")[2], [], [])
end

struct RelationArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::String
    order::Union{Integer,Nothing}
end

struct DefinitionArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::String
    order::Union{Int,Nothing}
    closed::Union{Bool,Nothing}
    context_element::Union{String,Nothing}

    DefinitionArc(
        from_locator::Locator,
        to_locator::Locator,
        arcrole::AbstractString,
        order::Union{Integer,Nothing},
        closed::Union{Bool,Nothing} = nothing,
        context_element::Union{AbstractString,Nothing} = nothing,
    ) = new(from_locator, to_locator, arcrole, order, closed, context_element)
end

struct CalculationArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::String
    order::Union{Int,Nothing}
    weight::Union{Float64,Nothing}

    CalculationArc(
        from_locator::Locator,
        to_locator::Locator,
        order::Union{Integer,Nothing},
        weight::Union{Real,Nothing},
    ) = new(
        from_locator,
        to_locator,
        "http://www.xbrl.org/2003/arcrole/summation-item",
        order,
        weight,
    )
end

struct PresentationArc <: AbstractArcElement
    from_locator::Locator
    to_locator::Locator
    arcrole::String
    order::Union{Int,Nothing}
    priority::Union{Int,Nothing}
    preferred_label::Union{String,Nothing}

    PresentationArc(
        from_locator::Locator,
        to_locator::Locator,
        order::Union{Integer,Nothing},
        priority::Union{Integer,Nothing},
        preferred_label::Union{AbstractString,Nothing} = nothing,
    ) = new(
        from_locator,
        to_locator,
        "http://www.xbrl.org/2003/arcrole/parent-child",
        order,
        priority,
        preferred_label,
    )
end

struct Label
    label::String
    label_type::String
    language::String
    text::Union{String,Nothing}

    Label(label, label_type, language, text::Union{AbstractString,Nothing}) =
        new(label, label_type, language, text isa Nothing ? text : strip(text))
end

struct LabelArc <: AbstractArcElement
    from_locator::Locator
    arcrole::String
    order::Union{Int,Nothing}
    labels::Vector{Label}

    LabelArc(from_locator::Locator, order::Union{Integer,Nothing}, labels::Vector{Label}) =
        new(from_locator, "http://www.xbrl.org/2003/arcrole/concept-label", order, labels)
end

struct ExtendedLink
    role::String
    elr_id::Union{String,Nothing}
    root_locators::Vector{Locator}
end

struct Linkbase
    extended_links::Vector{ExtendedLink}
    type::LinkbaseType
end

function get_type_from_role(role)::Union{LinkbaseType,Nothing}
    d::Dict{String,LinkbaseType} = Dict([
        "http://www.xbrl.org/2003/role/definitionLinkbaseRef" => DEFINITION,
        "http://www.xbrl.org/2003/role/calculationLinkbaseRef" => CALCULATION,
        "http://www.xbrl.org/2003/role/presentationLinkbaseRef" => PRESENTATION,
        "http://www.xbrl.org/2003/role/labelLinkbaseRef" => LABEL,
    ])
    return get(d, role, nothing)
end

function guess_linkbase_role(href)::Union{LinkbaseType,Nothing}
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
    return "labelArc"
end

function to_dict(locator::Locator)::Dict{String,Any}
    ps::Vector{Pair{String,Any}} = [
        "name" => locator.name,
        "href" => locator.href,
        "concept_id" => locator.concept_id,
        "children" => [to_dict(arc_element) for arc_element in locator.children],
    ]
    return Dict(ps)
end

function to_simple_dict(locator::Locator)::Dict{String,Any}
    ps::Vector{Pair{String,Any}} = [
        "concept_id" => locator.concept_id,
        "children" => [
            to_simple_dict(arc_element.to_locator) for arc_element in locator.children
        ],
    ]
    return Dict(ps)
end

function to_dict(arc::RelationArc)::Dict{String,Any}
    ps::Vector{Pair{String,Any}} = [
        "arcrole" => arc.arcrole,
        "order" => arc.order,
        "closed" => arc.order,
        "contextElement" => arc.context_element,
        "locator" => arc.to_locator |> to_dict,
    ]
    return Dict(ps)
end

function to_dict(arc::CalculationArc)::Dict{String,Any}
    ps::Vector{Pair{String,Any}} = [
        "arcrole" => arc.arcrole,
        "order" => arc.order,
        "weight" => arc.weight,
        "locator" => arc.to_locator |> to_dict,
    ]
    return Dict(ps)
end

function to_dict(arc::PresentationArc)::Dict{String,Any}
    ps::Vector{Pair{String,Any}} = [
        "arcrole" => arc.arcrole,
        "order" => arc.order,
        "preferredLabel" => arc.preferred_label,
        "locator" => arc.to_locator |> to_dict,
    ]
    return Dict(ps)
end

function to_dict(arc::LabelArc)::Dict{String,Any}
    ps::Vector{Pair{AbstractString,Union{AbstractString,nothing}}} = []
    for l in arc.labels
        push!(ps, l.label_type => l.text)
    end
    return Dict(ps)
end

function to_dict(link::ExtendedLink)::Dict{String,Any}
    ps::Vector{Pair{String,Any}} = [
        "role" => link.role,
        "elr_id" => link.elr_id,
        "root_locators" => [to_dict(loc) for loc in self.root_locators],
    ]
    return Dict(ps)
end

function to_simple_dict(link::ExtendedLink)::Dict{String,Any}
    ps::Vector{Pair{String,Any}} = [
        "role" => link.role,
        "children" => [to_simple_dict(loc) for loc in link.root_locators],
    ]
    return Dict(ps)
end

function to_dict(linkbase::Linkbase)::Dict{String,Vector{Dict{String,Any}}}
    p::Pair{String,Vector{Dict{String,Any}}} =
        "standardExtendedLinkElements" => [to_dict(el) for el in linkbase.extended_links]
    return Dict(p)
end

function to_simple_dict(linkbase::Linkbase)::Dict{String,Vector{Dict{String,Any}}}
    p::Pair{String,Vector{Dict{String,Any}}} =
        "standardExtendedLinkElements" =>
            [to_simple_dict(el) for el in linkbase.extended_links]
    return Dict(p)
end

function parselinkbase_url(
    linkbase_url,
    linkbase_type::LinkbaseType,
    cache::HttpCache,
)::Linkbase

    if startswith(linkbase_url, "http")
        linkbase_path = cachefile(cache, linkbase_url)
        return parselinkbase(linkbase_path, linkbase_type, linkbase_url)
    else
        throw("This function only parses remotely saved linkbases.")
    end

end

function parselinkbase(
    linkbase_path,
    linkbase_type::LinkbaseType,
    linkbase_url::Union{AbstractString,Nothing} = nothing,
)::Linkbase

    startswith(linkbase_path, "http") &&
        throw("This function only parses locally saved linkbases.")

    !isfile(linkbase_path) && throw("Could not find linkbase $(linkbase_path)")

    doc::EzXML.Document = readxml(linkbase_path)

    role_refs::Dict{AbstractString,AbstractString} = Dict()
    for role_ref in findall("link:roleRef", doc.root, NAME_SPACES)
        role_refs[role_ref["roleURI"]] = role_ref["xlink:href"]
    end

    extended_links::Vector{ExtendedLink} = []

    extended_link_tag::String = get_extended_link_tag(linkbase_type)
    arc_type::String = get_arc_type(linkbase_type)

    for extended_link in findall("link:$(extended_link_tag)", doc.root, NAME_SPACES)
        extended_link_role::AbstractString = extended_link["xlink:role"]
        locators::Vector{EzXML.Node} = findall("link:loc", extended_link, NAME_SPACES)
        arc_elements::Vector{EzXML.Node} =
            findall("link:$(arc_type)", extended_link, NAME_SPACES)

        locator_map::Dict{AbstractString,Locator} = Dict()
        for loc in locators
            loc_label::AbstractString = loc["xlink:label"]
            locator_href::AbstractString = loc["xlink:href"]
            if !startswith(locator_href, "http")
                locator_href = resolve_uri(
                    linkbase_url isa Nothing ? linkbase_path : linkbase_url,
                    locator_href,
                )
            end
            locator_map[loc_label] = Locator(locator_href, loc_label)
        end

        label_map::Dict{String,Vector{Label}} = Dict()
        if linkbase_type == LABEL
            for label_element in findall("link:label", extended_link, NAME_SPACES)
                label_name::AbstractString = label_element["xlink:label"]
                label_role::AbstractString = label_element["xlink:role"]
                label_lang::AbstractString = label_element["xml:lang"]
                label_obj::Label =
                    Label(label_name, label_role, label_lang, nodecontent(label_element))
                haskey(label_map, label_name) ? push!(label_map[label_name], label_obj) :
                label_map[label_name] = [label_obj]
            end
        end

        for arc_element in arc_elements
            if haskey(arc_element, "use")
                arc_element["use"] == "prohibited" && continue
            end
            arc_from::AbstractString = arc_element["xlink:from"]
            arc_to::AbstractString = arc_element["xlink:to"]
            arc_role::AbstractString = arc_element["xlink:arcrole"]
            arc_order::Union{Integer,Nothing} =
                haskey(arc_element, "order") ?
                trunc(Int, parse(Float64, arc_element["order"])) : nothing
            arc_closed::Union{Bool,Nothing} =
                haskey(arc_element, "xbrldt:weight") ?
                parse(Bool, arc_element["xbrldt:closed"]) : nothing
            arc_context_element::Union{AbstractString,Nothing} =
                haskey(arc_element, "xbrldt:contextElement") ?
                arc_element["xbrldt:contextElement"] : nothing
            arc_weight::Union{Real,Nothing} =
                haskey(arc_element, "weight") ? parse(Float64, arc_element["weight"]) :
                nothing
            arc_priority::Union{Integer,Nothing} =
                haskey(arc_element, "priority") ?
                trunc(Int, parse(Float64, arc_element["priority"])) : nothing
            arc_preferred_label::Union{AbstractString,Nothing} =
                haskey(arc_element, "preferredLabel") ? arc_element["preferredLabel"] :
                nothing

            if linkbase_type == DEFINITION
                arc_object::AbstractArcElement = DefinitionArc(
                    locator_map[arc_from],
                    locator_map[arc_to],
                    arc_role,
                    arc_order,
                    arc_closed,
                    arc_context_element,
                )
            elseif linkbase_type == CALCULATION
                arc_object = CalculationArc(
                    locator_map[arc_from],
                    locator_map[arc_to],
                    arc_order,
                    arc_weight,
                )
            elseif linkbase_type == PRESENTATION
                arc_object = PresentationArc(
                    locator_map[arc_from],
                    locator_map[arc_to],
                    arc_order,
                    arc_priority,
                    arc_preferred_label,
                )
            else
                arc_object = LabelArc(locator_map[arc_from], arc_order, label_map[arc_to])
            end

            linkbase_type != LABEL &&
                push!(locator_map[arc_to].parents, locator_map[arc_from])

            push!(locator_map[arc_from].children, arc_object)
        end

        root_locators::Vector{Locator} = []
        for locator in values(locator_map)
            length(locator.parents) == 0 && push!(root_locators, locator)
        end

        if haskey(role_refs, extended_link_role)
            push!(
                extended_links,
                ExtendedLink(
                    extended_link_role,
                    role_refs[extended_link_role],
                    root_locators,
                ),
            )
        elseif linkbase_type == LABEL
            push!(extended_links, ExtendedLink(extended_link_role, nothing, root_locators))
        end

    end

    return Linkbase(extended_links, linkbase_type)

end

Base.show(io::IO, l::Locator) = print(io, "$(l.name) with $(length(l.children)) children")
Base.show(io::IO, a::DefinitionArc) = print(
    io,
    "Linking to ",
    a.to_locator.name,
    " as ",
    split(a.arcrole, Base.Filesystem.path_separator)[end],
)
Base.show(io::IO, a::CalculationArc) = print(
    io,
    split(a.arcrole, Base.Filesystem.path_separator)[end],
    " ",
    a.to_locator.concept_id,
)
Base.show(io::IO, a::PresentationArc) = print(
    io,
    split(a.arcrole, Base.Filesystem.path_separator)[end],
    " ",
    a.to_locator.concept_id,
)
Base.show(io::IO, l::Label) = print(io, l.text)
Base.show(io::IO, a::LabelArc) = print(io, "LabelArc with $(length(a.labels)) labels")
Base.show(io::IO, l::ExtendedLink) = print(io, l.elr_id)

end # Module

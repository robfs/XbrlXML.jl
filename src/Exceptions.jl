module Exceptions

export TaxonomyNotFound, ContextParseException

abstract type XbrlParseException <: Exception end
abstract type TaxonomyParseException <: Exception end
abstract type InstanceParseException <: Exception end
abstract type LinkbaseNotFoundException <: Exception end


struct TaxonomyNotFound <: TaxonomyParseException
    namespace::AbstractString
end

struct ContextParseException <: InstanceParseException end

Base.show(io::IO, e::InstanceParseException) = print(io, "Error parsing instance")
Base.show(io::IO, e::ContextParseException) = print(io, "Error parsing context")
Base.show(io::IO, e::TaxonomyParseException) = print(io, "error parsing taxonomy")
Base.show(io::IO, e::TaxonomyNotFound) = print(
    io, "the taxonomy with the namespace $(e.namespace) could not be found.",
    "Check it is imported in the schema file."
)

end # module

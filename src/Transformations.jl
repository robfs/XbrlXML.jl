"""
Handle fact transformations.

What are fact transformation rules?
In iXBRL filers are allowed to tag textual values like "one million" or
"17th of January 2022". In XBRL those facts would be represented in a normalized manner
(1000000, 2022-01-17). To normalize the text values, the iXBRL specification provides for
so-called transformation rules. The transformation rule "zerodash" for example tells us
that the tagged char "-" has a normalized value of 0.

The transformation rules are collected in a so-called transformation rule registry.
As of writing SEC Edgar supports the following registries:

Name: XII Transformation Registry 3
Prefix: ixt
Namespace: http://www.xbrl.org/inlineXBRL/transformation/2015-02-26

Name: XII Transformation Registry 4
Prefix: ixt
Namespace: http://www.xbrl.org/inlineXBRL/transformation/2020-02-12

Name: SEC Specific Transformation Registry
Prefix: ixt-sec
Namespace: http://www.sec.gov/inlineXBRL/transformation/2015-08-31
"""
module Transformations

using Dates
using ..Exceptions

include("text2num.jl")

export normalize
export AbstractTransformationException, TransformationNotImplemented

abstract type AbstractTransformationException <: Exception end
struct TransformationException <: AbstractTransformationException
    message::String
end
struct RegistryNotSupported <: AbstractTransformationException
    namespace::AbstractString
    message::String
    RegistryNotSupported(namespace) = new(
        namespace,
        "$(namespace) registry not currently supported."
    )
end
struct InvalidTransformation <: AbstractTransformationException
    namespace::AbstractString
    formatcode::AbstractString
    message::String
    InvalidTransformation(namespace, formatcode) = new(
        namespace, formatcode,
        "$(formatcode) transformation rule not implemented in $(namespace)"
    )
end
struct TransformationNotImplemented <: AbstractTransformationException
    namespace::AbstractString
    formatcode::AbstractString
    message::String

    TransformationNotImplemented(message) = new("", "", message)
    TransformationNotImplemented(namespace, formatcode) = new(
        namespace, formatcode,
        "transformation $(formatcode) rule of registry $(namespace) not yet implemented"
    )
end

Base.show(io::IO, e::AbstractTransformationException) = print(io, e.message)

_WARNED_TRANSFORMERS = []

function _yearnorm(date::Dates.Date)::Dates.Date
    year(date) > 999 && return date
    year(date) > 60 && return date + Dates.Year(1900)
    year(date) <= 60 && return date + Dates.Year(2000)
    throw(TransformationException("error normalizing year for $(date)"))
end

_notimplemented(value::AbstractString) = throw(TransformationNotImplemented(value))
_monthformat(value, pos::Integer)::String = length(split(value, " ")[pos]) == 3 ? "u" : "U"
_dateformat(value, format::AbstractString, fmt::AbstractString)::String = Dates.format(
    _yearnorm(Date(value, DateFormat(format))), fmt
)

# region ixt mappings

_daymonth(value) = _dateformat(value, "d m", "--mm-dd")
_daymonthen(value) = _dateformat(value, "d $(_monthformat(value, 2))", "--mm-dd")
_daymonthyear(value) = _dateformat(value, "d m y", "Y-mm-dd")
_daymonthyearen(value) = _dateformat(value, "d $(_monthformat(value, 2)) y", "Y-mm-dd")
_monthday(value) = _dateformat(value, "m d", "--mm-dd")
_monthdayen(value) = _dateformat(value, "$(_monthformat(value, 1)) d", "--mm-dd")
_monthdayyear(value) = _dateformat(value, "m d y", "Y-mm-dd")
_monthdayyearen(value) = _dateformat(value, "$(_monthformat(value, 1)) d y", "Y-mm-dd")
_yearmonthday(value) = _dateformat(value, "y m d", "Y-mm-dd")
_yearmonthdayen(value) = _dateformat(value, "y $(_monthformat(value, 2)) d", "Y-mm-dd")
_monthyear(value) = _dateformat(value, "m y", "Y-mm")
_monthyearen(value) = _dateformat(value, "$(_monthformat(value, 1)) y", "Y-mm")
_yearmonth(value) = _dateformat(value, "y m", "Y-mm")
_yearmonthen(value) = _dateformat(value, "y $(_monthformat(value, 2))", "Y-mm")

_numcommadecimal(value) = replace(value, r"[^\d,]+" => "", "," => ".")
_numdotdecimal(value) = replace(value, r"[^\d.]+" => "")

# region ixt-sec mappings

function _match_durwords(value, tomatch)::Int
    m = match(Regex("(?<match>\\d+) $(tomatch)"), value)
    m isa Nothing && return 0
    return parse(Int, m["match"])
end

function _durwordsen(value)
    value = replace_text_numbers(value)
    years::Int = _match_durwords(value, "year")
    months::Int = _match_durwords(value, "month")
    days::Int = _match_durwords(value, "day")
    return "P$(years)Y$(months)M$(days)D"
end

function _numwordsen(value)
    (value == "no" || value == "none") && return "0"
    value = replace(value, " and " => " ")
    return "$(text2num(value))"
end

function _ballotbox(value)
    (value == "&#9744;" || value == "☐") && return "false"
    if (value == "&#9745;" || value == "☑" || value == "&#9746;" || value == "☒")
        return "true"
    else
        throw(TransformationException("Invalid input $(value) for ballotbox transformation rule"))
    end
end


_IXT3 = Dict([
    "booleanfalse" => x -> "false",
    "booleantrue" => x -> "true",
    "calindaymonthyear" => _notimplemented,
    "datedaymonth" => _daymonth,
    "datedaymonthdk" => _notimplemented,
    "datedaymonthen" => _daymonthen,
    "datedaymonthyear" => _daymonthyear,
    "datedaymonthyeardk" => _notimplemented,
    "datedaymonthyearen" => _daymonthyearen,
    "datedaymonthyearin" => _notimplemented,
    "dateerayearmonthdayjp" => _notimplemented,
    "dateerayearmonthjp" => _notimplemented,
    "datemonthday" => _monthday,
    "datemonthdayen" => _monthdayen,
    "datemonthdayyear" => _monthdayyear,
    "datemonthdayyearen" => _monthdayyearen,
    "datemonthyear" => _monthyear,
    "datemonthyeardk" => _notimplemented,
    "datemonthyearen" => _monthyearen,
    "datemonthyearin" => _notimplemented,
    "dateyearmonthday" => _yearmonthday,
    "dateyearmonthdayen" => _yearmonthdayen,
    "dateyearmonthdaycjk" => _notimplemented,
    "dateyearmonthcjk" => _notimplemented,
    "dateyearmonthen" => _yearmonthen,
    "numcommadecimal" => _numcommadecimal,
    "numdotdecimal" => _numdotdecimal,
    "numdotdecimalin" => _notimplemented,
    "numunitdecimal" => _notimplemented,
    "numunitdecimalin" => _notimplemented,
    "zerodash" => x -> "0",
    "nocontent" => x -> "",
])

_IXT4 = Dict([
    "date-day-month" => _daymonth,
    "date-day-month-year" => _daymonthyear,
    "date-day-monthname-bg" => _notimplemented,
    "date-day-monthname-cs" => _notimplemented,
    "date-day-monthname-da" => _notimplemented,
    "date-day-monthname-de" => _notimplemented,
    "date-day-monthname-el" => _notimplemented,
    "date-day-monthname-en" => _daymonthen,
    "date-day-monthname-es" => _notimplemented,
    "date-day-monthname-et" => _notimplemented,
    "date-day-monthname-fi" => _notimplemented,
    "date-day-monthname-fr" => _notimplemented,
    "date-day-monthname-hr" => _notimplemented,
    "date-day-monthname-it" => _notimplemented,
    "date-day-monthname-lv" => _notimplemented,
    "date-day-monthname-nl" => _notimplemented,
    "date-day-monthname-no" => _notimplemented,
    "date-day-monthname-pl" => _notimplemented,
    "date-day-monthname-pt" => _notimplemented,
    "date-day-monthname-ro" => _notimplemented,
    "date-day-monthname-sk" => _notimplemented,
    "date-day-monthname-sl" => _notimplemented,
    "date-day-monthname-sv" => _notimplemented,
    "date-day-monthname-year-bg" => _notimplemented,
    "date-day-monthname-year-cs" => _notimplemented,
    "date-day-monthname-year-da" => _notimplemented,
    "date-day-monthname-year-de" => _notimplemented,
    "date-day-monthname-year-el" => _notimplemented,
    "date-day-monthname-year-en" => _daymonthyearen,
    "date-day-monthname-year-es" => _notimplemented,
    "date-day-monthname-year-et" => _notimplemented,
    "date-day-monthname-year-fi" => _notimplemented,
    "date-day-monthname-year-fr" => _notimplemented,
    "date-day-monthname-year-hi" => _notimplemented,
    "date-day-monthname-year-hr" => _notimplemented,
    "date-day-monthname-year-it" => _notimplemented,
    "date-day-monthname-year-nl" => _notimplemented,
    "date-day-monthname-year-no" => _notimplemented,
    "date-day-monthname-year-pl" => _notimplemented,
    "date-day-monthname-year-pt" => _notimplemented,
    "date-day-monthname-year-ro" => _notimplemented,
    "date-day-monthname-year-sk" => _notimplemented,
    "date-day-monthname-year-sl" => _notimplemented,
    "date-day-monthname-year-sv" => _notimplemented,
    "date-day-monthroman" => _notimplemented,
    "date-day-monthroman-year" => _notimplemented,
    "date-ind-day-monthname-year-hi" => _notimplemented,
    "date-jpn-era-year-month" => _notimplemented,
    "date-jpn-era-year-month-day" => _notimplemented,
    "date-month-day" => _monthday,
    "date-month-day-year" => _monthdayyear,
    "date-month-year" => _monthyear,
    "date-monthname-day-en" => _monthdayen,
    "date-monthname-day-hu" => _notimplemented,
    "date-monthname-day-lt" => _notimplemented,
    "date-monthname-day-year-en" => _monthdayyearen,
    "date-monthname-year-bg" => _notimplemented,
    "date-monthname-year-cs" => _notimplemented,
    "date-monthname-year-da" => _notimplemented,
    "date-monthname-year-de" => _notimplemented,
    "date-monthname-year-el" => _notimplemented,
    "date-monthname-year-en" => _notimplemented,
    "date-monthname-year-es" => _notimplemented,
    "date-monthname-year-et" => _notimplemented,
    "date-monthname-year-fi" => _notimplemented,
    "date-monthname-year-fr" => _notimplemented,
    "date-monthname-year-hi" => _notimplemented,
    "date-monthname-year-hr" => _notimplemented,
    "date-monthname-year-it" => _notimplemented,
    "date-monthname-year-nl" => _notimplemented,
    "date-monthname-year-no" => _notimplemented,
    "date-monthname-year-pl" => _notimplemented,
    "date-monthname-year-pt" => _notimplemented,
    "date-monthname-year-ro" => _notimplemented,
    "date-monthname-year-sk" => _notimplemented,
    "date-monthname-year-sl" => _notimplemented,
    "date-monthname-year-sv" => _notimplemented,
    "date-monthroman-year" => _notimplemented,
    "date-year-day-monthname-lv" => _notimplemented,
    "date-year-month" => _yearmonth,
    "date-year-month-day" => _yearmonthday,
    "date-year-monthname-day-hu" => _notimplemented,
    "date-year-monthname-day-lt" => _notimplemented,
    "date-year-monthname-en" => _yearmonthen,
    "date-year-monthname-hu" => _notimplemented,
    "date-year-monthname-lt" => _notimplemented,
    "date-year-monthname-lv" => _notimplemented,
    "fixed-empty" => x -> "",
    "fixed-false" => x -> "false",
    "fixed-true" => x -> "true",
    "fixed-zero" => x -> "0",
    "num-comma-decimal" => _numcommadecimal,
    "num-dot-decimal" => _numdotdecimal,
    "num-unit-decimal" => _notimplemented,
])

_IXTSEC = Dict([
    "duryear" => _notimplemented,
    "durmonth" => _notimplemented,
    "durweek" => _notimplemented,
    "durday" => _notimplemented,
    "durhour" => _notimplemented,
    "durwordsen" => _durwordsen,
    "numwordsen" => _numwordsen,
    "datequarterend" => _notimplemented,
    "boolballotbox" => _ballotbox,
    "exchnameen" => _notimplemented,
    "stateprovnameen" => _notimplemented,
    "countrynameen" => _notimplemented,
    "edgarprovcountryen" => _notimplemented,
    "entityfilercategoryen" => _notimplemented,
])

function normalize(namespace::AbstractString, formatcode::AbstractString, value::AbstractString)::AbstractString
    value = replace(strip(lowercase(value)), '\ua0' => " ")
    if startswith(formatcode, "date")
        value = strip(replace(value, r"[^\d|^\w]+" => " ", r"\bsept\b" => "sep"))
    end
    try
        if namespace == "http://www.xbrl.org/inlineXBRL/transformation/2015-02-26"
            return _IXT3[formatcode](value)
        elseif namespace == "http://www.xbrl.org/inlineXBRL/transformation/2020-02-12"
            return _IXT4[formatcode](value)
        elseif namespace == "http://www.sec.gov/inlineXBRL/transformation/2015-08-31"
            return _IXTSEC[formatcode](value)
        else
            throw(RegistryNotSupported(namespace))
        end
    catch e
        e isa KeyError && throw(InvalidTransformation(namespace, formatcode))
        e isa TransformationNotImplemented && throw(
            TransformationNotImplemented(namespace, formatcode)
        )
        rethrow(e)
    end
end

end # module

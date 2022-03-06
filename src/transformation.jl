using Dates

include("text2num.jl")

function transform_ixt(value::AbstractString, transform_format::AbstractString)::AbstractString

    value::AbstractString = replace(strip(lowercase(value)), "\xa0" => " ")

    transform_format == "booleanfalse" && return "false"
    transform_format == "booleantrue" && return "true"
    transform_format == "zerodash" && return "0"
    transform_format == "nocontent" && ""

    if startswith(transform_format, "date")
        value = replace(value, r"[,\-\._/]" => " ")
        value = replace(value, r"\s{2,}" => " ")
        seg::Vector{AbstractString} = split(value, " ")

        if transform_format == "datedaymonth"
            return Dates.format(Date(value, "d m"), "--mm-dd")
        elseif transform_format == "datedaymonthen"
            monthformat::String = length(seg[2]) == 3 ? "u" : "U"
            return Dates.format(Date(value, "d $(monthformat)"), "--mm-dd")
        elseif transform_format == "datedaymonthyear"
            return Dates.format(Date(value, dateformat"d m y"), "Y-mm-dd")
        elseif transform_format == "datedaymonthyearen"
            monthformat = length(seg[2]) == 3 ? "u" : "U"
            return Dates.format(Date(value, dateformat"d $(monthformat) y"), "Y-mm-dd")
        elseif transform_format == "datemonthday"
            return Dates.format(Date(value, "m d"), "--mm-dd")
        elseif transform_format == "datemonthdayen"
            monthformat = length(seg[1]) == 3 ? "u" : "U"
            return Dates.format(Date(value, "$(monthformat) d"), "--mm-dd")
        elseif transform_format == "datemonthdayyear"
            return Dates.format(Date(value, "m d y"), "Y-mm-dd")
        elseif transform_format == "datemonthdayyearen"
            monthformat = length(seg[1]) == 3 ? "u" : "U"
            return Dates.format(Date(value, "$(monthformat) d y"), "Y-mm-dd")
        elseif transform_format == "dateyearmonthday"
            return Dates.format(Date(value, "y m d"), "Y-mm-dd")
        elseif transform_format == "dateyearmonthdayen"
            monthformat = length(seg[2]) == 3 ? "u" : "U"
            return Dates.format(Date(value, "y $(monthformat) d"), "Y-mm-dd")
        elseif transform_format == "datemonthyear"
            return Dates.format(Date(value, "m y"), "Y-mm")
        elseif transform_format == "datemonthyearen"
            monthformat = length(seg[1]) == 3 ? "u" : "U"
            return Dates.format(Date(value, "$(monthformat) y"), "Y-mm")
        elseif transform_format == "dateyearmonth"
            return Dates.format(Date(value, "y m"), "Y-mm")
        elseif transform_format == "dateyearmonthen"
            monthformat = length(seg[2]) == 3 ? "u" : "U"
            return Dates.format(Date(value, "y $(monthformat)"), "Y-mm")
        end
    elseif startswith(transform_format, "num")
        if transform_format == "numcommadecimal"
            return replace(value, r"(\s|-|\.)" => "", "," => ".")
        elseif transform_format == "numdotdecimal"
            return replace(value, r"(\s|-|,)" => "")
        end
    else
        throw(error("Unknown fact transformation $(format)"))
    end
end


function transform_ixt_sec(value::AbstractString, transform_format::AbstractString)::AbstractString

    value = replace(strip(lowercase(value)), "\xa0" => " ")

    if transform_format == "numwordsen"
        if value == "no" || value == "none"
            return "0"
        else
            return "$(text2num(value))"
        end
    end

    throw(error("Unknown fact transformation $(transform_format)"))
end

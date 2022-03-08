using Dates

_WARNED_TRANSFORMERS = []

include("text2num.jl")

function transform_ixt(value::AbstractString, transform_format::AbstractString)::AbstractString

    value = replace(strip(lowercase(value)), '\ua0' => " ")
    transform_format = replace(transform_format, "-" => "")

    transform_format == "booleanfalse" && return "false"
    transform_format == "booleantrue" && return "true"
    transform_format == "zerodash" && return "0"
    transform_format == "fixedzero" && return "0"
    transform_format == "fixedtrue" && return "true"
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
        elseif transform_format == "datemonthdayyearen" || transform_format == "datemonthnamedayyearen"
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
        else
            throw(error("Unknown date transformation $(transform_format), $(value)"))
        end
    elseif startswith(transform_format, "num")
        if transform_format == "numcommadecimal"
            return replace(value, r"(\s|-|\.)" => "", "," => ".")
        elseif transform_format == "numdotdecimal"
            return replace(value, r"(\s|-|,)" => "")
        end
    else
        throw(error("Unknown fact transformation $(transform_format)"))
    end
end


function transform_ixt_sec(value::AbstractString, transform_format::AbstractString)::AbstractString

    value = replace(strip(lowercase(value)), "\xa0" => " ")
    value = replace(value, r"[,\-\._/]" => " ")
    value = replace(value, r"\s{2,}" => " ")

    if transform_format == "numwordsen"
        if value == "no" || value == "none"
            return "0"
        else
            return "$(text2num(value))"
        end
    elseif transform_format == "boolballotbox"
        if value == "☐"
            return "false"
        else
            return "true"
        end
    elseif transform_format == "durwordsen"
        value = replace_text_numbers(value)
        (years, months, days) = (0, 0, 0)
        words::Vector{AbstractString} = split(value, " ")
        for (i, x) in enumerate(words)

            if tryparse(Int, x) isa Nothing
                continue
            elseif occursin("year", words[i + 1])
                years = parse(Int, x)
            elseif occursin("month", words[i + 1])
                months = parse(Int, x)
            elseif occursin("day", words[i + 1])
                days = parse(Int, x)
            end
        end

        return "P$(years)Y$(months)M$(days)D"
    end

    if !(transform_format in _WARNED_TRANSFORMERS)

        @warn "The transformation rule ixt-sec:$(transform_format) is currently not supported by this parser."
        push!(_WARNED_TRANSFORMERS, transform_format)

    end

    return value
end

function replace_text_numbers(text::AbstractString)::AbstractString
    text = replace(strip(lowercase(text)), "\xa0" => " ")
    seg::Vector{AbstractString} = split(text, " ")
    for (i, x) in enumerate(seg)
        try
            seg[i] = "$(text2num(x))"
        catch
            continue
        end
    end
    return join(seg, " ")
end

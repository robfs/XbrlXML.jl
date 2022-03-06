UNITNUMBERS = Dict([
    "zero" => 0,
    "one" => 1,
    "two" => 2,
    "three" => 3,
    "four" => 4,
    "five" => 5,
    "six" => 6,
    "seven" => 7,
    "eight" => 8,
    "nine" => 9,
    "ten" => 10,
    "eleven" => 11,
    "twelve" => 12,
    "thirteen" => 13,
    "fourteen" => 14,
    "fifteen" => 15,
    "sixteen" => 16,
    "seventeen" => 17,
    "eighteen" => 18,
    "nineteen" => 19,
    "twenty" => 20,
    "thirty" => 30,
    "forty" => 40,
    "fifty" => 50,
    "sixty" => 60,
    "seventy" => 70,
    "eighty" => 80,
    "ninety" => 90
])

ORDEROFMAGNITUDE = Dict([
    "thousand" => 1000,
    "million" => 1000000,
    "billion" => 1000000000,
    "trillion" => 1000000000000,
    "quadrillion" => 1000000000000000,
    "quintillion" => 1000000000000000000,
    "sextillion" => 1000000000000000000000,
    "septillion" => 1000000000000000000000000,
    "octillion" => 1000000000000000000000000000,
    "nonillion" => 1000000000000000000000000000000,
    "decillion" => 1000000000000000000000000000000000,
])

function text2num(s::AbstractString)::Real
    s = replace(lowercase(s), " and " => " ")
    re::Regex = r"[\s-]+"
    a::Vector{AbstractString} = split(s, re)
    n = 0
    g = 0
    for w in a
        x = get(UNITNUMBERS, w, nothing)
        if !(x isa Nothing)
            g += x
        elseif w == "hundred" && g != 0
            g *= 100
        else
            x = get(ORDEROFMAGNITUDE, w, nothing)
            if !(x isa Nothing)
                n += g * x
                g = 0
            else
                throw(error("Unknown number: " * w))
            end
        end
    end
    return n + g
end

text2num(x::Real)::Real = x

module Cache

using Downloads
using ZipFile

export HttpCache
export cacheheader!, cacheheaders!, cacheheaders, cachedir
export cachefile, purgefile, urltopath, cache_edgar_enclosure

mutable struct HttpCache
    cachedir::AbstractString
    headers::Dict{AbstractString, AbstractString}

    HttpCache(cachedir="./cache/", headers=Dict{String,String}()) = new(
        endswith(cachedir, "/") ? cachedir : cachedir * "/",
        headers
    )

end

cachedir(cache::HttpCache) = cache.cachedir
cacheheaders(cache::HttpCache) = cache.headers

Base.show(io::IO, c::HttpCache) = print(
    io, "$(abspath(cachedir(c)))"
)

function cacheheader!(cache::HttpCache, header::Pair{String,String})
    get!(cache.headers, header.first, header.second)
    return cacheheaders(cache)
end

function cacheheaders!(cache::HttpCache, headers::Vector{Pair{String,String}})
    for header in headers
        cacheheader!(cache, header)
    end
end

function cachefile(cache::HttpCache, file_url::AbstractString)::AbstractString

    file_path::AbstractString = urltopath(cache, file_url)

    isfile(file_path) && return file_path

    file_dir_path::AbstractString = join(split(file_path, "/")[1:end-1], "/")

    mkpath(file_dir_path)

    Downloads.download(file_url, file_path; headers=cacheheaders(cache))

    return file_path

end

function purgefile(cache::HttpCache, file_url::AbstractString)::Bool
    try
        rm(urltopath(cache, file_url))
    catch
        return false
    end
    return true
end

function urltopath(cache::HttpCache, url::AbstractString)::AbstractString
    rep::Pair{Regex, AbstractString} = r"https?://" => ""
    return cachedir(cache) * replace(url, rep)
end

function cache_edgar_enclosure(cache::HttpCache, enclosure_url::AbstractString)

    if endswith(enclosure_url, ".zip")

        enclosure_path::AbstractString = cachefile(cache, enclosure_url)

        parent_path::AbstractString = join(split(enclosure_url, "/")[1:end-1], "/")

        submission_dir_path::AbstractString = urltopath(cache, parent_path)

        r::ZipFile.Reader = ZipFile.Reader(enclosure_path)

        for f in r.files
            write("$(submission_dir_path)/$(f.name)", read(f, String))
        end

        close(r)

    else
        throw(error("This is not a valid zip folder"))
    end

    return submission_dir_path
end

function find_entry_file(cache::HttpCache, dir::AbstractString)::Union{AbstractString,Nothing}

    valid_files::Vector{AbstractString} = []

    for ext in [".htm", ".xml", ".xsd"]
        for f in readdir(dir, join=true)
            isfile(f) && endswith(lowercase(f), ext) && push!(valid_files, f)
        end
    end

    entry_candidates::Vector{AbstractString} = []

    for file1 in valid_files
        (fdir, file_nm) = rsplit(file1, Base.Filesystem.path_separator; limit=2)
        found_in_other::Bool = false
        for file2 in valid_files
            if file1 != file2
                file2contents::AbstractString = open(file2) do f
                    read(f)
                end
                if occursin(file_nm, file2contents)
                    found_in_other = true
                    break
                end
            end
        end

        !found_in_other && push!(entry_candidates, (file1, fileszie(file1)))
    end

    sort!(entry_candidates; by=x -> x[2], rev=true)

    if length(entry_candidates) > 0
        (file_path, size) = entry_candidates[1]
        return file_path
    end

    return nothing
end


end # Module
